// UIAUDIT01 additional private invitation previews on the owned local world.
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc, operationId } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  await context.guard();
  people = await personaSessions(context);
  const { giulia } = people;
  const f = Object.fromEntries(
    (await sql`select fixture_key,receipt from mock_control.fixtures`).map(
      (r) => [r.fixture_key, r.receipt],
    ),
  );
  const roomId = f["idea:garden"].room_id;
  const room = await rpc(giulia, "get_group_discussion_v2", {
    p_expected_profile_id: giulia.id,
    p_room_id: roomId,
  });
  const ideaLink = await rpc(
    giulia,
    "create_group_discussion_invitation_link",
    {
      p_expected_profile_id: giulia.id,
      p_client_request_id: operationId("uiaudit01:idea-link"),
      p_room_id: roomId,
      p_expected_version: room.invitation_link_version,
    },
  );
  const authority = await rpc(giulia, "create_group_authority_invitation", {
    p_expected_profile_id: giulia.id,
    p_client_request_id: operationId("uiaudit01:group-authority-preview"),
    p_group_id: f["group:garden"],
    p_role: "co_organizer",
  });
  await writeFile(
    path.join(directory, "private-links.json"),
    JSON.stringify({ ideaLink, authority }, null, 2),
  );
  console.log(
    "Private Idea and Group authority previews created through ordinary RPCs.",
  );
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
