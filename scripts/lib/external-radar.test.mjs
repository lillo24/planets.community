import test from "node:test";
import assert from "node:assert/strict";
import {
  htmlDocument,
  feedEntries,
  jsonLdEvents,
  calendarEntries,
  wallTime,
  explicitItalianDates,
  sourceDate,
} from "./external-activities/extraction.mjs";
import {
  parseMuseDetail,
  parseSantaCalendar,
  parseArciDetail,
  parseSusatFeed,
  radarSources,
  radarConnector,
} from "./external-activities/radar-sources.mjs";
import {
  robotsPolicy,
  runRadarImport,
} from "./external-activities/radar-importer.mjs";
import { publicAddress } from "./external-activities/network.mjs";
import { createActivityTransport } from "./external-activities/transport.mjs";
import {
  activityOperationArguments,
  runActivityOperations,
} from "./external-activities/operations.mjs";

const code = (value) => (error) => error?.code === value;
const origin = "https://publisher.example.org";
const record = {
  upstream_id: "one",
  title: "Synthetic workshop",
  canonical_url: origin + "/events/one",
  category: "culture",
  activity_type: "workshops",
  source_categories: [],
  description: null,
  discipline: null,
  organizer: null,
  cost: null,
  audience: null,
  city: "Trento",
  venue: "Synthetic hall",
  address: null,
  status: "scheduled",
  publishable: true,
  source_modified_at: null,
  occurrences: [
    { kind: "date", start: "2026-10-25", end: null, timezone: "Europe/Rome" },
  ],
};
const entry = {
  upstream_id: "one",
  title: record.title,
  record,
  fields: { title: "h1", occurrences: "time[datetime]" },
  reason: null,
};
const connector = {
  sourceId: "synthetic-radar",
  parserVersion: "synthetic-v1",
  origin,
  origins: [origin],
  publicLinkOrigins: [origin],
  allowedPaths: ["/robots.txt", "/events/"],
  delayMs: 0,
  rightsState: "held_test",
  async collect({ document }) {
    return {
      complete: true,
      candidates: await document(origin + "/events/one", "html", () => [entry]),
    };
  },
};
const muse = (date, clock = "", venue = "MUSE") =>
  `<link rel="alternate" type="application/json" href="https://www.muse.it/wp-json/wp/v2/events/123"><h1 class="title">Synthetic workshop</h1><aside><li><svg><use xlink:href="#ico-pin"></use></svg><p>${venue}</p></li><li><svg><use xlink:href="#ico-calendar"></use></svg><p>${date}</p></li>${clock ? `<li><svg><use xlink:href="#clock"></use></svg><p>${clock}</p></li>` : ""}</aside>`;

test("MUSE distinguishes full event dates, explicit lists, source venue and unknown hours", () => {
  const [one] = parseMuseDetail(
    muse("Domenica 25 ottobre 2026", "Dalle 14 alle 19"),
    "https://www.muse.it/eventi/one/",
    "workshops",
  );
  assert.equal(one.reason, null);
  assert.equal(one.record.occurrences[0].start, "2026-10-25T13:00:00.000Z");
  assert.equal(one.record.geometry, null);
  assert.equal(one.record.description, null);
  const linked = muse("25 ottobre 2026")
    .replace(
      '<li><svg><use xlink:href="#ico-pin"></use></svg><p>MUSE</p></li>',
      '<a class="btn--inline-ico-alt" href="https://www.muse.it/home/pianifica-la-visita/come-arrivare/"><svg><use xlink:href="#map-pin"></use></svg>MUSE</a>',
    )
    .replace(
      '<li><svg><use xlink:href="#ico-calendar">',
      '<li class="btn--inline-ico-alt"><svg><use xlink:href="#ico-calendar">',
    );
  assert.equal(
    parseMuseDetail(linked, "https://www.muse.it/eventi/one/", "talks")[0]
      .reason,
    null,
    "Linked venue panels are sibling anchors, not list items",
  );
  const [several] = parseMuseDetail(
    muse("Martedì 6 ottobre, 3 novembre e 1 dicembre 2026", "Vedi incontri"),
    "https://www.muse.it/eventi/one/",
    "talks",
  );
  assert.equal(several.record.occurrences.length, 3);
  assert.equal(several.record.occurrences[1].kind, "date");
  assert.equal(
    parseMuseDetail(
      muse("25 ottobre 2026", "", "Museo di Predazzo"),
      "https://www.muse.it/eventi/one/",
      "workshops",
    )[0].reason,
    "outside_area",
  );
  assert.equal(
    parseMuseDetail(
      muse("Ogni martedì dal 20 ottobre al 10 novembre 2026"),
      "https://www.muse.it/eventi/one/",
      "workshops",
    )[0].reason,
    "ambiguous_schedule",
  );
  assert.deepEqual(explicitItalianDates("31 dicembre 2026 e 1 gennaio 2027"), [
    "2026-12-31",
    "2027-01-01",
  ]);
  assert.throws(
    () => explicitItalianDates("31 dicembre e 1 gennaio 2027"),
    code("ambiguous_schedule"),
  );
});
test("DST gaps/folds need an explicit offset; unambiguous Rome clocks convert correctly", () => {
  assert.throws(
    () => sourceDate("2026-02-30T10:00:00+01:00"),
    code("ambiguous_schedule"),
  );
  assert.throws(() => sourceDate("2026-99-99"), code("ambiguous_schedule"));
  assert.throws(
    () => wallTime("2026-03-29", "02:30"),
    code("ambiguous_schedule"),
  );
  assert.throws(
    () => wallTime("2026-10-25", "02:30"),
    code("ambiguous_schedule"),
  );
  assert.equal(wallTime("2026-10-24", "21:00"), "2026-10-24T19:00:00.000Z");
  assert.throws(
    () => wallTime("2026-02-30", "09:00"),
    code("ambiguous_schedule"),
  );
});

test("publisher query days and date-only window overlap use Europe/Rome rather than UTC dates", async () => {
  let submitted;
  await radarConnector("santa-chiara-events").collect({
    window: { start: "2026-10-24T23:30:00Z", end: "2026-10-25T23:30:00Z" },
    document: async (url, kind, parse, options) => {
      submitted = options.form;
      return [];
    },
  });
  assert.equal(
    new URLSearchParams(submitted).get("date-range"),
    "25/10/2026 - 26/10/2026",
  );
  const result = await runRadarImport({
    connector: {
      ...connector,
      async collect({ document }) {
        return {
          complete: true,
          candidates: await document(origin + "/events/one", "html", () => [
            {
              ...entry,
              record: {
                ...record,
                occurrences: [
                  {
                    kind: "date",
                    start: "2026-10-24",
                    end: null,
                    timezone: "Europe/Rome",
                  },
                ],
              },
            },
          ]),
        };
      },
    },
    now: () => new Date("2026-10-24T22:30:00Z"),
    fetchImpl: async (url) =>
      url.endsWith("/robots.txt")
        ? new Response("User-agent: *\nAllow: /", {
            headers: { "content-type": "text/plain" },
          })
        : new Response("<h1>Synthetic past date</h1>", {
            headers: { "content-type": "text/html" },
          }),
  });
  assert.equal(result.validated, 0);
  assert.equal(result.reasons.outside_window, 1);
});
const santaRow = (
  date,
  venue = "Teatro Sociale Trento",
  slug = "synthetic-show",
) =>
  `<div class="single_next_event color_rassegna giallo_cinema"><div class="sne_date">${date}</div><p class="sne_title">Synthetic show</p><p class="sne_location">${venue}</p><a href="/spettacoli/calendariospettacoli/${slug}">dettagli</a><div class="she_adv">Ingresso libero</div></div>`;
test("programme rows retain two showtimes and separate venues; no title/row-order identity", () => {
  const rows = parseSantaCalendar(
    santaRow("24 Ottobre, 2026 18.00") +
      santaRow("24 Ottobre, 2026 21.00") +
      santaRow("25 Ottobre, 2026 18.00", "Teatro Rovereto"),
    origin,
  );
  assert.equal(rows.length, 2);
  assert.equal(rows[0].record.occurrences.length, 2);
  assert.equal(rows[1].reason, "outside_area");
  assert.notEqual(rows[0].upstream_id, rows[1].upstream_id);
  assert.equal(rows[0].record.activity_type, "theatre-cinema");
  const mixed = parseSantaCalendar(
    santaRow("24 Ottobre, 2026 18.00").replace("giallo_cinema", "waikawa_gray"),
    origin,
  )[0];
  assert.equal(mixed.record.activity_type, null);
  assert.equal(mixed.reason, null);
  assert.throws(
    () => parseSantaCalendar("<html><h1>login</h1></html>", origin),
    code("source_record_drift"),
  );
});
test("RSS/Atom parse without entities/network expansion; publication never supplies event time", () => {
  const rss = `<rss><channel><item><guid>https://www.susat.it/?p=1</guid><title>25 ottobre 2026 – Synthetic outing</title><link>https://www.susat.it/outing/</link><pubDate>Mon, 19 Oct 2026 10:00:00 GMT</pubDate><description><![CDATA[Partenza al parcheggio Zuffo; iscrizioni per soci e non soci]]></description></item></channel></rss>`;
  const [event] = parseSusatFeed(rss);
  assert.equal(event.record.occurrences[0].start, "2026-10-25");
  assert.equal(event.published_at, "2026-10-19T10:00:00.000Z");
  assert.equal(event.record.city, null);
  assert.equal(event.record.geometry, null);
  assert.match(event.record.access, /destinazione esterna/);
  const atom =
    '<feed><entry><id>urn:test:1</id><title>Test</title><link rel="alternate" href="https://publisher.example.org/one"/><published>2026-01-01T00:00:00Z</published></entry></feed>';
  assert.equal(feedEntries(atom)[0].url, origin + "/one");
  for (const xml of [
    '<!DOCTYPE rss [<!ENTITY x SYSTEM "file:///secret">]><rss>&x;</rss>',
    "<rss><channel></rss>",
    '<rss><xi:include href="https://internal/"/></rss>',
  ])
    assert.throws(() => feedEntries(xml), code("unsafe_xml"));
});
test("JSON-LD is data only; exhibition spans are dates and default price zero stays unknown", () => {
  const e = {
    "@context": "https://unfetched.example.org/context",
    "@type": "Event",
    name: "Synthetic exhibition",
    url: origin + "/eventi/one/",
    startDate: "2026-10-10T10:00:00+02:00",
    endDate: "2027-06-06T20:00:00+02:00",
    location: {
      name: "Palazzo delle Albere",
      address: { addressLocality: "Trento" },
    },
    offers: { price: "0" },
  };
  const html = `<script type="application/ld+json">${JSON.stringify(e)}</script><a href="https://arcideltrentino.it/?method=ical&amp;id=7">Export</a><div class="mec-single-event-category">Categoria Mostra</div>`;
  assert.equal(jsonLdEvents(htmlDocument(html)).length, 1);
  const [item] = parseArciDetail(html, e.url);
  assert.equal(item.reason, null);
  assert.equal(item.record.cost, null);
  assert.equal(item.record.occurrences[0].kind, "date");
  assert.equal(item.record.occurrences[0].end, "2027-06-07");
  assert.throws(
    () =>
      jsonLdEvents(
        htmlDocument('<script type="application/ld+json">{bad}</script>'),
      ),
    code("invalid_jsonld"),
  );
});
test("bounded iCalendar keeps UID, recurrence exceptions, Rome DST and explicit date-only semantics", () => {
  const calendar = `BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:weekly\r\nSUMMARY:Synthetic class\r\nURL:${origin}/one\r\nDTSTART;TZID=Europe/Rome:20261018T100000\r\nDTEND;TZID=Europe/Rome:20261018T110000\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\nEXDATE;TZID=Europe/Rome:20261025T100000\r\nEND:VEVENT\r\nEND:VCALENDAR`;
  const [item] = calendarEntries(calendar);
  assert.equal(item.id, "weekly");
  assert.equal(item.occurrences.length, 2);
  assert.equal(item.occurrences[0].start, "2026-10-18T08:00:00.000Z");
  assert.equal(item.occurrences[1].start, "2026-11-01T09:00:00.000Z");
  assert.throws(
    () => calendarEntries(calendar.replace(";COUNT=3", "")),
    code("unsupported_schedule"),
  );
  assert.throws(
    () => calendarEntries(calendar.replace("COUNT=3", "COUNT=201")),
    code("unsupported_schedule"),
  );
  const date = calendarEntries(
    calendar
      .replace(
        "DTSTART;TZID=Europe/Rome:20261018T100000",
        "DTSTART;VALUE=DATE:20261018",
      )
      .replace(
        "DTEND;TZID=Europe/Rome:20261018T110000",
        "DTEND;VALUE=DATE:20261019",
      )
      .replace("RRULE:FREQ=WEEKLY;COUNT=3\r\n", "")
      .replace("EXDATE;TZID=Europe/Rome:20261025T100000\r\n", ""),
  )[0];
  assert.equal(date.occurrences[0].kind, "date");
  assert.equal(date.occurrences[0].end, "2026-10-19");
});
test("robots longest policy and delays apply; DNS refuses local/reserved addresses", () => {
  const p = robotsPolicy(
    "User-agent: *\nDisallow: /private/\nAllow: /private/public$\nCrawl-delay: 2",
  );
  assert.equal(p.delayMs, 2000);
  assert.equal(p.allows(origin + "/private/secret"), false);
  assert.equal(p.allows(origin + "/private/public"), true);
  assert.equal(p.allows(origin + "/private/public-more"), false);
  const specific = robotsPolicy(
    "User-agent: *\nAllow: /\nUser-agent: planets-radar\nDisallow: /",
  );
  assert.equal(specific.allows(origin + "/events"), false);
  const encoded = robotsPolicy(
    "User-agent: *\nDisallow: /events/FooA\nDisallow: /eventi/è",
  );
  assert.equal(encoded.allows(origin + "/events/Foo%41"), false);
  assert.equal(encoded.allows(origin + "/eventi/%C3%A8"), false);
  for (const ip of [
    "127.0.0.1",
    "10.0.0.1",
    "169.254.169.254",
    "::1",
    "::ffff:127.0.0.1",
    "2001:db8::1",
    "100.64.1.1",
  ])
    assert.equal(publicAddress(ip), false, ip);
  assert.equal(publicAddress("8.8.8.8"), true);
  assert.equal(publicAddress("2606:4700:4700::1111"), true);
});
test("HTML/XML/calendar MIME is opt-in and retains decompressed bytes, redirects and encoding bounds", async () => {
  const make = (fetchImpl, limits) =>
    createActivityTransport({
      origins: [origin],
      apiPathPrefix: "/",
      allowedPaths: ["/events/"],
      allowDocuments: true,
      fetchImpl,
      limits,
    });
  await assert.rejects(
    make(
      async () =>
        new Response("<h1>oversize</h1>", {
          headers: { "content-type": "text/html" },
        }),
      { responseBytes: 5 },
    ).text(origin + "/events/one", { contentTypes: ["text/html"] }),
    code("limit_exceeded"),
  );
  await assert.rejects(
    make(
      async () =>
        new Response("x", {
          headers: { "content-type": "text/html;charset=latin1" },
        }),
    ).text(origin + "/events/one", { contentTypes: ["text/html"] }),
    code("invalid_payload"),
  );
  await assert.rejects(
    make(
      async () =>
        new Response("", {
          status: 302,
          headers: { location: "https://127.0.0.1/" },
        }),
    ).text(origin + "/events/one", { contentTypes: ["text/html"] }),
    code("unsafe_destination"),
  );
  await assert.rejects(
    make(async () => new Response("", { status: 403 })).text(
      origin + "/events/one",
      { contentTypes: ["text/html"] },
    ),
    code("access_denied"),
  );
  await assert.rejects(
    make(async () => {
      throw Error("must not fetch");
    }).text(origin + "/events/%2e%2e/private", { contentTypes: ["text/html"] }),
    code("unsafe_destination"),
  );
});
test("a root 304 reuses only its exact parser revision; details are still fetched and partial traversal cannot finish", async () => {
  let finished = 0,
    failed = 0;
  const documents = [
    {
      url: origin + "/events/one",
      parser_version: connector.parserVersion,
      content_digest: "a".repeat(64),
      etag: '"v1"',
      last_modified: null,
      parsed: [entry],
    },
  ];
  const store = {
    beginRadar: async () => ({
      run_id: "test",
      started_at: "2026-10-24T00:00:00Z",
      documents,
    }),
    finishRadar: async (_, data) => {
      finished++;
      assert.equal(data.candidates.length, 1);
      return {
        state: "collected_held",
        publishable: 0,
        source_reasons: ["rights_held"],
      };
    },
    failRadar: async () => {
      failed++;
    },
  };
  const fetchImpl = async (url, options) =>
    url.endsWith("/robots.txt")
      ? new Response("User-agent: *\nAllow: /", {
          headers: { "content-type": "text/plain" },
        })
      : (assert.equal(options.headers["if-none-match"], '"v1"'),
        new Response(null, { status: 304 }));
  const result = await runRadarImport({
    connector,
    store,
    apply: true,
    fetchImpl,
  });
  assert.equal(result.validated, 1);
  assert.equal(result.publishable, 0);
  assert.equal(finished, 1);
  await assert.rejects(
    runRadarImport({
      connector: {
        ...connector,
        collect: async () => ({ complete: false, candidates: [entry] }),
      },
      store,
      apply: true,
      fetchImpl,
    }),
    code("incomplete_traversal"),
  );
  assert.equal(finished, 1);
  assert.equal(failed, 1);
});
test("source sets above four need explicit bounded batches and retain target-wide outcomes", async () => {
  const sources = radarSources
    .map((s) => s.sourceId)
    .concat("trento-open-sports-facilities");
  assert.throws(
    () =>
      activityOperationArguments(["--dry-run", "--sources", sources.join(",")]),
    code("invalid_source_set"),
  );
  assert.equal(
    activityOperationArguments([
      "--dry-run",
      "--batch-size",
      "4",
      "--sources",
      sources.join(","),
    ]).sources.length,
    5,
  );
  let calls = 0;
  const result = await runActivityOperations({
    sources,
    mode: "dry-run",
    batchSize: 4,
    resolve: (id) => ({ sourceId: id }),
    importSource: async () => {
      calls++;
      return {
        state: "validated",
        fetched: 1,
        accepted: 1,
        rejected: 0,
        changed: null,
      };
    },
  });
  assert.equal(result.batches.length, 2);
  assert.equal(result.sources.length, 5);
  assert.equal(result.status, "success");
  assert.equal(calls, 5);
});

test("the total Radar deadline bounds an unresponsive extractor and saves an explicit failure", async () => {
  let failed = 0,
    finished = 0;
  await assert.rejects(
    runRadarImport({
      connector: { ...connector, collect: () => new Promise(() => {}) },
      apply: true,
      limits: { runMs: 15 },
      store: {
        beginRadar: async () => ({
          run_id: "deadline-test",
          started_at: "2026-10-24T00:00:00Z",
          documents: [],
        }),
        failRadar: async () => {
          failed++;
        },
        finishRadar: async () => {
          finished++;
        },
      },
      fetchImpl: async () =>
        new Response("User-agent: *\nAllow: /", {
          headers: { "content-type": "text/plain" },
        }),
    }),
    code("deadline"),
  );
  assert.equal(failed, 1);
  assert.equal(finished, 0);
});
