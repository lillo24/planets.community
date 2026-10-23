// Additive UIAUDIT01 scenarios on this task's freshly seeded local world only.
// These use the original personas and ordinary RPCs, never replacement labels.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  people = await personaSessions(context);
  const receipts = Object.fromEntries(
    (await sql`select fixture_key,receipt from mock_control.fixtures`).map(
      (r) => [r.fixture_key, r.receipt],
    ),
  );
  const { giulia, marco, maya, iris, nora, teo } = people;
  const resource = await rpc(giulia, "request_resource_listing", {
    p_expected_requester_profile_id: giulia.id,
    p_listing_id: receipts["listing:donation"],
    p_message: "Vorrei usare i vasi per le erbe del quartiere.",
  });
  await rpc(marco, "accept_resource_listing_request", {
    p_expected_owner_profile_id: marco.id,
    p_request_id: resource,
  });
  const reverse = await rpc(giulia, "request_to_join_project", {
    p_expected_requester_profile_id: giulia.id,
    p_project_id: receipts["tavolo:repair"],
    p_request_message: "Posso aiutare con le piccole riparazioni.",
  });
  const actor = (p) => ({
    p_expected_profile_id: p.id,
    p_command_id: randomUUID(),
  });
  async function post(owner, title) {
    const draft = await rpc(owner, "mutate_cocreate_post", {
      ...actor(owner),
      p_operation: "create",
      p_content: {
        title,
        body: "Cerchiamo persone per incontrarci e provare questa attività insieme. Dati immaginari per la revisione UI.",
        locality: "Trento",
      },
    });
    return rpc(owner, "mutate_cocreate_post", {
      ...actor(owner),
      p_operation: "publish",
      p_post_id: draft.post_id,
      p_expected_version: draft.version,
    });
  }
  const drawing = await post(maya, "Passeggiata e disegno a Trento");
  const interest = await rpc(iris, "mutate_cocreate_interest", {
    ...actor(iris),
    p_operation: "request",
    p_post_id: drawing.post_id,
    p_note: "Mi piacerebbe partecipare alla passeggiata.",
  });
  const accepted = await rpc(maya, "mutate_cocreate_interest", {
    ...actor(maya),
    p_operation: "accept",
    p_post_id: drawing.post_id,
    p_interest_id: interest.interest_id,
  });
  await rpc(maya, "mutate_cocreate_contact", {
    ...actor(maya),
    p_operation: "send",
    p_contact_id: accepted.contact_id,
    p_body:
      "Ciao Iris, possiamo scegliere insieme il percorso della passeggiata.",
  });
  const games = await post(teo, "Serata di giochi da tavolo");
  const pending = await rpc(nora, "mutate_cocreate_interest", {
    ...actor(nora),
    p_operation: "request",
    p_post_id: games.post_id,
    p_note: "Mi piacerebbe imparare un nuovo gioco.",
  });
  const privateItems = await rpc(
    giulia,
    "list_own_scoped_conversation_items_v7",
    { p_expected_profile_id: giulia.id, p_scope: "private", p_limit: 21 },
  );
  const identities = privateItems.map((i) => `${i.item_kind}:${i.chat_id}`);
  assert.equal(
    new Set(identities).size,
    identities.length,
    "No repeated canonical chat identity",
  );
  const pairItems = privateItems.filter(
    (i) =>
      i.resource_counterparty_profile_id === marco.id ||
      i.project_request_counterparty_profile_id === marco.id,
  );
  assert.equal(
    pairItems.filter((i) => i.item_kind === "project_request_chat").length,
    1,
    "Reversed participation roles share one anchor",
  );
  assert.equal(
    pairItems.filter((i) => i.item_kind === "resource_chat").length,
    1,
    "Resource domain remains independently accessible",
  );
  const safe = {
    resourceRequest: resource,
    reversedParticipationRequest: reverse,
    drawingPost: drawing.post_id,
    gamesPost: games.post_id,
    contact: accepted.contact_id,
    acceptedInterest: interest.interest_id,
    pendingInterest: pending.interest_id,
    pairDiagnostic: pairItems.map((i) => ({
      kind: i.item_kind,
      chatId: i.chat_id,
      requestId: i.project_request_id ?? i.resource_request_id,
      counterparty:
        i.resource_counterparty_profile_id ??
        i.project_request_counterparty_profile_id,
      viewerRole: i.viewer_role,
    })),
    checks: [
      "canonical chat identities unique",
      "reversed participation roles share one anchor",
      "resource chat remains separate",
    ],
  };
  await writeFile(
    path.join(directory, "scenarios.json"),
    JSON.stringify(safe, null, 2),
  );
  console.log(
    "Additive scenarios ready; canonical pair checks 3/3. No original fixtures replaced.",
  );
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
