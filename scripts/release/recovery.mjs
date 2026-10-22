import { ReleaseError } from "./errors.mjs";
import { inflateRawSync } from "node:zlib";
import { sha256 } from "./sql-fingerprint.mjs";
import { STAGING_REF } from "./migrations.mjs";

// This standing development choice only concerns recovery. SQL authorization,
// exact-source validation and protected readiness remain independent gates.
export function assertStagingRecoveryMode(env, projectRef) {
  let config;
  try {
    config = JSON.parse(env.STAGING_CONFIG_JSON);
  } catch {
    throw new ReleaseError(
      "Recovery mode requires the identified staging config",
    );
  }
  if (
    projectRef !== STAGING_REF ||
    config?.APP_ENV !== "staging" ||
    config.SUPABASE_URL !== `https://${STAGING_REF}.supabase.co`
  )
    throw new ReleaseError("Recovery mode is restricted to planets-staging");
  if (
    !["development-no-backup", "verified-backup"].includes(
      env.STAGING_RECOVERY_MODE,
    )
  )
    throw new ReleaseError(
      "Set protected STAGING_RECOVERY_MODE to development-no-backup or verified-backup before staging writes",
    );
  return env.STAGING_RECOVERY_MODE;
}

export async function stagingRecovery(
  env,
  api,
  predecessor,
  projectRef,
  fetcher = fetch,
) {
  const mode = assertStagingRecoveryMode(env, projectRef);
  if (!/^[a-f0-9]{64}$/.test(predecessor ?? ""))
    throw new ReleaseError(
      "Recovery mode requires the observed predecessor inventory",
    );
  if (mode === "development-no-backup")
    return {
      mode,
      status: "waived",
      project_ref: STAGING_REF,
      predecessor_inventory_sha256: predecessor,
      data_loss_accepted: true,
    };
  return {
    mode,
    status: "verified",
    ...(await verifiedRecovery(env, api, predecessor, fetcher)),
  };
}

// Read a single small receipt in memory. Never extract a backup/ZIP onto disk.
export function recoveryReceipt(zip) {
  const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (
    end < 0 ||
    end + 22 > zip.length ||
    zip.length > 65536 ||
    end + 22 + zip.readUInt16LE(end + 20) !== zip.length ||
    zip.readUInt16LE(end + 4) !== 0 ||
    zip.readUInt16LE(end + 6) !== 0 ||
    zip.readUInt16LE(end + 8) !== 1 ||
    zip.readUInt16LE(end + 10) !== 1
  )
    throw new ReleaseError(
      "Recovery artifact must contain one small metadata receipt only",
    );
  const central = zip.readUInt32LE(end + 16);
  if (central + 46 > end || zip.readUInt32LE(central) !== 0x02014b50)
    throw new ReleaseError("Invalid recovery receipt archive");
  const method = zip.readUInt16LE(central + 10),
    size = zip.readUInt32LE(central + 20),
    expanded = zip.readUInt32LE(central + 24),
    length = zip.readUInt16LE(central + 28),
    offset = zip.readUInt32LE(central + 42);
  if (
    zip.subarray(central + 46, central + 46 + length).toString() !==
      "recovery.json" ||
    central +
      46 +
      length +
      zip.readUInt16LE(central + 30) +
      zip.readUInt16LE(central + 32) !==
      end ||
    zip.readUInt16LE(central + 8) & 1 ||
    expanded > 16384 ||
    offset + 30 > central ||
    ![0, 8].includes(method) ||
    zip.readUInt32LE(offset) !== 0x04034b50
  )
    throw new ReleaseError(
      "Recovery archive is not the metadata-only contract",
    );
  const start =
    offset + 30 + zip.readUInt16LE(offset + 26) + zip.readUInt16LE(offset + 28);
  if (
    start + size > central ||
    zip.readUInt16LE(offset + 8) !== method ||
    zip
      .subarray(offset + 30, offset + 30 + zip.readUInt16LE(offset + 26))
      .toString() !== "recovery.json"
  )
    throw new ReleaseError("Invalid recovery receipt boundaries");
  const data = zip.subarray(start, start + size);
  const decoded =
    method === 8 ? inflateRawSync(data, { maxOutputLength: 16384 }) : data;
  if (decoded.length !== expanded)
    throw new ReleaseError("Recovery receipt size mismatch");
  return JSON.parse(decoded.toString("utf8"));
}

export function assertRecoveryPolicy(policy) {
  if (
    policy?.project_ref !== STAGING_REF ||
    !/^[a-f0-9]{64}$/.test(policy.workflow_sha256 ?? "") ||
    !Number.isSafeInteger(policy.workflow_id) ||
    policy.workflow_id < 1 ||
    policy.workflow_path !== ".github/workflows/staging-recovery.yml" ||
    !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(
      policy.policy_id ?? "",
    ) ||
    typeof policy.max_age_hours !== "number" ||
    !(policy.max_age_hours > 0 && policy.max_age_hours <= 24)
  )
    throw new ReleaseError(
      "One-time protected staging recovery policy is missing/invalid; original bootstrap waiver is not standing authorization",
    );
}
export function assertRecovery(policy, receipt, predecessor, now = Date.now()) {
  assertRecoveryPolicy(policy);
  const age = now - Date.parse(receipt?.completed_at);
  if (
    !receipt ||
    typeof receipt !== "object" ||
    Array.isArray(receipt) ||
    Object.keys(receipt).sort().join(",") !==
      "access_controlled,completed_at,database_restored,database_sha256,encrypted,policy_id,predecessor_inventory_sha256,project_ref,storage_objects_restored,storage_objects_sha256" ||
    receipt?.project_ref !== STAGING_REF ||
    receipt.policy_id !== policy.policy_id ||
    receipt.predecessor_inventory_sha256 !== predecessor ||
    !Number.isFinite(age) ||
    age < 0 ||
    age > policy.max_age_hours * 3600000 ||
    [
      "encrypted",
      "access_controlled",
      "database_restored",
      "storage_objects_restored",
    ].some((k) => receipt[k] !== true) ||
    !/^[a-f0-9]{64}$/.test(receipt.database_sha256 ?? "") ||
    !/^[a-f0-9]{64}$/.test(receipt.storage_objects_sha256 ?? "")
  )
    throw new ReleaseError(
      "Fresh encrypted DB AND Storage-object backup/restore evidence does not cover the observed predecessor",
    );
  return {
    policy_id: policy.policy_id,
    completed_at: receipt.completed_at,
    database_restored: true,
    storage_objects_restored: true,
  };
}

export async function verifiedRecovery(env, api, predecessor, fetcher = fetch) {
  let policy;
  try {
    policy = JSON.parse(env.STAGING_RECOVERY_POLICY_JSON);
  } catch {
    throw new ReleaseError(
      "One-time STAGING_RECOVERY_POLICY_JSON setup is required; no blanket backup waiver",
    );
  }
  // Separate configuration validation from receipt validation, with no permissive fallback.
  assertRecoveryPolicy(policy);
  const runs = await api(
    `/actions/workflows/${policy.workflow_id}/runs?branch=main&status=success&per_page=1`,
  );
  const run = runs.workflow_runs?.[0];
  if (
    !run ||
    run.head_branch !== "main" ||
    run.head_repository?.full_name !== env.GITHUB_REPOSITORY ||
    run.conclusion !== "success" ||
    !["schedule", "workflow_dispatch", "push"].includes(run.event)
  )
    throw new ReleaseError(
      "Trusted main recovery workflow has no successful run",
    );
  const workflow = await api(
    `/contents/${policy.workflow_path}?ref=${run.head_sha}`,
  );
  if (
    workflow.encoding !== "base64" ||
    sha256(Buffer.from(workflow.content, "base64")) !== policy.workflow_sha256
  )
    throw new ReleaseError(
      "Recovery workflow source differs from the protected owner-reviewed policy",
    );
  const artifacts = await api(`/actions/runs/${run.id}/artifacts?per_page=100`);
  const matches = artifacts.artifacts.filter(
    (a) => a.name === "staging-recovery-receipt" && !a.expired,
  );
  if (
    matches.length !== 1 ||
    !(matches[0].size_in_bytes > 0 && matches[0].size_in_bytes <= 65536)
  )
    throw new ReleaseError(
      "Missing/ambiguous/oversized metadata-only recovery artifact",
    );
  const response = await fetcher(
    `https://api.github.com/repos/${env.GITHUB_REPOSITORY}/actions/artifacts/${matches[0].id}/zip`,
    {
      headers: { Authorization: `Bearer ${env.GH_TOKEN}` },
      signal: AbortSignal.timeout(60000),
    },
  );
  if (!response.ok || Number(response.headers.get("content-length")) > 65536)
    throw new ReleaseError("Recovery receipt download failed/oversized");
  const receipt = recoveryReceipt(Buffer.from(await response.arrayBuffer()));
  return {
    ...assertRecovery(policy, receipt, predecessor),
    workflow_run_id: run.id,
  };
}
