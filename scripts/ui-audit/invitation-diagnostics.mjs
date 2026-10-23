// UIAUDIT01 additional private invitation previews on the owned local world.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  await context.guard();
  people = await personaSessions(context);
  const saved = JSON.parse(
    await readFile(path.join(directory, "private-links.json"), "utf8"),
  );
  const [fixture] = await sql`
    select receipt from mock_control.fixtures where fixture_key='idea:garden'
  `;
  const preview = await rpc(
    people.dario,
    "get_group_authority_invitation_preview",
    { p_token: saved.authority[0].invite_token },
  );
  const room = await rpc(people.dario, "get_group_discussion_v2", {
    p_expected_profile_id: people.dario.id,
    p_room_id: fixture.receipt.room_id,
  });
  const value = { authorityPreview: preview, admissionId: room.admission_id };
  await writeFile(
    path.join(directory, "invitation-diagnostic.json"),
    JSON.stringify(value, null, 2),
  );
  console.log(JSON.stringify(value));
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
