import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFile, writeFile, rename } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

export const DEMO_DRAFTS = Object.freeze(
  [
    { kind: "project", title: "Bozza demo · Un pomeriggio per il quartiere" },
    { kind: "table", title: "Bozza demo · Tavolo di lettura" },
    { kind: "donate", title: "Bozza demo · Libri da donare" },
    { kind: "exchange", title: "Bozza demo · Materiali da scambiare" },
  ].map(Object.freeze),
);

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u;
const contracts = {
  project: {
    read: "list_own_proposals",
    create: "create_editor_proposal_draft",
    id: "proposal_id",
  },
  table: {
    read: "list_own_recurring_activities",
    create: "create_recurring_activity_draft",
    id: "recurring_activity_id",
  },
  donate: {
    read: "list_own_resource_listings",
    create: "create_resource_listing_draft",
    id: "listing_id",
  },
  exchange: {
    read: "list_own_resource_listings",
    create: "create_resource_listing_draft",
    id: "listing_id",
  },
};

async function rpc(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error)
    throw new Error(
      `Draft demo operation ${name} failed (${error.code ?? "unknown"}).`,
    );
  return data;
}

function identityParams(actor, kind) {
  return kind === "project" || kind === "table"
    ? { p_expected_creator_profile_id: actor }
    : { p_expected_owner_profile_id: actor };
}

function creationParams(actor, definition) {
  const params = {
    ...identityParams(actor, definition.kind),
    p_title: definition.title,
    p_description:
      "Bozza sintetica incompleta: completa i dati prima di pubblicare.",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Trento · luogo da concordare",
  };
  if (definition.kind === "donate" || definition.kind === "exchange") {
    return { ...params, p_listing_mode: definition.kind };
  }
  const project = {
    ...params,
    p_summary: null,
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_event_timezone: "Europe/Rome",
    p_registration_capacity: null,
    p_count_organizers_toward_capacity: false,
  };
  if (definition.kind === "project")
    return {
      ...project,
      p_client_request_id: randomUUID(),
      p_starts_at: null,
      p_ends_at: null,
      p_skill_ids: [],
      p_skill_importances: [],
    };
  return {
    ...project,
    p_topic: null,
    // An absent Tavolo schedule must not contain a lone timezone.
    p_event_timezone: null,
    p_recurrence_type: null,
    p_weekday: null,
    p_day_of_month: null,
    p_local_start_time: null,
    p_duration_minutes: null,
    p_effective_from: null,
  };
}

// Local tooling receipts identify rows even after the user renames/edits them.
// No credentials or content are stored. The world seeder already holds its
// database advisory lock. Tables/listings lack idempotent-create receipts, so a
// pending unknown result is recovered by its original title or fails closed.
export function draftReceiptPath(context) {
  const digest = createHash("sha256")
    .update(
      JSON.stringify([
        "ui-next02.v1",
        context.status.apiUrl,
        context.personas.alice.id,
      ]),
    )
    .digest("hex");
  return path.join(os.tmpdir(), `planets-demo-drafts-${digest}.json`);
}

async function loadReceipts(file) {
  let value;
  try {
    value = JSON.parse(await readFile(file, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return {};
    throw error;
  }
  assert.ok(
    value && typeof value === "object" && !Array.isArray(value),
    "Invalid draft demo receipts.",
  );
  for (const [kind, receipt] of Object.entries(value)) {
    assert.ok(
      contracts[kind] &&
        receipt &&
        (receipt.id === null || uuid.test(receipt.id)),
      "Invalid draft demo receipt identity.",
    );
    if (kind === "project")
      assert.ok(uuid.test(receipt.request), "Invalid draft creation request.");
  }
  return value;
}

async function saveReceipts(file, receipts) {
  const temporary = `${file}.${randomUUID()}.tmp`;
  await writeFile(temporary, `${JSON.stringify(receipts)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  await rename(temporary, file);
}

export async function seedDemoDrafts(
  context,
  { receiptFile = draftReceiptPath(context) } = {},
) {
  const owner = context.personas.alice;
  const receipts = await loadReceipts(receiptFile);
  for (const definition of DEMO_DRAFTS) {
    const contract = contracts[definition.kind];
    const rows = await rpc(
      owner.client,
      contract.read,
      identityParams(owner.id, definition.kind),
    );
    assert.ok(
      Array.isArray(rows),
      `Draft demo ${definition.kind} owner read was not a collection.`,
    );
    let receipt = receipts[definition.kind];
    if (receipt?.id) {
      assert.ok(
        rows.some((row) => row[contract.id] === receipt.id),
        `Draft demo ${definition.kind} receipt destination is unavailable; no replacement created.`,
      );
      continue; // Preserve edited content, including a user's explicit publication.
    }
    if (receipt) {
      const matches = rows.filter((row) => row.title === definition.title);
      if (definition.kind === "project") {
        receipt.id = await rpc(owner.client, "recover_editor_proposal_draft", {
          p_expected_creator_profile_id: owner.id,
          p_client_request_id: receipt.request,
        });
      } else {
        assert.equal(
          matches.length,
          1,
          `Draft demo ${definition.kind} has an uncertain first creation; reconcile its receipt before retrying.`,
        );
        receipt.id = matches[0][contract.id];
      }
      if (receipt.id) {
        assert.ok(uuid.test(receipt.id), "Invalid recovered draft ID.");
        await saveReceipts(receiptFile, receipts);
        continue;
      }
    } else {
      assert.ok(
        !rows.some((row) => row.title === definition.title),
        `Unreceipted draft demo ${definition.kind}; do not silently adopt or duplicate it.`,
      );
      receipt = {
        id: null,
        ...(definition.kind === "project" ? { request: randomUUID() } : {}),
      };
      receipts[definition.kind] = receipt;
      await saveReceipts(receiptFile, receipts);
    }
    const params = creationParams(owner.id, definition);
    if (definition.kind === "project")
      params.p_client_request_id = receipt.request;
    const id = await rpc(owner.client, contract.create, params);
    assert.ok(
      typeof id === "string" && uuid.test(id),
      `Draft demo ${definition.kind} creation returned no canonical ID.`,
    );
    receipt.id = id;
    await saveReceipts(receiptFile, receipts);
  }
}

export async function verifyDemoDrafts(
  context,
  { receiptFile = draftReceiptPath(context) } = {},
) {
  const owner = context.personas.alice;
  const receipts = await loadReceipts(receiptFile);
  for (const definition of DEMO_DRAFTS) {
    const contract = contracts[definition.kind];
    assert.ok(
      receipts[definition.kind]?.id,
      `Missing ${definition.kind} draft demo receipt; run the explicit seed on this disposable stack.`,
    );
    const rows = await rpc(
      owner.client,
      contract.read,
      identityParams(owner.id, definition.kind),
    );
    assert.ok(
      rows.some((row) => row[contract.id] === receipts[definition.kind].id),
      `Draft demo ${definition.kind} is absent from canonical owner management.`,
    );
  }
}
