import { setTimeout as delay } from "node:timers/promises";

export class ActivityImportError extends Error {
  constructor(code) {
    super(`External activity import failed: ${code}.`);
    this.name = "ActivityImportError";
    this.code = code;
  }
}

export const activityImportLimits = Object.freeze({
  runMs: 300_000,
  requestMs: 15_000,
  responseBytes: 2_097_152,
  totalBytes: 16_777_216,
  pages: 50,
  related: 100,
  requests: 160,
  records: 2000,
  retries: 2,
  retryDelayMs: 15_000,
  redirects: 2,
});

// Origins and the path prefix are code-owned connector configuration, never
// supplied by a payload, CLI URL or client. Tests inject fetch, not live hosts.
export function createActivityTransport({
  origins,
  apiPathPrefix,
  signal,
  fetchImpl = fetch,
  sleep = (ms) => delay(ms, undefined, { signal }),
  now = Date.now,
  limits: overrides = {},
  allowedPaths,
  minDelayMs = 0,
  userAgent,
  allowDocuments = false,
}) {
  const limits = { ...activityImportLimits, ...overrides };
  if (
    !Array.isArray(origins) ||
    origins.length < 1 ||
    origins.length > 2 ||
    !apiPathPrefix?.startsWith("/") ||
    !apiPathPrefix.endsWith("/") ||
    Object.values(limits).some((n) => !Number.isSafeInteger(n) || n < 0)
  ) {
    throw new ActivityImportError("invalid_transport_configuration");
  }
  const allowed = new Set(origins);
  for (const origin of allowed) {
    const url = new URL(origin);
    if (url.protocol !== "https:" || url.origin !== origin) {
      throw new ActivityImportError("invalid_transport_configuration");
    }
  }
  const counts = { pages: 0, related: 0, requests: 0, bytes: 0 };
  const visitedPages = new Set();
  let lastRequest = null;
  function destination(input) {
    if (
      typeof input !== "string" ||
      /[\u0000-\u0020\u007f\\]|%(?:2f|5c|2e)/i.test(input)
    ) {
      throw new ActivityImportError("unsafe_destination");
    }
    let url;
    try {
      url = new URL(input);
    } catch {
      throw new ActivityImportError("unsafe_destination");
    }
    if (
      url.protocol !== "https:" ||
      !allowed.has(url.origin) ||
      url.username ||
      url.password ||
      url.hash ||
      !url.pathname.startsWith(apiPathPrefix) ||
      (allowedPaths &&
        !allowedPaths.some((path) =>
          path !== "/" && path.endsWith("/")
            ? url.pathname.startsWith(path)
            : url.pathname === path,
        )) ||
      url.href.length > 4096
    ) {
      throw new ActivityImportError("unsafe_destination");
    }
    return url;
  }
  async function read(
    input,
    { kind, etag, lastModified, textTypes, form } = {},
  ) {
    if (!["pages", "related"].includes(kind)) {
      throw new ActivityImportError("invalid_request_kind");
    }
    const initialUrl = destination(input);
    if (kind === "pages") {
      if (visitedPages.has(initialUrl.href))
        throw new ActivityImportError("pagination_loop");
      visitedPages.add(initialUrl.href);
    }
    if (++counts[kind] > limits[kind])
      throw new ActivityImportError("limit_exceeded");
    if (
      textTypes != null &&
      (!Array.isArray(textTypes) ||
        !textTypes.length ||
        textTypes.length > 8 ||
        textTypes.some(
          (type) =>
            !(
              allowDocuments
                ? [
                    "text/csv",
                    "application/csv",
                    "text/plain",
                    "text/html",
                    "application/xhtml+xml",
                    "application/rss+xml",
                    "application/atom+xml",
                    "application/xml",
                    "text/xml",
                    "text/calendar",
                  ]
                : ["text/csv", "application/csv", "text/plain"]
            ).includes(type),
        ))
    ) {
      throw new ActivityImportError("invalid_transport_configuration");
    }
    const headers = { accept: textTypes?.join(", ") ?? "application/json" };
    // Only a code-owned recipe may submit a bounded public calendar query.
    // Never use feed values to select a method, endpoint or form field.
    if (form != null) {
      if (
        typeof form !== "string" ||
        form.length > 4096 ||
        etag ||
        lastModified
      )
        throw new ActivityImportError("invalid_transport_configuration");
      headers["content-type"] = "application/x-www-form-urlencoded";
    }
    if (userAgent) headers["user-agent"] = userAgent;
    for (const [key, value] of [
      ["if-none-match", etag],
      ["if-modified-since", lastModified],
    ]) {
      if (value != null) {
        if (
          typeof value !== "string" ||
          value.length > 512 ||
          /[\r\n]/.test(value)
        ) {
          throw new ActivityImportError("invalid_conditional_header");
        }
        headers[key] = value;
      }
    }
    let url = initialUrl;
    let retries = 0;
    let redirects = 0;
    while (true) {
      signal?.throwIfAborted();
      if (++counts.requests > limits.requests)
        throw new ActivityImportError("limit_exceeded");
      const requestSignal = AbortSignal.any([
        ...(signal ? [signal] : []),
        AbortSignal.timeout(limits.requestMs),
      ]);
      let response;
      if (lastRequest != null && minDelayMs > 0)
        await sleep(Math.max(0, minDelayMs - (now() - lastRequest)));
      lastRequest = now();
      try {
        response = await fetchImpl(url.href, {
          method: form == null ? "GET" : "POST",
          ...(form == null ? {} : { body: form }),
          headers,
          redirect: "manual",
          signal: requestSignal,
          credentials: "omit",
        });
      } catch {
        throw new ActivityImportError(
          signal?.aborted ? "deadline" : "transport_error",
        );
      }
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        await response.body?.cancel();
        if (++redirects > limits.redirects)
          throw new ActivityImportError("redirect_limit");
        const location = response.headers.get("location");
        if (form != null) throw new ActivityImportError("unsafe_destination");
        if (!location) throw new ActivityImportError("unsafe_destination");
        url = destination(new URL(location, url).href);
        continue;
      }
      if ([408, 429, 502, 503, 504].includes(response.status)) {
        await response.body?.cancel();
        if (retries++ >= limits.retries)
          throw new ActivityImportError("upstream_error");
        const retryAfter = response.headers.get("retry-after");
        let ms = Math.min(1000 * 2 ** (retries - 1), limits.retryDelayMs);
        if (retryAfter != null) {
          if (
            !/^\d+$/.test(retryAfter) &&
            !/^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d{2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4} \d{2}:\d{2}:\d{2} GMT$/.test(
              retryAfter,
            )
          ) {
            throw new ActivityImportError("invalid_retry_after");
          }
          ms = /^\d+$/.test(retryAfter)
            ? Number(retryAfter) * 1000
            : Date.parse(retryAfter) - now();
          if (!Number.isFinite(ms))
            throw new ActivityImportError("invalid_retry_after");
          ms = Math.max(0, ms);
          // Never retry earlier than the provider asks. Long waits fail this run.
          if (ms > limits.retryDelayMs)
            throw new ActivityImportError("retry_after_exceeds_limit");
        }
        await sleep(ms);
        continue;
      }
      if (response.status === 304) {
        if (!etag && !lastModified)
          throw new ActivityImportError("unexpected_not_modified");
        return { notModified: true };
      }
      if (response.status !== 200) {
        await response.body?.cancel();
        throw new ActivityImportError(
          [401, 403].includes(response.status)
            ? "access_denied"
            : "upstream_error",
        );
      }
      const mime = (response.headers.get("content-type") ?? "")
        .split(";")[0]
        .trim()
        .toLowerCase();
      const charset = /(?:^|;)\s*charset\s*=\s*"?([^;"\s]+)/i.exec(
        response.headers.get("content-type") ?? "",
      )?.[1];
      if (textTypes && charset && !/^utf-?8$/i.test(charset)) {
        await response.body?.cancel();
        throw new ActivityImportError("invalid_payload");
      }
      if (
        textTypes
          ? !textTypes.includes(mime)
          : !/^application\/(?:[\w.-]+\+)?json$/i.test(mime)
      ) {
        await response.body?.cancel();
        throw new ActivityImportError("invalid_payload");
      }
      const declared = Number(response.headers.get("content-length"));
      if (
        declared > limits.responseBytes ||
        declared + counts.bytes > limits.totalBytes
      ) {
        await response.body?.cancel();
        throw new ActivityImportError("limit_exceeded");
      }
      const reader = response.body?.getReader();
      if (!reader) throw new ActivityImportError("invalid_payload");
      const chunks = [];
      let bytes = 0;
      try {
        while (true) {
          const chunk = await reader.read();
          requestSignal.throwIfAborted();
          if (chunk.done) break;
          bytes += chunk.value.byteLength;
          counts.bytes += chunk.value.byteLength;
          if (
            bytes > limits.responseBytes ||
            counts.bytes > limits.totalBytes
          ) {
            throw new ActivityImportError("limit_exceeded");
          }
          chunks.push(Buffer.from(chunk.value));
        }
      } catch (error) {
        await reader.cancel().catch(() => {});
        if (error instanceof ActivityImportError) throw error;
        throw new ActivityImportError(
          signal?.aborted ? "deadline" : "transport_error",
        );
      } finally {
        reader.releaseLock();
      }
      let value;
      try {
        const text = new TextDecoder("utf-8", { fatal: true }).decode(
          Buffer.concat(chunks),
        );
        value = textTypes ? text : JSON.parse(text);
      } catch {
        throw new ActivityImportError("invalid_payload");
      }
      return {
        notModified: false,
        value,
        etag: response.headers.get("etag"),
        lastModified: response.headers.get("last-modified"),
        fetchedAt: new Date(now()).toISOString(),
      };
    }
  }
  return {
    page: (url, options = {}) => read(url, { ...options, kind: "pages" }),
    related: (url, options = {}) => read(url, { ...options, kind: "related" }),
    // Only code-owned connectors select this MIME policy and exact export URL.
    // It shares all redirect, streamed/decompressed byte and request budgets.
    text: (url, { contentTypes, ...options } = {}) =>
      read(url, {
        ...options,
        kind: "pages",
        textTypes: contentTypes ?? ["text/csv"],
      }),
    counts,
  };
}
