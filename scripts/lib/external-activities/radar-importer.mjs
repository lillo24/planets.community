import {
  ActivityImportError,
  activityImportLimits,
  createActivityTransport,
} from "./transport.mjs";
import { safeActivityFetch } from "./network.mjs";
import { digest, wallTime, nextDate } from "./extraction.mjs";
import { normalizeActivity } from "./records.mjs";

const mime = {
  html: ["text/html", "application/xhtml+xml"],
  rss: [
    "application/rss+xml",
    "application/atom+xml",
    "application/xml",
    "text/xml",
  ],
  calendar: ["text/calendar"],
};
const fail = (code) => {
  throw new ActivityImportError(code);
};

function beforeDeadline(promise, signal) {
  return new Promise((resolve, reject) => {
    const aborted = () => reject(new ActivityImportError("deadline"));
    signal.addEventListener("abort", aborted, { once: true });
    Promise.resolve(promise)
      .then(resolve, reject)
      .finally(() => signal.removeEventListener("abort", aborted));
    if (signal.aborted) aborted();
  });
}

// RFC9309 group selection, longest matching rule and Allow tie precedence.
// Unknown/malformed policies fail closed. robots availability is not reuse.
function robotsOctets(value) {
  return value
    .replace(/[^\x00-\x7f]/gu, (character) => encodeURIComponent(character))
    .replace(/%([a-f0-9]{2})/gi, (encoded, hex) => {
      const character = String.fromCharCode(Number.parseInt(hex, 16));
      return /^[a-z0-9._~-]$/i.test(character)
        ? character
        : encoded.toUpperCase();
    });
}
export function robotsPolicy(text, agent = "planets-radar") {
  const groups = [];
  let group = null,
    rulesStarted = false;
  for (const line of text.split(/\r?\n/)) {
    const clean = line.replace(/#.*/, "").trim();
    if (!clean) continue;
    const match = /^([\w-]+)\s*:\s*(.*)$/.exec(clean);
    if (!match) fail("invalid_robots");
    const [, raw, value] = match,
      key = raw.toLowerCase();
    if (key === "user-agent") {
      if (!group || rulesStarted) {
        group = { agents: [], rules: [], delay: 0 };
        groups.push(group);
        rulesStarted = false;
      }
      group.agents.push(value.toLowerCase());
    } else if (group && ["allow", "disallow", "crawl-delay"].includes(key)) {
      rulesStarted = true;
      if (key === "crawl-delay") {
        const seconds = Number(value);
        if (!Number.isFinite(seconds) || seconds < 0 || seconds > 30)
          fail("source_delay_exceeds_budget");
        group.delay = Math.max(group.delay, seconds * 1000);
      } else if (value)
        group.rules.push({ allow: key === "allow", path: robotsOctets(value) });
    }
  }
  const score = (g) =>
    Math.max(
      -1,
      ...g.agents.map((a) =>
        a === "*" ? 0 : agent.toLowerCase() === a ? a.length : -1,
      ),
    );
  const best = Math.max(-1, ...groups.map(score)),
    selected = groups.filter((g) => score(g) === best && best >= 0);
  const rules = selected.flatMap((g) => g.rules);
  return {
    delayMs: Math.max(0, ...selected.map((g) => g.delay)),
    allows(url) {
      const path = robotsOctets(new URL(url).pathname + new URL(url).search);
      const matches = rules.filter((r) =>
        new RegExp(
          "^" +
            r.path
              .split("*")
              .map((s) => s.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
              .join(".*")
              .replace(/\\\$$/, "$"),
        ).test(path),
      );
      matches.sort(
        (a, b) =>
          b.path.replace(/\*/g, "").length - a.path.replace(/\*/g, "").length ||
          Number(b.allow) - Number(a.allow),
      );
      return matches.length === 0 || matches[0].allow;
    },
  };
}

export async function runRadarImport({
  connector,
  store,
  apply = false,
  now = () => new Date(),
  limits: overrides = {},
  fetchImpl = safeActivityFetch,
  sleep,
  parentSignal,
}) {
  const limits = { ...activityImportLimits, ...overrides };
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), limits.runMs);
  const signal = parentSignal
    ? AbortSignal.any([parentSignal, controller.signal])
    : controller.signal;
  let run;
  try {
    signal.throwIfAborted();
    if (apply)
      run = await store.beginRadar(
        connector.sourceId,
        connector.parserVersion,
        signal,
      );
    const started = run?.started_at ?? now().toISOString();
    const transport = createActivityTransport({
      origins: connector.origins,
      apiPathPrefix: "/",
      allowedPaths: connector.allowedPaths,
      minDelayMs: connector.delayMs,
      userAgent: "PLANETS-Radar/1.0",
      allowDocuments: true,
      signal,
      limits,
      fetchImpl,
      sleep,
    });
    const robots = await beforeDeadline(
      transport.text(connector.origin + "/robots.txt", {
        contentTypes: ["text/plain"],
      }),
      signal,
    );
    const policy = robotsPolicy(robots.value);
    // A newly stricter publisher delay needs a reviewed registry update.
    if (policy.delayMs > connector.delayMs) fail("source_delay_changed");
    const documents = [],
      candidates = [];
    const cached = new Map((run?.documents ?? []).map((d) => [d.url, d]));
    async function document(url, kind, parse, options = {}) {
      const { context = null, ...requestOptions } = options;
      if (!policy.allows(url)) fail("robots_denied");
      const prior = cached.get(url);
      const reusable =
        prior?.parser_version === connector.parserVersion &&
        (prior.context ?? null) === context &&
        !requestOptions.form;
      const headers = reusable
        ? { etag: prior.etag, lastModified: prior.last_modified }
        : {};
      const response =
        kind === "json"
          ? await transport.page(url, { ...headers, ...requestOptions })
          : await transport.text(url, {
              ...headers,
              contentTypes: mime[kind],
              ...requestOptions,
            });
      let parsed, hash;
      if (response.notModified) {
        if (!reusable || !prior.parsed) fail("unexpected_not_modified");
        parsed = prior.parsed;
        hash = prior.content_digest;
      } else {
        hash = digest(
          typeof response.value === "string"
            ? response.value
            : JSON.stringify(response.value),
        );
        // Hash reuse confirms only this freshly fetched representation.
        parsed =
          reusable && prior.content_digest === hash
            ? prior.parsed
            : parse(response.value);
      }
      if (!Array.isArray(parsed)) fail("invalid_payload");
      const observed = new Date().toISOString();
      documents.push({
        url,
        parser_version: connector.parserVersion,
        context,
        content_digest: hash,
        etag: response.notModified ? prior.etag : response.etag,
        last_modified: response.notModified
          ? prior.last_modified
          : response.lastModified,
        fetched_at: observed,
        parsed,
      });
      // Evidence attached here is private and contains selectors, facts and a
      // digest, never raw HTML, images, contact paragraphs or script bodies.
      return parsed.map((item) =>
        item.upstream_id
          ? {
              ...item,
              evidence: {
                url,
                content_digest: hash,
                parser_version: connector.parserVersion,
                fetched_at: observed,
                fields: item.fields,
              },
            }
          : item,
      );
    }
    const collected = await beforeDeadline(
      connector.collect({
        document,
        signal,
        window: {
          start: started,
          end: new Date(Date.parse(started) + 90 * 86400000).toISOString(),
        },
      }),
      signal,
    );
    if (collected?.complete !== true || !Array.isArray(collected.candidates))
      fail("incomplete_traversal");
    if (collected.candidates.length > limits.records) fail("limit_exceeded");
    const ids = new Set(),
      reasons = {};
    let validated = 0;
    const families = {};
    for (const entry of collected.candidates) {
      if (!entry?.upstream_id || ids.has(entry.upstream_id))
        fail("duplicate_upstream_id");
      ids.add(entry.upstream_id);
      let record = null,
        reason = entry.reason ?? null;
      if (entry.record) {
        try {
          record = normalizeActivity(entry.record, connector.publicLinkOrigins);
        } catch (error) {
          if (error?.code !== "invalid_record") throw error;
          reason ??= "invalid_record";
        }
      }
      if (!record) reason ??= "invalid_record";
      if (
        record?.occurrences.length &&
        record.occurrences.every(
          (o) =>
            Date.parse(
              o.kind === "timed"
                ? (o.end ?? o.start)
                : wallTime(o.end ?? nextDate(o.start), "00:00", o.timezone),
            ) < Date.parse(started) ||
            Date.parse(
              o.kind === "timed"
                ? o.start
                : wallTime(o.start, "00:00", o.timezone),
            ) >
              Date.parse(started) + 90 * 86400000,
        )
      )
        reason ??= "outside_window";
      if (!reason) validated++;
      else reasons[reason] = (reasons[reason] ?? 0) + 1;
      const family = record?.activity_type ?? "unknown";
      families[family] = (families[family] ?? 0) + 1;
      candidates.push({
        upstream_id: entry.upstream_id,
        title: entry.title,
        record,
        evidence: entry.evidence,
        published_at: entry.published_at ?? null,
        reason,
      });
    }
    const counts = {
      collected: candidates.length,
      validated,
      held: candidates.length - validated,
      reasons,
      families,
    };
    if (apply) {
      const result = await store.finishRadar(
        run.run_id,
        { candidates, documents },
        signal,
      );
      return {
        source: connector.sourceId,
        ...result,
        ...counts,
        held: candidates.length - result.publishable,
        source_reasons: result.source_reasons,
      };
    }
    // Code-owned assessment is informational; it never grants owner approval.
    return {
      source: connector.sourceId,
      state: "collected_held",
      ...counts,
      held: candidates.length,
      publishable: 0,
      changed: null,
      source_reasons: [
        connector.rightsState,
        "owner_parser_qualification_required",
        "public_enablement_required",
      ],
    };
  } catch (error) {
    if (run) {
      try {
        await store.failRadar(
          run.run_id,
          signal.aborted ? "deadline" : "collection_failed",
          AbortSignal.timeout(10000),
        );
      } catch {
        throw new ActivityImportError("completion_unconfirmed");
      }
    }
    throw error instanceof ActivityImportError
      ? error
      : new ActivityImportError(signal.aborted ? "deadline" : "internal_error");
  } finally {
    clearTimeout(timer);
  }
}

export function radarImportStore(client) {
  async function rpc(name, params, signal) {
    const { data, error } = await client.rpc(name, params).abortSignal(signal);
    if (error) fail("persistence_error");
    return data;
  }
  return {
    beginRadar: (source, version, signal) =>
      rpc(
        "begin_external_radar_collection",
        { p_source_id: source, p_parser_version: version },
        signal,
      ),
    finishRadar: (run, input, signal) =>
      rpc(
        "finish_external_radar_collection",
        {
          p_run_id: run,
          p_candidates: input.candidates,
          p_documents: input.documents,
        },
        signal,
      ),
    failRadar: (run, code, signal) =>
      rpc(
        "fail_external_radar_collection",
        { p_run_id: run, p_error_code: code },
        signal,
      ),
  };
}
