// UIAUDIT01 pagination, resource-need and saved-search fixtures in the owned world.
// Ordinary persona RPCs; no canonical fixture rewrite or hosted operation.
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc, operationId } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  await context.guard();
  people = await personaSessions(context);
  const { giulia, marco, iris } = people;
  const fixtures = Object.fromEntries(
    (await sql`select fixture_key,receipt from mock_control.fixtures`).map(
      (r) => [r.fixture_key, r.receipt],
    ),
  );
  const ids = [];
  for (let i = 1; i <= 22; i++) {
    const id = await rpc(marco, "create_editor_resource_listing_draft", {
      p_expected_owner_profile_id: marco.id,
      p_client_request_id: operationId("uiaudit01:paging:" + i),
      p_listing_mode: "donate",
      p_title: "Materiali di prova " + String(i).padStart(2, "0"),
      p_description:
        "Risorsa immaginaria per verificare la paginazione della casella messaggi.",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
    });
    await rpc(marco, "publish_resource_listing", {
      p_expected_owner_profile_id: marco.id,
      p_listing_id: id,
    });
    const request = await rpc(giulia, "request_resource_listing", {
      p_expected_requester_profile_id: giulia.id,
      p_listing_id: id,
      p_message: "Richiesta immaginaria per la revisione.",
    });
    await rpc(marco, "accept_resource_listing_request", {
      p_expected_owner_profile_id: marco.id,
      p_request_id: request,
    });
    ids.push({ listing: id, request });
  }
  const need = await rpc(giulia, "create_project_resource_need", {
    p_expected_creator_profile_id: giulia.id,
    p_project_id: fixtures["proposal:garden"],
    p_title: "Vasi",
    p_details: "Vasi per le erbe del quartiere; prova UI.",
  });
  const saved = await rpc(giulia, "create_resource_saved_search_v2", {
    p_expected_profile_id: giulia.id,
    p_query: "vasi",
    p_listing_mode: "donate",
    p_locality: "Trento",
    p_category_slug: null,
  });
  const first = await rpc(giulia, "list_own_scoped_conversation_items_v7", {
    p_expected_profile_id: giulia.id,
    p_scope: "private",
    p_limit: 21,
  });
  assert.equal(
    first.length,
    21,
    "Paging scenario must exceed the native page size",
  );
  assert.equal(
    new Set(first.map((x) => x.item_kind + ":" + x.chat_id)).size,
    21,
  );
  const safe = {
    pagination: ids,
    resourceNeed: need,
    savedSearch: saved,
    firstPage: first.map((x) => ({ kind: x.item_kind, chatId: x.chat_id })),
  };
  await writeFile(
    path.join(directory, "continuations.json"),
    JSON.stringify(safe, null, 2),
  );
  console.log(
    "22 additive resource conversations, populated need/search and native paging fixture verified.",
  );
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
