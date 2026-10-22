import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import {
  ActivityImportError,
  createActivityTransport,
} from "./external-activities/transport.mjs";
import { normalizeActivity } from "./external-activities/records.mjs";
import {
  activityImportArguments,
  officialActivityConnector,
  runActivityImport,
} from "./external-activities/importer.mjs";

const origin = "https://api.example.org";
const endpoint = origin + "/api/events";
const fixture = (changes = {}) => ({
  upstream_id: "synthetic-1",
  title: "Synthetic cultural exhibition about sport",
  description:
    "Source-language plain text. Schedule and booking are not inferred.",
  canonical_url: origin + "/events/synthetic-1",
  category: "culture",
  source_categories: ["Exhibition"],
  status: "scheduled",
  publishable: true,
  occurrences: [
    {
      kind: "timed",
      start: "2026-10-24T10:00:00+02:00",
      end: "2026-10-24T11:00:00+02:00",
      timezone: "Europe/Rome",
    },
    {
      kind: "timed",
      start: "2026-10-31T10:00:00+01:00",
      end: "2026-10-31T11:00:00+01:00",
      timezone: "Europe/Rome",
    },
  ],
  ...changes,
});
const json = (value, options) => Response.json(value, options);
function transport(fetchImpl, limits = {}, rest = {}) {
  return createActivityTransport({
    origins: [origin],
    apiPathPrefix: "/api/",
    fetchImpl,
    limits,
    ...rest,
  });
}
const code = (value) => (error) =>
  error instanceof ActivityImportError && error.code === value;

test("official connector and CLI remain blocked, never successful empty imports", () => {
  assert.throws(
    () => officialActivityConnector("agenda-trento"),
    code("source_rights_checkpoint_blocked"),
  );
  const result = spawnSync(
    process.execPath,
    [
      "scripts/import-external-activities.mjs",
      "--source",
      "agenda-trento",
      "--dry-run",
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 1);
  assert.match(result.stderr, /source_rights_checkpoint_blocked/);
  assert.equal(result.stdout, "");
});
test("modes and explicit targets are required; conflicting/unknown flags fail", () => {
  assert.deepEqual(
    activityImportArguments(["--source", "agenda-trento", "--dry-run"]),
    { source: "agenda-trento", apply: false },
  );
  for (const args of [
    ["--source", "x"],
    ["--source", "x", "--apply"],
    ["--source", "x", "--apply", "--dry-run"],
    ["--source", "x", "--dry-run", "--target", "production"],
    ["--url", endpoint],
  ]) {
    assert.throws(
      () => activityImportArguments(args),
      code("invalid_arguments"),
    );
  }
});
test("canonical validation preserves explicit sessions, DST offsets, cancellation and unknown optional data", () => {
  const record = normalizeActivity(fixture(), origin);
  assert.equal(record.category, "culture");
  assert.equal(record.discipline, null);
  assert.equal(record.cost, null);
  assert.equal(record.source_modified_at, null);
  const blanks = normalizeActivity(fixture({ cost: "", venue: "  " }), origin);
  assert.equal(blanks.cost, null);
  assert.equal(blanks.venue, null);
  assert.equal(record.occurrences.length, 2);
  assert.ok(record.occurrences.some((o) => o.start.endsWith("+01:00")));
  assert.equal(
    normalizeActivity(fixture({ status: "cancelled" }), origin).status,
    "cancelled",
  );
  assert.equal(
    normalizeActivity(fixture({ occurrences: [] }), origin).occurrences.length,
    0,
  );
});
test("date/all-day values stay dates, use exclusive ends, reject invented midnight and invalid dates", () => {
  for (const kind of ["date", "all_day"]) {
    const record = normalizeActivity(
      fixture({
        occurrences: [
          {
            kind,
            start: "2026-10-25",
            end: "2026-10-26",
            timezone: "Europe/Rome",
          },
        ],
      }),
      origin,
    );
    assert.equal(record.occurrences[0].start, "2026-10-25");
    assert.throws(
      () =>
        normalizeActivity(
          fixture({
            occurrences: [
              { kind, start: "2026-02-30", timezone: "Europe/Rome" },
            ],
          }),
          origin,
        ),
      code("invalid_record"),
    );
    assert.throws(
      () =>
        normalizeActivity(
          fixture({
            occurrences: [
              {
                kind,
                start: "2026-10-25",
                end: "2026-10-25",
                timezone: "Europe/Rome",
              },
            ],
          }),
          origin,
        ),
      code("invalid_record"),
    );
  }
});
test("invalid/unbounded records and noncanonical URL/HTML/contact fields are rejected", () => {
  for (const changes of [
    { canonical_url: "javascript:alert(1)" },
    { canonical_url: "https://user:pass@api.example.org/event" },
    { canonical_url: "https://other.example.org/event" },
    { description: "<script>alert(1)</script>" },
    { title: "x".repeat(301) },
    { contact_email: "synthetic@example.org" },
    { source_categories: [42] },
    {
      occurrences: [
        {
          kind: "timed",
          start: "2026-10-25T10:00:00",
          timezone: "Europe/Rome",
        },
      ],
    },
    {
      occurrences: [
        {
          kind: "timed",
          start: "2026-10-25T10:00:00Z",
          timezone: "Unknown/Nowhere",
        },
      ],
    },
  ])
    assert.throws(
      () => normalizeActivity(fixture(changes), origin),
      code("invalid_record"),
    );
});
test("canonical ordering/deduplication avoids revisions from source ordering only", () => {
  const first = fixture();
  const second = fixture({
    occurrences: [...first.occurrences].reverse().concat(first.occurrences[0]),
  });
  assert.deepEqual(
    normalizeActivity(first, origin),
    normalizeActivity(second, origin),
  );
});
test("only code-owned HTTPS origins and API paths are fetched, including redirects", async () => {
  const seen = [];
  const t = transport(async (url, options) => {
    seen.push(url);
    assert.equal(options.redirect, "manual");
    return json({ entries: [] });
  });
  for (const url of [
    "http://api.example.org/api/events",
    "https://user@api.example.org/api/events",
    "https://api.example.org.evil.test/api/events",
    origin + "/other/events",
    endpoint + "#fragment",
    "file:///tmp/a",
  ]) {
    await assert.rejects(t.page(url), code("unsafe_destination"));
  }
  assert.equal(seen.length, 0);
  await t.page(endpoint);
  assert.equal(seen.length, 1);
  const redirect = transport(
    async () =>
      new Response(null, {
        status: 302,
        headers: { location: "http://127.0.0.1/private" },
      }),
  );
  await assert.rejects(redirect.page(endpoint), code("unsafe_destination"));
});
test("same-origin redirects are revalidated and bounded", async () => {
  let calls = 0;
  const t = transport(async () =>
    ++calls === 1
      ? new Response(null, {
          status: 302,
          headers: { location: "/api/redirected" },
        })
      : json({ ok: true }),
  );
  assert.deepEqual((await t.page(endpoint)).value, { ok: true });
  const loop = transport(
    async () =>
      new Response(null, { status: 302, headers: { location: endpoint } }),
  );
  await assert.rejects(loop.page(endpoint), code("redirect_limit"));
});
test("pagination loops and independent request/page/lookup budgets fail explicitly", async () => {
  const t = transport(async () => json({ ok: true }));
  await t.page(endpoint);
  await assert.rejects(t.page(endpoint), code("pagination_loop"));
  for (const [key, kind] of [
    ["pages", "page"],
    ["related", "related"],
    ["requests", "page"],
  ]) {
    await assert.rejects(
      transport(async () => json({}), { [key]: 0 })[kind](endpoint),
      code("limit_exceeded"),
    );
  }
});
test("429 retries honor seconds/date Retry-After and never retry earlier than a long request", async () => {
  const waits = [];
  let calls = 0;
  const t = transport(
    async () =>
      ++calls === 1
        ? new Response(null, { status: 429, headers: { "retry-after": "2" } })
        : json({}),
    {},
    { sleep: async (ms) => waits.push(ms) },
  );
  await t.page(endpoint);
  assert.deepEqual(waits, [2000]);
  const long = transport(
    async () =>
      new Response(null, { status: 429, headers: { "retry-after": "999" } }),
  );
  await assert.rejects(long.page(endpoint), code("retry_after_exceeds_limit"));
  calls = 0;
  const exhausted = transport(
    async () => {
      calls++;
      return new Response(null, { status: 503 });
    },
    { retries: 1 },
    { sleep: async () => {} },
  );
  await assert.rejects(exhausted.page(endpoint), code("upstream_error"));
  assert.equal(calls, 2);
  const fixed = Date.parse("2026-10-21T12:00:00Z");
  const dated = transport(
    async () =>
      ++calls === 3
        ? new Response(null, {
            status: 429,
            headers: { "retry-after": "Wed, 21 Oct 2026 12:00:03 GMT" },
          })
        : json({}),
    {},
    { sleep: async (ms) => waits.push(ms), now: () => fixed },
  );
  await dated.page(endpoint);
  assert.equal(waits.at(-1), 3000);
});
test("malformed JSON, HTML and truncated/upstream error pages cannot become empty success", async () => {
  for (const response of [
    new Response("<html>", { headers: { "content-type": "text/html" } }),
    new Response('{"unfinished":', {
      headers: { "content-type": "application/json" },
    }),
  ]) {
    await assert.rejects(
      transport(async () => response).page(endpoint),
      code("invalid_payload"),
    );
  }
  await assert.rejects(
    transport(async () => new Response(null, { status: 500 })).page(endpoint),
    code("upstream_error"),
  );
});
test("declared and streamed bytes are bounded, including decompressed and total response size", async () => {
  await assert.rejects(
    transport(async () => json({}, { headers: { "content-length": "9999" } }), {
      responseBytes: 10,
    }).page(endpoint),
    code("limit_exceeded"),
  );
  await assert.rejects(
    transport(async () => json({ long: "x".repeat(80) }), {
      responseBytes: 10,
    }).page(endpoint),
    code("limit_exceeded"),
  );
  const t = transport(async () => json({ a: 1 }), { totalBytes: 10 });
  await t.page(endpoint);
  await assert.rejects(t.related(endpoint), code("limit_exceeded"));
});
test("304 is explicit and requires an actual conditional request", async () => {
  let header;
  const t = transport(async (_, options) => {
    header = options.headers["if-none-match"];
    return new Response(null, { status: 304 });
  });
  assert.deepEqual(await t.page(endpoint, { etag: '"revision"' }), {
    notModified: true,
  });
  assert.equal(header, '"revision"');
  await assert.rejects(
    transport(async () => new Response(null, { status: 304 })).page(endpoint),
    code("unexpected_not_modified"),
  );
});

test("request deadlines abort slow IO and malformed Retry-After never becomes an early retry", async () => {
  const slow = transport(
    (_, { signal }) =>
      new Promise((resolve, reject) => {
        const timer = setTimeout(() => resolve(json({})), 100);
        signal.addEventListener(
          "abort",
          () => {
            clearTimeout(timer);
            reject(new DOMException("aborted", "AbortError"));
          },
          { once: true },
        );
      }),
    { requestMs: 5 },
  );
  await assert.rejects(slow.page(endpoint), code("transport_error"));
  await assert.rejects(
    transport(
      async () =>
        new Response(null, { status: 429, headers: { "retry-after": "0.5" } }),
    ).page(endpoint),
    code("invalid_retry_after"),
  );
  await assert.rejects(
    transport(async () => json({})).page(endpoint + String.fromCharCode(1)),
    code("unsafe_destination"),
  );
  assert.throws(
    () =>
      normalizeActivity(
        fixture({ canonical_url: origin + "/event/" + String.fromCharCode(1) }),
        origin,
      ),
    code("invalid_record"),
  );
});

function connector(entries, extra = {}) {
  return {
    sourceId: "synthetic",
    origins: [origin],
    officialOrigin: origin,
    apiPathPrefix: "/api/",
    collect: async () => ({ complete: true, entries }),
    ...extra,
  };
}
test("dry-run validates, reports explicit rejections and performs zero catalogue mutations", async () => {
  const result = await runActivityImport({
    connector: connector([
      { record: fixture() },
      { record: fixture({ title: "" }) },
      { rejection: "rights_not_permitted" },
    ]),
    store: {
      begin() {
        assert.fail();
      },
      finish() {
        assert.fail();
      },
    },
    now: () => new Date("2026-10-21T12:00:00Z"),
  });
  assert.equal(result.mode, "dry-run");
  assert.equal(result.accepted, 1);
  assert.equal(result.rejected, 2);
  assert.equal(result.changed, null);
});
test("apply calls one atomic completion only after complete validated collection", async () => {
  const calls = [];
  const store = {
    async begin(source) {
      calls.push(source);
      return { run_id: "run-1", started_at: "2026-10-21T12:00:00Z" };
    },
    async finish(id, value) {
      calls.push(value);
      assert.equal(id, "run-1");
      return {
        state: value.state,
        fetched: value.fetched,
        accepted: value.records.length,
        rejected: value.rejected,
        changed: 1,
      };
    },
  };
  const c = connector([{ record: fixture() }], {
    collect: async ({ window }) => {
      assert.equal(window.end, "2027-01-19T12:00:00.000Z");
      return { complete: true, entries: [{ record: fixture() }] };
    },
  });
  const result = await runActivityImport({ connector: c, store, apply: true });
  assert.equal(result.changed, 1);
  assert.equal(calls.length, 2);
});
test("incomplete pages, limits and duplicate identities never persist partial records", async () => {
  for (const c of [
    connector([], { collect: async () => ({ complete: false, entries: [] }) }),
    connector([{ record: fixture() }, { record: fixture() }]),
  ]) {
    let failed;
    const store = {
      begin: async () => ({
        run_id: "run",
        started_at: "2026-10-21T12:00:00Z",
      }),
      finish: async (_, input) => {
        failed = input;
        return {};
      },
    };
    await assert.rejects(
      runActivityImport({ connector: c, store, apply: true }),
    );
    assert.deepEqual(failed.records, []);
    assert.notEqual(failed.state, "success");
  }
});
test("total deadline bounds an unresponsive connector and uses a separate bounded failure receipt", async () => {
  let failure;
  await assert.rejects(
    runActivityImport({
      connector: connector([], { collect: () => new Promise(() => {}) }),
      apply: true,
      limits: { runMs: 10 },
      store: {
        begin: async () => ({
          run_id: "r",
          started_at: "2026-10-21T12:00:00Z",
        }),
        finish: async (_, input, signal) => {
          assert.equal(signal.aborted, false);
          failure = input;
          return {};
        },
      },
    }),
    code("deadline"),
  );
  assert.equal(failure.errorCode, "deadline");
});
test("unconfirmed completion cannot be reported as successful or safely recorded failure", async () => {
  await assert.rejects(
    runActivityImport({
      connector: connector([{ record: fixture() }]),
      apply: true,
      store: {
        begin: async () => ({
          run_id: "r",
          started_at: "2026-10-21T12:00:00Z",
        }),
        finish: async () => {
          throw new Error("do not log credentials");
        },
      },
    }),
    code("completion_unconfirmed"),
  );
});
