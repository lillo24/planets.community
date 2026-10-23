// UIAUDIT01 invitation and coordination fixtures on the owned fictional world.
// Run once after scenarios.mjs; capability receipts stay in the private directory.
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc, operationId } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  await context.guard();
  people = await personaSessions(context);
  const { giulia, sara, dario } = people;
  const f = Object.fromEntries(
    (await sql`select fixture_key,receipt from mock_control.fixtures`).map(
      (r) => [r.fixture_key, r.receipt],
    ),
  );
  const project = f["proposal:garden"],
    group = f["group:garden"];
  const participant = await rpc(
    giulia,
    "create_project_participant_invitation",
    { p_expected_profile_id: giulia.id, p_project_id: project },
  );
  const organizer = await rpc(giulia, "create_project_delegate_invitation", {
    p_expected_owner_profile_id: giulia.id,
    p_project_id: project,
    p_requested_authority_role: "co_organizer",
  });
  const groupParticipant = await rpc(
    giulia,
    "create_group_participant_invitation",
    {
      p_expected_profile_id: giulia.id,
      p_group_id: group,
      p_client_request_id: operationId("uiaudit01:group-participant"),
    },
  );
  await writeFile(
    path.join(directory, "private-relationships.json"),
    JSON.stringify({ participant, organizer, groupParticipant }, null, 2),
  );
  const third = await rpc(sara, "create_group_draft", {
    p_expected_profile_id: sara.id,
    p_client_request_id: operationId("uiaudit01:third-group"),
    p_content: {
      name: "Atelier immaginario",
      description:
        "Gruppo immaginario aggiuntivo per rivedere il consenso al coordinamento.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: false,
    },
  });
  await rpc(sara, "set_group_publication_state", {
    p_expected_profile_id: sara.id,
    p_client_request_id: operationId("uiaudit01:third-group-publish"),
    p_group_id: third,
    p_expected_version: 1,
    p_publication_state: "published",
  });
  const ideaInvitation = await rpc(sara, "invite_group_discussion_member", {
    p_expected_profile_id: sara.id,
    p_client_request_id: operationId("uiaudit01:idea-dario"),
    p_room_id: f["idea:garden"].room_id,
    p_profile_id: dario.id,
  });
  const coordination = await rpc(giulia, "submit_group_coordination_proposal", {
    p_expected_profile_id: giulia.id,
    p_action_id: operationId("uiaudit01:coordination"),
    p_source_chat_id: f["contact:groups:accept"].chat_id,
    p_group_ids: [third],
    p_title: "Laboratorio di quartiere",
    p_note: "Nuovo riepilogo immaginario, senza copiare i messaggi precedenti.",
  });
  await writeFile(
    path.join(directory, "private-relationships.json"),
    JSON.stringify(
      {
        participant,
        organizer,
        groupParticipant,
        ideaInvitation,
        coordination,
      },
      null,
      2,
    ),
  );
  console.log(
    "Ordinary RPC invitation/coordination scenarios ready; capabilities kept private.",
  );
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
