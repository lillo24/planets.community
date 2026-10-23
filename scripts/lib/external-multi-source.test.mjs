import assert from "node:assert/strict";
import test from "node:test";
import { normalizeActivity } from "./external-activities/records.mjs";
import { createActivityTransport } from "./external-activities/transport.mjs";
import {
  activityConnectorDirectory,
  resolveActivityConnector,
} from "./external-activities/connectors.mjs";

const api = "https://api.example.org";
const publicOrigin = "https://municipal.example.org";
const record = {
  upstream_id: "equipment-1",
  kind: "place",
  title: "Public court",
  description: null,
  category: "sports",
  canonical_url: publicOrigin + "/dataset",
  link_scope: "dataset",
  source_categories: ["Court"],
  status: "scheduled",
  publishable: true,
  occurrences: [],
  geometry: {
    latitude: 46.07,
    longitude: 11.12,
    precision: "venue",
    provenance_url: api + "/data/source",
  },
};
const code = (expected) => (error) => error.code === expected;

test("API and bounded source-specific public origins are independent", () => {
  const accepted = normalizeActivity(record, [api, publicOrigin]);
  assert.equal(accepted.link_scope, "dataset");
  assert.equal(accepted.geometry.provenance_url, api + "/data/source");
  assert.throws(() => normalizeActivity(record, api), code("invalid_record"));
  for (const canonical_url of [
    publicOrigin + ".evil.org/item",
    "http://municipal.example.org/item",
    publicOrigin + ":8443/item",
    "https://user:secret@municipal.example.org/item",
  ])
    assert.throws(
      () =>
        normalizeActivity({ ...record, canonical_url }, [api, publicOrigin]),
      code("invalid_record"),
    );
  assert.throws(
    () =>
      normalizeActivity({ ...record, link_scope: "booking" }, [
        api,
        publicOrigin,
      ]),
    code("invalid_record"),
  );
  assert.throws(
    () =>
      normalizeActivity(
        {
          ...record,
          geometry: {
            ...record.geometry,
            provenance_url: "https://evil.example.org/source",
          },
        },
        [api, publicOrigin],
      ),
    code("invalid_record"),
  );
});

function textTransport(fetchImpl, limits) {
  return createActivityTransport({
    origins: [api],
    apiPathPrefix: "/export/",
    fetchImpl,
    limits,
  });
}
test("CSV path has explicit MIME, UTF-8/BOM and the same byte/redirect budgets", async () => {
  const transport = textTransport(async (_, options) => {
    assert.equal(options.headers.accept, "text/csv");
    assert.equal(options.credentials, "omit");
    return new Response("\ufeffItem,Luogo\n1,Trènto\n", {
      headers: { "content-type": "text/csv; charset=utf-8" },
    });
  });
  assert.equal(
    (await transport.text(api + "/export/facilities")).value,
    "Item,Luogo\n1,Trènto\n",
  );
  assert.equal(transport.counts.pages, 1);
  assert.ok(transport.counts.bytes > 20);
  await assert.rejects(
    transport.text(api + "/export/facilities"),
    code("pagination_loop"),
  );
  for (const mime of ["text/html", "application/json", "application/zip", ""])
    await assert.rejects(
      textTransport(
        async () =>
          new Response("Item,Luogo", { headers: { "content-type": mime } }),
      ).text(api + "/export/facilities"),
      code("invalid_payload"),
    );
  await assert.rejects(
    textTransport(
      async () =>
        new Response(new Uint8Array([0xff, 0xfe]), {
          headers: { "content-type": "text/csv" },
        }),
    ).text(api + "/export/facilities"),
    code("invalid_payload"),
  );
  await assert.rejects(
    textTransport(
      async () =>
        new Response("a".repeat(30), {
          headers: { "content-type": "text/csv" },
        }),
      { responseBytes: 20 },
    ).text(api + "/export/facilities"),
    code("limit_exceeded"),
  );
  await assert.rejects(
    textTransport(
      async () =>
        new Response(null, {
          status: 302,
          headers: { location: publicOrigin + "/export/evil" },
        }),
    ).text(api + "/export/facilities"),
    code("unsafe_destination"),
  );
  await assert.rejects(
    textTransport(async () => {
      throw Error("must not fetch");
    }).text(api + "/export/facilities", { contentTypes: ["text/html"] }),
    code("invalid_transport_configuration"),
  );
});

test("source directory is code owned; blocked rights and unknown source stay failures", () => {
  assert.ok(Object.isFrozen(activityConnectorDirectory));
  assert.ok(activityConnectorDirectory.length <= 4);
  assert.throws(
    () => resolveActivityConnector("agenda-trento"),
    code("source_rights_checkpoint_blocked"),
  );
  assert.throws(
    () => resolveActivityConnector("https://arbitrary.example.org"),
    code("unknown_source"),
  );
});
