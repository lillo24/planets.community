import { randomUUID } from "node:crypto";

// Called only by the existing explicitly disposable local C smoke preparer.
// It adds a dedicated ordinary-member source without changing the General test.
export async function prepareConversion({ rpc, expected, people, group }) {
  const { creator, member, planner } = people;
  const setting = await rpc(creator, "get_group_discussion_settings", { ...expected(creator), p_group_id: group });
  const configured = await rpc(creator, "set_group_discussion_settings", { ...expected(creator), p_client_request_id: randomUUID(), p_group_id: group, p_expected_version: setting.version, p_creation_policy: "members" });
  const created = await rpc(member, "create_group_discussion_v2", { ...expected(member), p_client_request_id: randomUUID(), p_group_id: group, p_title: "A garden to build together", p_purpose: "Private planning before the public Project.", p_visibility: "group" });
  await rpc(planner, "join_group_discussion", { ...expected(planner), p_client_request_id: randomUUID(), p_room_id: created.room_id });
  await rpc(member, "send_group_discussion_message", { ...expected(member), p_client_request_id: randomUUID(), p_room_id: created.room_id, p_body: "Private conversion planning: our original garden idea." });
  await rpc(member, "send_group_discussion_message", { ...expected(member), p_client_request_id: randomUUID(), p_room_id: created.room_id, p_body: "The public Project must not copy this planning history." });
  await rpc(creator, "set_group_discussion_settings", { ...expected(creator), p_client_request_id: randomUUID(), p_group_id: group, p_expected_version: configured.version, p_creation_policy: "managers" });
  return { C_CONVERSION_ROOM: created.room_id };
}
