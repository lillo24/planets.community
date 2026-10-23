import {
  ActivityImportError,
  activityImportLimits,
  createActivityTransport,
} from "./transport.mjs";
import { normalizeActivity } from "./records.mjs";
import { resolveActivityConnector } from "./connectors.mjs";

const rejectionCodes = new Set([
  "invalid_record",
  "rights_not_permitted",
  "unsupported_schedule",
  "outside_window",
]);
const storedCodes = new Set([
  "upstream_error",
  "invalid_payload",
  "limit_exceeded",
  "transport_error",
  "deadline",
  "internal_error",
]);

export function officialActivityConnector(sourceId) {
  return resolveActivityConnector(sourceId);
}

export function activityImportArguments(args) {
  const result = { apply: false };
  let mode;
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--apply" || arg === "--dry-run") {
      if (mode) throw new ActivityImportError("invalid_arguments");
      mode = arg;
      result.apply = arg === "--apply";
    } else if (arg === "--source" || arg === "--target") {
      const key = arg.slice(2);
      if (result[key] || !args[i + 1] || args[i + 1].startsWith("--"))
        throw new ActivityImportError("invalid_arguments");
      result[key] = args[++i];
    } else throw new ActivityImportError("invalid_arguments");
  }
  if (
    !mode ||
    !/^[a-z][a-z0-9-]{0,63}$/.test(result.source ?? "") ||
    (result.apply && !/^[a-z][a-z0-9-]{0,63}$/.test(result.target ?? "")) ||
    (!result.apply && result.target)
  )
    throw new ActivityImportError("invalid_arguments");
  return result;
}

export async function runActivityImport({
  connector,
  store,
  apply = false,
  now = () => new Date(),
  limits: overrides = {},
  fetchImpl,
  sleep,
}) {
  const limits = { ...activityImportLimits, ...overrides };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), limits.runMs);
  const signal = controller.signal;
  let run;
  let fetched = 0;
  let rejected = 0;
  const reasons = {};
  try {
    if (apply) run = await store.begin(connector.sourceId, signal);
    const start = run ? new Date(run.started_at) : now();
    if (!Number.isFinite(start.getTime()))
      throw new ActivityImportError("invalid_payload");
    const transport = createActivityTransport({
      origins: connector.origins,
      apiPathPrefix: connector.apiPathPrefix,
      signal,
      limits,
      fetchImpl,
      sleep,
    });
    // Race the complete connector as well as bounding individual HTTP calls.
    const collected = await Promise.race([
      connector.collect({
        transport,
        signal,
        window: {
          start: start.toISOString(),
          end: new Date(start.getTime() + 90 * 86400000).toISOString(),
        },
      }),
      new Promise((_, reject) =>
        signal.addEventListener(
          "abort",
          () => reject(new ActivityImportError("deadline")),
          { once: true },
        ),
      ),
    ]);
    if (collected?.complete !== true || !Array.isArray(collected.entries))
      throw new ActivityImportError("invalid_payload");
    if (collected.entries.length > limits.records)
      throw new ActivityImportError("limit_exceeded");
    if (
      collected.summary != null &&
      (typeof collected.summary !== "object" ||
        Array.isArray(collected.summary) ||
        Object.keys(collected.summary).length > 12 ||
        Object.entries(collected.summary).some(
          ([key, value]) =>
            !/^[a-z_]{1,40}$/.test(key) ||
            !Number.isSafeInteger(value) ||
            value < 0 ||
            value > limits.records,
        ))
    )
      throw new ActivityImportError("invalid_payload");
    const records = [];
    const ids = new Set();
    for (const entry of collected.entries) {
      signal.throwIfAborted();
      fetched++;
      let rejection = entry?.rejection;
      if (rejection != null && !rejectionCodes.has(rejection))
        throw new ActivityImportError("invalid_payload");
      if (!rejection) {
        let record;
        try {
          record = normalizeActivity(
            entry?.record,
            connector.publicLinkOrigins ?? connector.officialOrigin,
          );
          if (connector.kinds && !connector.kinds.includes(record.kind))
            throw new ActivityImportError("invalid_record");
        } catch (error) {
          if (error?.code !== "invalid_record") throw error;
          rejection = "invalid_record";
        }
        if (record) {
          if (ids.has(record.upstream_id))
            throw new ActivityImportError("duplicate_upstream_id");
          ids.add(record.upstream_id);
          records.push(record);
        }
      }
      if (rejection) {
        rejected++;
        reasons[rejection] = (reasons[rejection] ?? 0) + 1;
      }
    }
    const result = apply
      ? await store.finish(
          run.run_id,
          { state: "success", records, fetched, rejected },
          signal,
        )
      : {
          state: "validated",
          fetched,
          accepted: records.length,
          rejected,
          changed: null,
        };
    return {
      mode: apply ? "apply" : "dry-run",
      ...result,
      rejection_reasons: reasons,
      ...(collected.summary == null
        ? {}
        : { source_summary: collected.summary }),
      transport: transport.counts,
    };
  } catch (error) {
    const code = signal.aborted
      ? "deadline"
      : error instanceof ActivityImportError
        ? error.code
        : "internal_error";
    if (run) {
      try {
        await store.finish(
          run.run_id,
          {
            state:
              code === "limit_exceeded" || code === "invalid_payload"
                ? "incomplete"
                : "failure",
            records: [],
            fetched,
            rejected,
            errorCode: storedCodes.has(code) ? code : "internal_error",
          },
          AbortSignal.timeout(10_000),
        );
      } catch {
        // A lost success response may already have committed. Never claim a
        // failure receipt was saved or overwrite a fenced/finished import.
        throw new ActivityImportError("completion_unconfirmed");
      }
    }
    throw new ActivityImportError(code);
  } finally {
    clearTimeout(timer);
  }
}

export function activityImportStore(client) {
  async function rpc(name, params, signal) {
    const { data, error } = await client.rpc(name, params).abortSignal(signal);
    if (error) throw new ActivityImportError("persistence_error");
    return data;
  }
  return {
    async begin(source, signal) {
      const data = await rpc(
        "begin_external_activity_import",
        { p_source_id: source },
        signal,
      );
      if (!data?.run_id || !data.started_at)
        throw new ActivityImportError("invalid_payload");
      return data;
    },
    async finish(runId, input, signal) {
      const data = await rpc(
        "finish_external_activity_import",
        {
          p_run_id: runId,
          p_state: input.state,
          p_records: input.records,
          p_fetched: input.fetched,
          p_rejected: input.rejected,
          p_error_code: input.errorCode ?? null,
        },
        signal,
      );
      if (
        data?.state !== input.state ||
        !["fetched", "accepted", "rejected", "changed"].every(
          (key) => Number.isInteger(data[key]) && data[key] >= 0,
        )
      )
        throw new ActivityImportError("invalid_payload");
      return data;
    },
  };
}
