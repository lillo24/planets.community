import assert from "node:assert/strict";
import test from "node:test";
import {
  mapTrentoFacilities,
  municipalPlaceLink,
  parseMunicipalCsv,
  trentoFacilitiesConnector,
  trentoFacilitiesSource,
} from "./external-activities/trento-facilities.mjs";
import { runActivityImport } from "./external-activities/importer.mjs";

const header = [
  "Item",
  "Tipo di impianto",
  "Luogo",
  "Ingresso da",
  "Link",
  "Coordinate GPS",
  "Note",
];
const cell = (value) => '"' + String(value).replaceAll('"', '""') + '"';
function csv(rows, columns = header) {
  return (
    [columns, ...rows].map((r) => r.map(cell).join(",")).join("\r\n") + "\r\n"
  );
}
const anchor =
  '<a href="https://www.comune.trento.it/Vivere-il-Comune/Luoghi/Giardino-Test " target="_blank">Vai al luogo</a>';
const sample = (id = "5") => [
  id,
  "Pallacanestro",
  'Giardino "pubblico", Trènto',
  "via Fonte\nsecondo ingresso",
  anchor,
  "46.07, 11.12",
  "",
];
const invalid = (error) => error.code === "invalid_payload";

test("strict municipal CSV supports BOM, quoted multiline/commas/quotes and reordered Unicode headers", () => {
  const text = "\ufeff" + csv([sample()]);
  assert.equal(parseMunicipalCsv(text)[0].Luogo, 'Giardino "pubblico", Trènto');
  assert.equal(
    parseMunicipalCsv(text)[0]["Ingresso da"],
    "via Fonte\nsecondo ingresso",
  );
  const reversed = [...header].reverse();
  assert.equal(
    parseMunicipalCsv(csv([[...sample()].reverse()], reversed))[0].Item,
    "5",
  );
  for (const malformed of [
    text.slice(0, -5),
    csv([sample().slice(0, 6)]),
    csv([sample()], [...header.slice(0, 6), "Item"]),
    csv([sample()], [...header.slice(0, 6), "Private notes"]),
    "Item,Luogo\n1,Trento",
    csv([]),
    csv([sample()]) + '"unclosed',
  ])
    assert.throws(() => parseMunicipalCsv(malformed), invalid);
});

test("published Item identity, equipment/type and optional description/geometry stay factual", () => {
  const first = sample();
  const second = sample("11");
  second[1] = "Ping pong";
  second[4] = "";
  second[5] = "";
  const result = mapTrentoFacilities(csv([first, second]));
  assert.deepEqual(result.summary, {
    equipment_records: 2,
    named_places: 1,
    dataset_links: 1,
    missing_geometry: 1,
    unknown_types: 0,
  });
  assert.equal(result.entries[0].record.upstream_id, "5");
  assert.equal(result.entries[0].record.discipline, "basketball");
  assert.equal(result.entries[0].record.geometry.latitude, 46.07);
  assert.equal(result.entries[1].record.geometry, null);
  assert.equal(result.entries[1].record.link_scope, "dataset");
  assert.equal(
    result.entries[1].record.canonical_url,
    trentoFacilitiesSource.datasetUrl,
  );
  for (const { record } of result.entries) {
    assert.equal(record.kind, "place");
    assert.equal(record.description, null);
    assert.equal(record.address, null);
    assert.equal(record.cost, null);
    assert.deepEqual(record.occurrences, []);
    assert.equal(record.organizer, null);
  }
  assert.throws(() => mapTrentoFacilities(csv([sample(), sample()])), invalid);
  for (const gps of ["11.12, 46.07", "not coordinates", "Infinity,11", "0,0"]) {
    const row = sample();
    row[5] = gps;
    assert.throws(() => mapTrentoFacilities(csv([row])), invalid);
  }
  const unfamiliar = sample();
  unfamiliar[1] = "New source equipment";
  assert.equal(
    mapTrentoFacilities(csv([unfamiliar])).entries[0].record.discipline,
    "other-sports",
  );
});

test("only one safe municipal place anchor is decoded; no linked page is fetched", () => {
  assert.equal(
    municipalPlaceLink(anchor),
    "https://www.comune.trento.it/Vivere-il-Comune/Luoghi/Giardino-Test",
  );
  assert.equal(municipalPlaceLink(""), null);
  assert.equal(
    municipalPlaceLink(
      '<a href="https://www.comune.trento.it/Vivere-il-Comune/Luoghi/Giardino&#45;Test">link</a>',
    ),
    "https://www.comune.trento.it/Vivere-il-Comune/Luoghi/Giardino-Test",
  );
  for (const bad of [
    anchor + anchor,
    "<script>evil</script>",
    anchor.replace("https:", "javascript:"),
    anchor.replace("www.comune.trento.it", "evil.example.org"),
    anchor.replace("Giardino-Test ", "Giardino Test"),
    anchor.replace("/Luoghi/", "/Luoghi/%2f"),
    anchor.replace(" target=", " onclick="),
    anchor.replace(' target="_blank"', ' href="https://evil.example.org"'),
  ])
    assert.throws(() => municipalPlaceLink(bad), invalid);
});

test("real connector policy allows one exact CSV export and dry run has zero persistence", async () => {
  const calls = [];
  let writes = 0;
  const result = await runActivityImport({
    connector: trentoFacilitiesConnector(),
    apply: false,
    store: { begin: () => writes++, finish: () => writes++ },
    fetchImpl: async (url) => {
      calls.push(url);
      return new Response(csv([sample()]), {
        headers: { "content-type": "text/csv; charset=utf-8" },
      });
    },
  });
  assert.deepEqual(calls, [trentoFacilitiesSource.resourceUrl]);
  assert.equal(writes, 0);
  assert.equal(result.accepted, 1);
  assert.equal(result.source_summary.equipment_records, 1);
  assert.equal(result.transport.requests, 1);
});
