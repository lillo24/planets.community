import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { ReleaseError, reportFailure } from "./errors.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import { stagingRelease } from "./staging.mjs";
import {
  playAccessToken,
  playClient,
  publishBundle,
  PACKAGE,
} from "./play.mjs";

export function verifyPersistedArtifact(
  policy,
  evidence,
  bundle,
  validation,
  sourceSha,
) {
  if (
    !/^[a-f0-9]{40}$/.test(sourceSha ?? "") ||
    evidence.source_sha !== sourceSha ||
    validation.source_sha !== sourceSha ||
    evidence.package !== PACKAGE ||
    evidence.backend !== "https://cllpvruvrrvxczjitlqd.supabase.co" ||
    evidence.debuggable !== false ||
    evidence.demos_enabled !== false ||
    evidence.mock_capability !== false ||
    !Number.isSafeInteger(evidence.target_sdk) ||
    evidence.target_sdk < 36 ||
    !Number.isSafeInteger(evidence.version_code) ||
    evidence.version_code < 1 ||
    !Number.isSafeInteger(evidence.signed_payloads) ||
    evidence.signed_payloads < 1 ||
    !Number.isSafeInteger(evidence.native_16k_checks) ||
    evidence.native_16k_checks < 1 ||
    !/^[a-f0-9]{64}$/.test(policy.upload_certificate_sha256 ?? "") ||
    evidence.upload_certificate_sha256 !== policy.upload_certificate_sha256 ||
    evidence.sha256 !== sha256(bundle) ||
    JSON.stringify(validation.areas) !==
      JSON.stringify(["Mobile", "Database", "Web", "Site"])
  )
    throw new ReleaseError(
      "Persisted artifact does not match the verified source/signing/backend receipt",
    );
}

export async function publishExisting(env = process.env) {
  if (env.GITHUB_REF !== "refs/heads/main")
    throw new ReleaseError("Play publication requires tested main");
  const policy = JSON.parse(
    readFileSync("scripts/release/policy.json", "utf8"),
  );
  const evidence = JSON.parse(
    readFileSync("build/release01/artifact.json", "utf8"),
  );
  const validation = JSON.parse(
    readFileSync("build/release01/validation.json", "utf8"),
  );
  // Select only the known generated name; no artifact-controlled filesystem path.
  const name = `planets-staging-${Number(evidence.version_code)}-${env.GITHUB_SHA.slice(0, 12)}.aab`;
  const bundle = readFileSync(`build/release01/${name}`);
  verifyPersistedArtifact(policy, evidence, bundle, validation, env.GITHUB_SHA);
  const current = spawnSync("git", ["ls-remote", "origin", "refs/heads/main"], {
    encoding: "utf8",
    timeout: 60000,
  });
  if (current.status !== 0 || current.stdout.split(/\s/)[0] !== env.GITHUB_SHA)
    throw new ReleaseError(
      "Main advanced before publication; start a new release run",
    );
  await stagingRelease("verify", env);
  const api = playClient(await playAccessToken(env.PLAY_SERVICE_ACCOUNT_JSON));
  const release = await publishBundle(api, {
    policy,
    evidence,
    bundle,
    backendReady: true,
  });
  writeFileSync("build/release01/play.json", JSON.stringify(release, null, 2));
  console.log(
    "Verified persisted AAB submitted and closed track re-read; Google review/installability and Play-device QA remain separate.",
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
)
  publishExisting().catch((error) => reportFailure("Play publication", error));
