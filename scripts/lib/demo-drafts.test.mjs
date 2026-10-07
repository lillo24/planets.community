import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  DEMO_DRAFTS,
  seedDemoDrafts,
  verifyDemoDrafts,
} from "./demo-drafts.mjs";

async function fixture(t) {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "planets-draft-test-"),
  );
  t.after(() => rm(directory, { recursive: true }));
  const rows = { project: [], table: [], listings: [] };
  const calls = [];
  const requests = new Map();
  let failCreate;
  const owner = randomUUID();
  const context = {
    status: { apiUrl: "http://127.0.0.1:59321" },
    personas: {
      alice: {
        id: owner,
        client: {
          async rpc(name, args) {
            calls.push(name);
            assert.equal(
              args.p_expected_creator_profile_id ??
                args.p_expected_owner_profile_id,
              owner,
            );
            if (name === "list_own_proposals")
              return { data: structuredClone(rows.project) };
            if (name === "list_own_recurring_activities")
              return { data: structuredClone(rows.table) };
            if (name === "list_own_resource_listings")
              return { data: structuredClone(rows.listings) };
            if (name === "recover_editor_proposal_draft")
              return { data: requests.get(args.p_client_request_id) ?? null };
            const id = randomUUID();
            const group =
              name === "create_editor_proposal_draft"
                ? "project"
                : name === "create_recurring_activity_draft"
                  ? "table"
                  : "listings";
            const key =
              group === "project"
                ? "proposal_id"
                : group === "table"
                  ? "recurring_activity_id"
                  : "listing_id";
            rows[group].push({
              [key]: id,
              title: args.p_title,
              lifecycle_state: "draft",
              listing_mode: args.p_listing_mode,
            });
            if (args.p_client_request_id)
              requests.set(args.p_client_request_id, id);
            if (name === failCreate) {
              failCreate = null;
              return { error: { code: "PT500" } };
            }
            return { data: id };
          },
        },
      },
    },
  };
  return {
    context,
    rows,
    calls,
    options: { receiptFile: path.join(directory, "receipts.json") },
    failNextCreate(name) {
      failCreate = name;
    },
  };
}

test("four ordinary creator drafts are seeded once and verification performs only canonical reads", async (t) => {
  const f = await fixture(t);
  await seedDemoDrafts(f.context, f.options);
  assert.equal(f.rows.project.length, 1);
  assert.equal(f.rows.table.length, 1);
  assert.equal(f.rows.listings.length, 2);
  assert.equal(new Set(DEMO_DRAFTS.map((d) => d.kind)).size, 4);
  const before = structuredClone(f.rows);
  await seedDemoDrafts(f.context, f.options);
  assert.deepEqual(f.rows, before);
  f.calls.length = 0;
  await verifyDemoDrafts(f.context, f.options);
  assert.ok(f.calls.every((name) => name.startsWith("list_own_")));
  assert.deepEqual(f.rows, before);
});

test("renaming, editing or publishing demo drafts never causes replacement or overwrite", async (t) => {
  const f = await fixture(t);
  await seedDemoDrafts(f.context, f.options);
  for (const row of Object.values(f.rows).flat()) {
    row.title = "User edited";
    row.lifecycle_state = "published";
  }
  const before = structuredClone(f.rows);
  await seedDemoDrafts(f.context, f.options);
  await verifyDemoDrafts(f.context, f.options);
  assert.deepEqual(f.rows, before);
});

for (const operation of [
  "create_editor_proposal_draft",
  "create_recurring_activity_draft",
  "create_resource_listing_draft",
]) {
  test(`committed unknown ${operation} result recovers without creating another draft`, async (t) => {
    const f = await fixture(t);
    f.failNextCreate(operation);
    await assert.rejects(
      seedDemoDrafts(f.context, f.options),
      /operation .* failed/u,
    );
    const creates = f.calls.filter((name) => name === operation).length;
    await seedDemoDrafts(f.context, f.options);
    await verifyDemoDrafts(f.context, f.options);
    assert.equal(
      f.calls.filter((name) => name === operation).length,
      operation === "create_resource_listing_draft" ? creates + 1 : creates,
    );
    assert.equal(Object.values(f.rows).flat().length, 4);
  });
}

test("lost or unavailable receipts fail instead of silently adopting, duplicating or reporting success", async (t) => {
  const f = await fixture(t);
  await assert.rejects(
    verifyDemoDrafts(f.context, f.options),
    /Missing project/u,
  );
  await seedDemoDrafts(f.context, f.options);
  f.rows.table.length = 0;
  await assert.rejects(
    seedDemoDrafts(f.context, f.options),
    /destination is unavailable/u,
  );
  await assert.rejects(
    verifyDemoDrafts(f.context, f.options),
    /table is absent/u,
  );
  await rm(f.options.receiptFile);
  await assert.rejects(seedDemoDrafts(f.context, f.options), /Unreceipted/u);
});
