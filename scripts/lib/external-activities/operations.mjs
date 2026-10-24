import {
  activityConnectorDirectory,
  resolveActivityConnector,
} from "./connectors.mjs";
import { activityImportStore, runActivityImport } from "./importer.mjs";
import { ActivityImportError } from "./transport.mjs";

const known = new Set(activityConnectorDirectory.map((x) => x.sourceId));
const slug = /^[a-z][a-z0-9-]{0,63}$/;
const good = new Set(["success", "validated", "not_due"]);
const safeCodes = new Set([
  "source_rights_checkpoint_blocked",
  "source_coverage_checkpoint_blocked",
  "unknown_source",
  "deadline",
  "completion_unconfirmed",
  "persistence_error",
  "upstream_error",
  "invalid_payload",
  "source_record_drift",
  "limit_exceeded",
  "transport_error",
  "duplicate_upstream_id",
  "invalid_record",
  "incomplete_traversal",
  "unsafe_destination",
  "pagination_loop",
  "unsupported_media_type",
  "access_denied",
  "robots_denied",
  "invalid_robots",
  "source_delay_changed",
  "source_delay_exceeds_budget",
  "unsafe_xml",
  "ambiguous_schedule",
  "invalid_jsonld",
  "invalid_calendar",
]);

// At most four explicit code-owned sources. No implicit directory-wide fetch.
export function activityOperationArguments(args, env = process.env) {
  const result = { dueOnly: false };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (["--apply", "--dry-run", "--inspect", "--maintain"].includes(arg)) {
      if (result.mode) throw new ActivityImportError("invalid_arguments");
      result.mode = arg.slice(2);
    } else if (arg === "--due-only") {
      if (result.dueOnly) throw new ActivityImportError("invalid_arguments");
      result.dueOnly = true;
    } else if (arg === "--batch-size") {
      if (result.batchSize || args[++i] !== "4")
        throw new ActivityImportError("invalid_arguments");
      result.batchSize = 4;
    } else if (["--sources", "--target"].includes(arg)) {
      const key = arg.slice(2);
      if (result[key] || !args[i + 1] || args[i + 1].startsWith("--"))
        throw new ActivityImportError("invalid_arguments");
      result[key] = args[++i];
    } else throw new ActivityImportError("invalid_arguments");
  }
  if (
    !result.mode ||
    (result.dueOnly && result.mode !== "apply") ||
    (result.mode === "dry-run" && result.target) ||
    (result.mode !== "dry-run" && !slug.test(result.target ?? ""))
  )
    throw new ActivityImportError("invalid_arguments");
  const sources = result.sources ?? env.ACTIVITIES_SOURCES;
  if (!sources) throw new ActivityImportError("source_set_required");
  result.sources = sources.split(",");
  if (
    result.sources.length > (result.batchSize ? 8 : 4) ||
    result.sources.some((x) => !slug.test(x) || !known.has(x)) ||
    new Set(result.sources).size !== result.sources.length
  )
    throw new ActivityImportError("invalid_source_set");
  return result;
}

// Private policy is cadence only; it cannot add connectors, origins or rights.
// Daily schedule means overrides are whole days, 24h..168h. Freshness is separate.
export function activityRefreshPolicy(input) {
  let values = {};
  if (input) {
    try {
      values = JSON.parse(input);
    } catch {
      throw new ActivityImportError("invalid_refresh_policy");
    }
  }
  if (
    !values ||
    Array.isArray(values) ||
    typeof values !== "object" ||
    Object.entries(values).some(
      ([id, hours]) =>
        !known.has(id) ||
        !Number.isInteger(hours) ||
        hours < 24 ||
        hours > 168 ||
        hours % 24 !== 0,
    )
  )
    throw new ActivityImportError("invalid_refresh_policy");
  return Object.fromEntries([...known].map((id) => [id, values[id] ?? 24]));
}

export function activityOperationTarget(options, env) {
  const apiUrl = env.ACTIVITIES_API_URL,
    key = env.ACTIVITIES_SERVICE_ROLE_KEY;
  if (!apiUrl || !key || options.target !== env.ACTIVITIES_TARGET)
    throw new ActivityImportError("missing_explicit_target");
  let url;
  try {
    url = new URL(apiUrl);
  } catch {
    throw new ActivityImportError("invalid_target");
  }
  if (
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    !(
      url.protocol === "https:" ||
      (url.protocol === "http:" &&
        ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname))
    )
  )
    throw new ActivityImportError("invalid_target");
  return { apiUrl, key };
}

export function activityOperationStore(client) {
  async function rpc(name, sources, signal) {
    const { data, error } = await client
      .rpc(name, { p_source_ids: sources })
      .abortSignal(signal);
    if (error) throw new ActivityImportError("persistence_error");
    if (
      data?.scope !== "external_activity_operations" ||
      !Number.isFinite(Date.parse(data.as_of))
    )
      throw new ActivityImportError("invalid_payload");
    return data;
  }
  return {
    ...activityImportStore(client),
    async inspect(sources, signal) {
      const result = await rpc(
        "inspect_external_activity_sources",
        sources,
        signal,
      );
      const radar = sources.filter(
        (id) =>
          activityConnectorDirectory.find((s) => s.sourceId === id)?.status ===
          "collection_available_publication_held",
      );
      if (radar.length) {
        const { data, error } = await client
          .rpc("inspect_external_radar_status", { p_source_ids: radar })
          .abortSignal(signal);
        if (error || !Array.isArray(data))
          throw new ActivityImportError("persistence_error");
        result.sources = result.sources.map((s) => ({
          ...s,
          ...data.find((r) => r.id === s.id),
        }));
      }
      return result;
    },
    async maintain(sources, signal) {
      const result = await rpc(
        "maintain_external_activity_imports",
        sources,
        signal,
      );
      for (const id of sources.filter(
        (id) =>
          activityConnectorDirectory.find((s) => s.sourceId === id)?.status ===
          "collection_available_publication_held",
      )) {
        // Bounded backlog drain: <=10,000 old evidence revisions per source/run.
        for (let batch = 0; batch < 100; batch++) {
          const { data, error } = await client
            .rpc("maintain_external_radar_evidence", {
              p_source_id: id,
              p_limit: 100,
            })
            .abortSignal(signal);
          if (error) throw new ActivityImportError("persistence_error");
          if (data.candidates_pruned < 100 && data.documents_pruned < 100)
            break;
        }
      }
      return result;
    },
  };
}

// Sequential source leases plus the existing target-wide Actions concurrency.
// The seven-minute parent leaves setup/failure-receipt time within the 10m job.
async function runActivityOperationBatch({
  sources,
  mode,
  dueOnly = false,
  policy = activityRefreshPolicy(),
  store,
  resolve = resolveActivityConnector,
  importSource = runActivityImport,
  parentSignal,
  runMs = 420_000,
  fetchImpl,
}) {
  if (
    !Array.isArray(sources) ||
    sources.length < 1 ||
    sources.length > 4 ||
    new Set(sources).size !== sources.length ||
    sources.some((x) => !slug.test(x)) ||
    !["apply", "dry-run", "inspect", "maintain"].includes(mode) ||
    !Number.isSafeInteger(runMs) ||
    runMs < 1 ||
    runMs > 420_000
  )
    throw new ActivityImportError("invalid_arguments");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), runMs);
  const signal = parentSignal
    ? AbortSignal.any([parentSignal, controller.signal])
    : controller.signal;
  const results = [];
  try {
    signal.throwIfAborted();
    let inspection, maintenance;
    // Maintenance is independently runnable; it does not depend on provider success.
    if (mode === "apply" || mode === "maintain")
      maintenance = await store.maintain(sources, signal);
    if (mode === "maintain")
      return { mode, status: "success", maintenance, sources: [] };
    if (mode !== "dry-run") {
      inspection = await store.inspect(sources, signal);
      if (
        !Array.isArray(inspection.sources) ||
        inspection.sources.length !== sources.length ||
        inspection.sources.some(
          (x, i) => x.id !== sources[i] || typeof x.configured !== "boolean",
        )
      )
        throw new ActivityImportError("invalid_payload");
      if (mode === "inspect")
        return {
          mode,
          status: inspection.sources.every((x) => x.configured)
            ? "success"
            : "unconfigured",
          inspection,
        };
    }
    for (const [index, id] of sources.entries()) {
      try {
        if (signal.aborted) throw new ActivityImportError("deadline");
        // Code-owned rights/coverage blocks precede all provider IO, including dry-run.
        const connector = resolve(id);
        const current = inspection?.sources[index];
        if (current) {
          const state = !current.configured
            ? "unconfigured"
            : connector.radar && !current.collection_enabled
              ? "collection_disabled"
              : !connector.radar && !current.rights_confirmed
                ? "rights_blocked"
                : !connector.radar && !current.enabled
                  ? "disabled"
                  : current.lease_state === "running"
                    ? "busy"
                    : null;
          if (state) {
            results.push({ id, state });
            continue;
          }
          const lastComplete = connector.radar
            ? current.last_collection_at
            : current.last_success_at;
          if (dueOnly && lastComplete) {
            const observed = Date.parse(lastComplete),
              asOf = Date.parse(inspection.as_of);
            if (
              !Number.isFinite(observed) ||
              !Number.isFinite(asOf) ||
              observed > asOf ||
              !Number.isInteger(policy[id])
            )
              throw new ActivityImportError("invalid_payload");
            if (asOf - observed < policy[id] * 3600000) {
              results.push({ id, state: "not_due" });
              continue;
            }
          }
        }
        const result = await importSource({
          connector,
          store,
          apply: mode === "apply",
          parentSignal: signal,
          fetchImpl,
        });
        if (connector.radar) {
          if (
            !["collected_held", "success"].includes(result.state) ||
            !["collected", "validated", "held", "publishable"].every(
              (key) =>
                Number.isSafeInteger(result[key]) &&
                result[key] >= 0 &&
                result[key] <= 2000,
            )
          )
            throw new ActivityImportError("invalid_payload");
          results.push({
            id,
            state: result.state,
            collected: result.collected,
            validated: result.validated,
            held: result.held,
            publishable: result.publishable,
            changed: result.changed,
            reasons: result.reasons,
            source_reasons: result.source_reasons,
            families: result.families,
          });
          continue;
        }
        // Only counts/codes are emitted. Never connector payloads, URLs or run tokens.
        const counts = {};
        for (const key of ["fetched", "accepted", "rejected", "changed"]) {
          const n = result[key];
          if (
            (n === null && key === "changed") ||
            (Number.isSafeInteger(n) && n >= 0 && n <= 2000)
          )
            counts[key] = n;
          else throw new ActivityImportError("invalid_payload");
        }
        if (result.state !== (mode === "apply" ? "success" : "validated"))
          throw new ActivityImportError("invalid_payload");
        const unknown = result.source_summary?.unknown_types ?? 0;
        if (!Number.isSafeInteger(unknown) || unknown < 0 || unknown > 2000)
          throw new ActivityImportError("invalid_payload");
        const invalidRecords = [
          "invalid_record",
          "unsupported_schedule",
        ].reduce((sum, key) => sum + (result.rejection_reasons?.[key] ?? 0), 0);
        if (
          !Number.isSafeInteger(invalidRecords) ||
          invalidRecords < 0 ||
          invalidRecords > result.rejected
        )
          throw new ActivityImportError("invalid_payload");
        const warning = unknown
          ? "unknown_source_types"
          : invalidRecords
            ? "source_record_drift"
            : null;
        results.push({
          id,
          state: warning ? "warning" : result.state,
          ...counts,
          ...(warning ? { code: warning } : {}),
          ...(unknown ? { unknown_types: unknown } : {}),
          ...(invalidRecords ? { invalid_records: invalidRecords } : {}),
        });
      } catch (error) {
        const code = signal.aborted
          ? "deadline"
          : error instanceof ActivityImportError && safeCodes.has(error.code)
            ? error.code
            : "internal_error";
        results.push({ id, state: "failed", code });
      }
    }
    const successes = results.filter((x) => good.has(x.state)).length;
    return {
      mode,
      status:
        successes === results.length
          ? "success"
          : successes
            ? "partial"
            : results.every((x) => x.state === "collected_held")
              ? "held"
              : "failure",
      ...(maintenance ? { maintenance } : {}),
      sources: results,
    };
  } catch (error) {
    throw new ActivityImportError(
      signal.aborted
        ? "deadline"
        : error instanceof ActivityImportError
          ? error.code
          : "internal_error",
    );
  } finally {
    clearTimeout(timer);
  }
}

// Extra registry coverage is explicit: <=8 selected sources in <=2 sequential
// four-source batches, each with the original seven-minute parent budget.
export async function runActivityOperations(options) {
  if (!Array.isArray(options.sources) || options.sources.length <= 4)
    return runActivityOperationBatch(options);
  if (options.batchSize !== 4 || options.sources.length > 8)
    throw new ActivityImportError("invalid_arguments");
  const deadline = AbortSignal.timeout(840_000);
  const parentSignal = options.parentSignal
    ? AbortSignal.any([options.parentSignal, deadline])
    : deadline;
  const batches = [];
  for (let at = 0; at < options.sources.length; at += 4) {
    batches.push(
      await runActivityOperationBatch({
        ...options,
        sources: options.sources.slice(at, at + 4),
        parentSignal,
      }),
    );
  }
  const states = batches.map((b) => b.status);
  return {
    mode: options.mode,
    status: states.every((s) => s === "success")
      ? "success"
      : states.every((s) => s === "held")
        ? "held"
        : states.some((s) => s === "success" || s === "partial")
          ? "partial"
          : "failure",
    batches,
    sources: batches.flatMap((b) => b.sources ?? []),
  };
}
