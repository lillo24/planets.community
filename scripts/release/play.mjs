import { ReleaseError } from "./errors.mjs";
import { sign } from "node:crypto";

export const PACKAGE = "community.planets.app";
const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/edits`;

export function selectTrack(tracks, policy) {
  if (
    policy.package !== PACKAGE ||
    !policy.closed_track_verified_reference ||
    !policy.closed_track ||
    /^(?:production|internal|beta|.*:production)$/i.test(policy.closed_track)
  )
    throw new ReleaseError(
      "Only the verified existing closed-testing track is allowed",
    );
  const track = tracks.find((item) => item.track === policy.closed_track);
  if (!track)
    throw new ReleaseError("Configured closed track was not returned by Play");
  if (
    (track.releases ?? []).some((r) => r.status !== "completed") ||
    (track.releases?.length ?? 0) > 1
  )
    throw new ReleaseError(
      "Existing draft/staged release requires owner reconciliation",
    );
  return track;
}

export function allocateCode(policy, runNumber, tracks, bundles, apks) {
  const floor = policy.historical_version_code_floor;
  if (
    !Number.isSafeInteger(floor) ||
    floor < 1 ||
    !Number.isSafeInteger(runNumber) ||
    runNumber < 1
  )
    throw new ReleaseError(
      "Missing verified historical code floor/CI run number",
    );
  const used = [
    ...bundles.map((b) => b.versionCode),
    ...apks.map((a) => a.versionCode),
    ...tracks.flatMap((t) =>
      (t.releases ?? []).flatMap((r) => r.versionCodes ?? []),
    ),
  ].map(Number);
  const code = floor + runNumber;
  if (
    used.some((n) => !Number.isSafeInteger(n) || n < 1) ||
    code <= Math.max(floor, ...used) ||
    code > 2100000000
  )
    throw new ReleaseError(
      "Version code already used/out of range; refresh Console floor and start a NEW run",
    );
  return code;
}

export async function playAccessToken(json, fetcher = fetch) {
  if (!json)
    throw new ReleaseError(
      "Missing PLAY_SERVICE_ACCOUNT_JSON in planets-play-closed environment",
    );
  let account;
  try {
    account = JSON.parse(json);
  } catch {
    throw new ReleaseError("Invalid Play service-account JSON");
  }
  if (
    account.type !== "service_account" ||
    !account.client_email?.endsWith(".gserviceaccount.com") ||
    !account.private_key ||
    account.token_uri !== "https://oauth2.googleapis.com/token"
  )
    throw new ReleaseError(
      "Invalid Play service-account identity/token endpoint",
    );
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({ iss: account.client_email, scope: "https://www.googleapis.com/auth/androidpublisher", aud: account.token_uri, iat: now, exp: now + 3600 })}`;
  const assertion = `${unsigned}.${sign("RSA-SHA256", Buffer.from(unsigned), account.private_key).toString("base64url")}`;
  const response = await fetcher(account.token_uri, {
    method: "POST",
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
    signal: AbortSignal.timeout(60000),
  });
  if (!response.ok)
    throw new ReleaseError(`Play OAuth failed (HTTP ${response.status})`);
  const value = await response.json();
  if (!value.access_token)
    throw new ReleaseError("Play OAuth returned no access token");
  return value.access_token;
}

export function playClient(token, fetcher = fetch) {
  async function request(path, method = "GET", body, upload = false) {
    const response = await fetcher(
      `${upload ? BASE.replace("/androidpublisher/v3/", "/upload/androidpublisher/v3/") : BASE}${path}`,
      {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": upload
            ? "application/octet-stream"
            : "application/json",
        },
        ...(body !== undefined && {
          body: upload ? body : JSON.stringify(body),
        }),
        signal: AbortSignal.timeout(upload ? 600000 : 60000),
      },
    );
    if (!response.ok)
      throw new ReleaseError(
        `Play ${method} failed (HTTP ${response.status}); inspect Console privately; no automatic retry of writes`,
      );
    return response.status === 204 ? null : response.json();
  }
  return {
    request,
    create: () => request("", "POST", {}),
    inventory: async (id) => {
      const [tracks, bundles, apks] = await Promise.all([
        request(`/${id}/tracks`),
        request(`/${id}/bundles`),
        request(`/${id}/apks`),
      ]);
      return {
        tracks: tracks.tracks ?? [],
        bundles: bundles.bundles ?? [],
        apks: apks.apks ?? [],
      };
    },
    discard: (id) => request(`/${id}`, "DELETE"),
  };
}

export async function publishBundle(
  api,
  { policy, bundle, evidence, backendReady },
) {
  if (
    !backendReady ||
    evidence.package !== PACKAGE ||
    evidence.sha256 !== (await import("./sql-fingerprint.mjs")).sha256(bundle)
  )
    throw new ReleaseError(
      "Backend/artifact verification is required before Play upload",
    );
  const edit = await api.create();
  let committed = false;
  try {
    const inventory = await api.inventory(edit.id);
    const track = selectTrack(inventory.tracks, policy);
    const used = [...inventory.bundles, ...inventory.apks].map((b) =>
      Number(b.versionCode),
    );
    const trackCodes = inventory.tracks
      .flatMap((t) => (t.releases ?? []).flatMap((r) => r.versionCodes ?? []))
      .map(Number);
    if (
      evidence.version_code <=
      Math.max(policy.historical_version_code_floor, ...used, ...trackCodes)
    )
      throw new ReleaseError("Play code became stale before upload");
    const uploaded = await api.request(
      `/${edit.id}/bundles?uploadType=media`,
      "POST",
      bundle,
      true,
    );
    if (
      uploaded.versionCode !== evidence.version_code ||
      uploaded.sha256 !== evidence.sha256
    )
      throw new ReleaseError("Play upload code/hash mismatch");
    // Preserve country targeting; never call testers APIs or touch other tracks.
    const previous = track.releases?.[0];
    const release = {
      name: `RELEASE01 ${evidence.source_sha.slice(0, 12)}`,
      versionCodes: [String(evidence.version_code)],
      status: "completed",
      ...(previous?.countryTargeting && {
        countryTargeting: previous.countryTargeting,
      }),
    };
    await api.request(
      `/${edit.id}/tracks/${encodeURIComponent(track.track)}`,
      "PUT",
      { track: track.track, releases: [release] },
    );
    await api.request(`/${edit.id}:validate`, "POST");
    await api.request(`/${edit.id}:commit`, "POST");
    committed = true;
    const verify = await api.create();
    try {
      const state = await api.request(
        `/${verify.id}/tracks/${encodeURIComponent(track.track)}`,
      );
      if (
        !state.releases?.some(
          (r) =>
            r.versionCodes?.includes(String(evidence.version_code)) &&
            r.status === "completed",
        )
      )
        throw new ReleaseError(
          "Committed Play release is not visible on the expected track; inspect Console before retry",
        );
      return {
        track: state.track,
        version_code: evidence.version_code,
        api_status: "completed",
        delivery:
          "submitted; review/processing/installation must be verified in Console and on a Play device",
        edit_id: edit.id,
      };
    } finally {
      await api.discard(verify.id);
    }
  } finally {
    // A discarded edit cannot reclaim an already accepted version code.
    if (!committed) await api.discard(edit.id);
  }
}
