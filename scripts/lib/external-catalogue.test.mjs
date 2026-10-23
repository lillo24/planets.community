import assert from "node:assert/strict";
import test from "node:test";
import { normalizeActivity } from "./external-activities/records.mjs";

const origin = "https://sports.example.org";
const place = (changes = {}) => ({
  upstream_id: "fixture",
  title: "Synthetic basketball court",
  kind: "place",
  canonical_url: origin + "/places/fixture",
  category: "sports",
  source_categories: ["Court"],
  status: "scheduled",
  publishable: true,
  occurrences: [],
  ...changes,
});
const schedule = (changes = {}) => ({
  season_start: "2026-10-01",
  season_end: "2026-12-20",
  timezone: "Europe/Rome",
  weekly: { days: [7, 3], start_time: "10:00" },
  exceptions: ["2026-10-25"],
  ...changes,
});
const normalize = (changes) => normalizeActivity(place(changes), origin);
const rejected = (changes) =>
  assert.throws(() => normalize(changes), { code: "invalid_record" });

test("places do not invent prose, dates, prices, opening hours or exact coordinates", () => {
  const item = normalize({});
  assert.equal(item.description, null);
  assert.equal(item.cost, null);
  assert.equal(item.access, null);
  assert.equal(item.geometry, null);
  assert.deepEqual(item.occurrences, []);
  for (const precision of ["venue", "locality"]) {
    const geometry = {
      latitude: 46.07,
      longitude: 11.12,
      precision,
      provenance_url: origin + "/dataset",
    };
    assert.deepEqual(normalize({ geometry }).geometry, geometry);
  }
});

test("course term, weekly wall clocks, cancelled lesson and unknown end stay explicit", () => {
  const item = normalize({ kind: "course", schedule: schedule() });
  assert.equal(item.kind, "course");
  assert.deepEqual(item.schedule.weekly, {
    days: [3, 7],
    start_time: "10:00",
    end_time: null,
  });
  assert.deepEqual(item.schedule.exceptions, ["2026-10-25"]);
  assert.equal(item.schedule.timezone, "Europe/Rome");
  assert.deepEqual(item.occurrences, []);
  const unknown = normalize({
    kind: "course",
    schedule: schedule({
      weekly: null,
      text: "Ask the source for session times",
    }),
  });
  assert.equal(unknown.schedule.weekly, null);
  assert.equal(unknown.schedule.text, "Ask the source for session times");
});

test("invalid geometry and unpublished precision/provenance cannot pass canonical validation", () => {
  const geometry = {
    latitude: 46,
    longitude: 11,
    precision: "venue",
    provenance_url: origin + "/dataset",
  };
  for (const change of [
    { latitude: Infinity },
    { latitude: 91 },
    { longitude: -181 },
    { longitude: "11" },
    { precision: null },
    { precision: "inferred" },
    { provenance_url: "https://other.example.org/" },
    { provenance_url: origin + "/bad path" },
    { private_location_id: "forbidden" },
  ])
    rejected({ geometry: { ...geometry, ...change } });
});

test("only finite complete rules may derive sessions; malformed and unsupported schedule keys fail", () => {
  for (const change of [
    { season_end: null },
    { season_start: null },
    { timezone: null },
    { season_start: "2026-02-30" },
    { season_end: "2028-12-20" },
    { season_end: "2026-09-01" },
    { timezone: "invalid/zone" },
    { weekly: { days: [0], start_time: "10:00" } },
    { weekly: { days: [1, 1], start_time: "10:00" } },
    { weekly: { days: [1], start_time: "24:00" } },
    { weekly: { days: [1], start_time: "10:00", end_time: "09:00" } },
    { exceptions: ["2027-01-01"] },
    { text: "<script>bad</script>" },
    { rrule: "FREQ=DAILY" },
  ]) {
    rejected({ kind: "course", schedule: schedule(change) });
  }
  rejected({ kind: "facility" });
  rejected({ kind: "place", schedule: schedule() });
  rejected({
    kind: "place",
    occurrences: [
      { kind: "date", start: "2026-10-25", timezone: "Europe/Rome" },
    ],
  });
});

test("legacy events retain their exact disjoint DST offsets and accept absent prose", () => {
  const item = normalize({
    kind: "event",
    description: null,
    occurrences: [
      {
        kind: "timed",
        start: "2026-10-24T10:00:00+02:00",
        timezone: "Europe/Rome",
      },
      {
        kind: "timed",
        start: "2026-10-31T10:00:00+01:00",
        timezone: "Europe/Rome",
      },
    ],
  });
  assert.equal(item.occurrences.length, 2);
  assert.equal(item.description, null);
  assert.ok(item.occurrences[0].start.endsWith("+02:00"));
  assert.ok(item.occurrences[1].start.endsWith("+01:00"));
});
