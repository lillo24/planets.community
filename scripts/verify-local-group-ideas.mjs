import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Non-resetting real Auth qualification. Run only against the owned C stack.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const value of [status.apiUrl, status.databaseUrl, mailpitUrl])
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(value).hostname),
  );
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
function equal(actual, expected, label) {
  assert.deepEqual(actual, expected, label);
  checks++;
}
const expected = (p) => ({ p_expected_profile_id: p.id });
const command = (p, room) => ({
  ...expected(p),
  p_client_request_id: randomUUID(),
  ...(room ? { p_room_id: room } : {}),
});
async function rpc(p, name, args) {
  const response = await p.client.rpc(name, args);
  assert.equal(
    response.error?.code ?? null,
    null,
    `${name}: ${response.error?.message ?? "ok"}`,
  );
  checks++;
  return response.data;
}
async function denied(p, name, args, code = "42501") {
  const response = await p.client.rpc(name, args);
  equal(response.error?.code, code, `${name} denied`);
}
async function user(label) {
  const p = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `cr-${run}-${label}@planets.invalid`,
    verifierName: "group-ideas",
  });
  await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Fictional C revision ${label}`})`;
  return p;
}
const get = (p, room) =>
  rpc(p, "get_group_discussion_v2", { ...expected(p), p_room_id: room });
const history = (p, room, extra = {}) =>
  rpc(p, "get_group_discussion_message_page_v2", {
    ...expected(p),
    p_room_id: room,
    ...extra,
  });
const send = (p, room, body) =>
  rpc(p, "send_group_discussion_message", {
    ...command(p, room),
    p_body: body,
  });
const join = (p, room) => rpc(p, "join_group_discussion", command(p, room));
const rooms = (p, group, extra = {}) =>
  rpc(p, "list_group_discussions_v2", {
    ...expected(p),
    p_group_id: group,
    ...extra,
  });
const notices = (p, extra = {}) =>
  rpc(p, "list_own_group_discussion_notices", { ...expected(p), ...extra });
const invite = (p, target, room) =>
  rpc(p, "invite_group_discussion_member", {
    ...command(p, room),
    p_profile_id: target.id,
  });
const accept = (p, invitation) =>
  rpc(p, "respond_group_discussion_invitation", {
    ...command(p, invitation.room_id),
    p_invitation_id: invitation.object_id,
    p_response: "accepted",
  });
const leave = (p, room, admission) =>
  rpc(p, "leave_group_discussion", {
    ...command(p, room),
    p_admission_id: admission,
  });
const create = (p, group, title, visibility = "group") =>
  rpc(p, "create_group_discussion_v2", {
    ...command(p),
    p_group_id: group,
    p_title: title,
    p_purpose: "Fictional local planning purpose.",
    p_visibility: visibility,
  });
const prefs = (p, room, muted, hidden) =>
  rpc(p, "set_group_discussion_preferences", {
    ...command(p, room),
    p_muted: muted,
    p_hidden: hidden,
  });

try {
  const alice = await user("Alice"),
    bea = await user("Bea"),
    carlo = await user("Carlo"),
    diana = await user("Diana"),
    manager = await user("Manager");
  const group = await rpc(alice, "create_group_draft", {
    ...command(alice),
    p_content: {
      name: `Fictional CR ${run}`,
      description: "Fictional Group planning collaborative local activities.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  equal(
    (
      await sql`select count(*)::int n from private.group_discussions where group_id=${group}::uuid and kind='general'`
    )[0].n,
    0,
    "Draft has no General",
  );
  await rpc(alice, "set_group_publication_state", {
    ...command(alice),
    p_group_id: group,
    p_expected_version: 1,
    p_publication_state: "published",
  });
  await sql`update private.community_groups set publication_state='published' where id=${group}::uuid`;
  equal(
    (
      await sql`select count(*)::int n from private.group_discussions where group_id=${group}::uuid and kind='general'`
    )[0].n,
    1,
    "Repeated publication creates exactly one General",
  );
  const [sharing] = await rpc(alice, "create_group_participant_invitation", {
    ...command(alice),
    p_group_id: group,
  });
  const memberships = new Map();
  for (const person of [bea, carlo, manager]) {
    const [membership] = await rpc(
      person,
      "accept_group_participant_invitation",
      { ...command(person), p_token: sharing.invite_token },
    );
    memberships.set(person.id, membership);
  }
  const [offer] = await rpc(alice, "create_group_authority_invitation", {
    ...command(alice),
    p_group_id: group,
    p_role: "co_organizer",
  });
  await rpc(manager, "accept_group_authority_invitation", {
    ...command(manager),
    p_token: offer.invite_token,
  });
  let settings = await rpc(bea, "get_group_discussion_settings", {
    ...expected(bea),
    p_group_id: group,
  });
  equal(settings.creation_policy, "managers", "Creation starts managers-only");
  const general = settings.general_room_id;
  equal(
    (await get(bea, general)).access,
    "general",
    "Current Group membership automatically opens General",
  );
  equal(
    (await history(bea, general)).items,
    [],
    "Empty General is a legitimate empty history",
  );
  await denied(diana, "get_group_discussion_v2", {
    ...expected(diana),
    p_room_id: general,
  });
  await denied(bea, "create_group_discussion_v2", {
    ...command(bea),
    p_group_id: group,
    p_title: "Denied",
    p_purpose: "",
    p_visibility: "group",
  });
  await denied(manager, "set_group_discussion_settings", {
    ...command(manager),
    p_group_id: group,
    p_expected_version: settings.version,
    p_creation_policy: "members",
  });
  await rpc(alice, "set_group_discussion_settings", {
    ...command(alice),
    p_group_id: group,
    p_expected_version: settings.version,
    p_creation_policy: "members",
  });
  const idea = (await create(bea, group, "Fictional garden")).room_id;
  await send(bea, idea, "Earlier planning is available after explicit Join.");
  const preview = await get(carlo, idea);
  equal(
    preview.access,
    "discoverable",
    "Group-visible summary is not admission",
  );
  equal(preview.preview, null, "Unjoined summary contains no message preview");
  await denied(carlo, "get_group_discussion_message_page_v2", {
    ...expected(carlo),
    p_room_id: idea,
  });
  const admitted = await join(carlo, idea);
  equal(
    (await history(carlo, idea)).items.length,
    1,
    "New planner receives full earlier history",
  );
  equal(
    (await get(carlo, idea)).unread_count,
    0,
    "Back history is not new unread",
  );
  equal(
    (await get(bea, idea)).can_manage,
    true,
    "Ordinary Discussion Creator manages their Idea",
  );
  equal(
    (await get(bea, idea)).can_publish,
    false,
    "Discussion creation never grants Project publication",
  );
  equal(
    (await get(manager, idea)).access,
    "oversight",
    "Manager oversight is separate from explicit admission",
  );
  await denied(carlo, "update_group_discussion_v2", {
    ...command(carlo, idea),
    p_expected_version: 1,
    p_title: "Denied",
    p_purpose: "",
    p_visibility: "group",
    p_archived: false,
  });
  const second = await send(bea, idea, "Unread after explicit Join.");
  const firstPage = await history(carlo, idea, { p_limit: 1 });
  equal(
    firstPage.items[0].message_id,
    second.object_id,
    "Newest history uses committed ordinal",
  );
  equal(
    (
      await history(carlo, idea, {
        p_limit: 1,
        p_before_sequence: firstPage.items[0].sequence,
      })
    ).items.length,
    1,
    "History has a second bounded page",
  );
  await send(bea, idea, "Must remain unread after an earlier snapshot ACK.");
  await rpc(carlo, "acknowledge_group_discussion_read_v2", {
    ...expected(carlo),
    p_room_id: idea,
    p_snapshot_token: firstPage.snapshot_token,
  });
  equal(
    (await get(carlo, idea)).unread_count,
    1,
    "Rendered snapshot ACK never consumes later activity",
  );
  await prefs(carlo, idea, true, false);
  equal(
    (await get(carlo, idea)).unread_count,
    1,
    "Mute does not acknowledge unread",
  );
  equal(
    (await notices(carlo)).some(
      (n) => n.room_id === idea && n.event_kind === "message",
    ),
    false,
    "Mute suppresses ordinary message notices",
  );
  const hiddenIdea = (
    await create(bea, group, "Fictional unjoined hidden Idea")
  ).room_id;
  await prefs(carlo, hiddenIdea, false, true);
  equal(
    (await rooms(carlo, group)).some((r) => r.room_id === hiddenIdea),
    false,
    "Manual hide omits unjoined Idea",
  );
  equal(
    (await rooms(carlo, group, { p_hidden: true })).some(
      (r) => r.room_id === hiddenIdea,
    ),
    true,
    "Show hidden restores access",
  );
  equal(
    (await notices(carlo)).some(
      (n) => n.room_id === hiddenIdea && n.event_kind === "created",
    ),
    true,
    "Hide is not unsubscribe",
  );
  await sql`update private.group_discussions set last_activity_at=clock_timestamp()-interval '8 days' where id=${hiddenIdea}::uuid`;
  await prefs(carlo, hiddenIdea, false, false);
  equal(
    (await rooms(carlo, group)).some((r) => r.room_id === hiddenIdea),
    false,
    "Inactive Idea automatically soft-hides",
  );
  await send(
    bea,
    hiddenIdea,
    "New activity resurfaces an automatically hidden Idea.",
  );
  equal(
    (await rooms(carlo, group)).some((r) => r.room_id === hiddenIdea),
    true,
    "Meaningful new activity resurfaces Idea",
  );
  const restricted = (
    await create(bea, group, "Fictional restricted Idea", "invitation")
  ).room_id;
  await send(bea, restricted, "Restricted earlier planning.");
  equal(
    (await rooms(carlo, group, { p_hidden: true })).some(
      (r) => r.room_id === restricted,
    ),
    false,
    "Restricted room absent from ordinary discovery",
  );
  equal(
    (await notices(carlo)).some((n) => n.room_id === restricted),
    false,
    "Restricted creation is not broadcast to ordinary members",
  );
  equal(
    (await notices(manager)).some(
      (n) => n.room_id === restricted && n.event_kind === "created",
    ),
    true,
    "Managers receive restricted creation notice",
  );
  await get(manager, restricted);
  const oversightPage = await history(manager, restricted);
  equal(
    oversightPage.items.length,
    1,
    "Manager can inspect restricted history without admission",
  );
  await send(bea, restricted, "Not fetched by the oversight reader.");
  const [role] = await rpc(manager, "get_own_group_role", {
    ...expected(manager),
    p_group_id: group,
  });
  await rpc(alice, "revoke_group_delegate", {
    ...command(alice),
    p_delegate_id: role.delegate_id,
  });
  equal(
    (await history(manager, restricted)).items.length,
    1,
    "Role loss retains only actual fetched oversight frontier",
  );
  equal(
    (await get(manager, restricted)).can_read_links,
    false,
    "Former oversight has no current links",
  );
  const suggestion = await invite(carlo, manager, idea);
  await accept(manager, suggestion);
  const targeted = await invite(bea, carlo, restricted);
  equal(
    (
      await rpc(carlo, "list_group_discussion_invitations", expected(carlo))
    ).some((i) => i.invitation_id === targeted.object_id),
    true,
    "Targeted invitation is a structured explicit request",
  );
  await accept(carlo, targeted);
  equal(
    (await history(carlo, restricted)).items.length,
    2,
    "Accepted invitation grants full earlier history",
  );
  await denied(carlo, "invite_group_discussion_member", {
    ...command(carlo, restricted),
    p_profile_id: manager.id,
  });
  const capability = await rpc(bea, "create_group_discussion_invitation_link", {
    ...command(bea, restricted),
    p_expected_version: 1,
  });
  const capPreview = await rpc(
    manager,
    "preview_group_discussion_invitation_link",
    { ...expected(manager), p_token: capability.token },
  );
  equal(
    capPreview.access,
    "discoverable",
    "Capability preview grants no message access",
  );
  await denied(diana, "preview_group_discussion_invitation_link", {
    ...expected(diana),
    p_token: capability.token,
  });
  const capArgs = { ...command(manager), p_token: capability.token };
  const capAdmission = await rpc(
    manager,
    "accept_group_discussion_invitation_link",
    capArgs,
  );
  await leave(manager, restricted, capAdmission.object_id);
  equal(
    await rpc(manager, "accept_group_discussion_invitation_link", capArgs),
    capAdmission,
    "Lost reply replay returns original admission receipt",
  );
  equal(
    (await get(manager, restricted)).access,
    "former",
    "Receipt replay never revives a left episode",
  );
  await rpc(bea, "revoke_group_discussion_invitation_link", {
    ...command(bea, restricted),
    p_expected_version: capability.invitation_link_version,
  });
  await denied(manager, "preview_group_discussion_invitation_link", {
    ...expected(manager),
    p_token: capability.token,
  });
  const beforeExit = await history(carlo, idea);
  await leave(carlo, idea, admitted.object_id);
  const afterExit = await send(bea, idea, "Not visible after committed exit.");
  await sql.begin(async (fixture) => {
    await fixture`set local session_replication_role=replica`;
    await fixture`update private.group_discussion_messages set created_at=(select ended_at from private.group_discussion_admissions where id=${admitted.object_id}::uuid) where room_id=${idea}::uuid`;
  });
  const former = await history(carlo, idea);
  equal(
    former.items.length,
    beforeExit.items.length,
    "Equal timestamps cannot widen exact exit sequence",
  );
  equal(
    former.items.some((m) => m.message_id === afterExit.object_id),
    false,
    "Post-exit message stays inaccessible",
  );
  equal(former.snapshot_token, null, "Former history never ACKs live activity");
  const oldSummary = await get(carlo, idea);
  await rpc(bea, "update_group_discussion_v2", {
    ...command(bea, idea),
    p_expected_version: 1,
    p_title: "Changed current title",
    p_purpose: "Changed current purpose",
    p_visibility: "group",
    p_archived: false,
  });
  equal(
    (await get(carlo, idea)).title,
    oldSummary.title,
    "Former projection uses saved metadata, not current edits",
  );
  await join(carlo, idea);
  equal(
    (await history(carlo, idea)).items.some(
      (m) => m.message_id === afterExit.object_id,
    ),
    true,
    "Deliberate fresh Join receives full history",
  );
  const page1 = await rooms(carlo, group, { p_limit: 2, p_hidden: true });
  equal(
    page1[0].room_id,
    general,
    "General pins first independently of creation order",
  );
  const last = page1.at(-1);
  const page2 = await rooms(carlo, group, {
    p_limit: 2,
    p_hidden: true,
    p_before_created_at: last.created_at,
    p_before_id: last.room_id,
  });
  equal(
    page2.some((r) => page1.some((p) => p.room_id === r.room_id)),
    false,
    "Room paging is stable and disjoint",
  );
  const noticePage = await notices(carlo, { p_limit: 1 });
  equal(noticePage.length, 1, "Notices are bounded");
  const olderNotices = await notices(carlo, {
    p_limit: 1,
    p_before_created_at: noticePage[0].created_at,
    p_before_id: noticePage[0].notice_id,
  });
  equal(olderNotices.length, 1, "Notices have another stable page");
  await rpc(carlo, "mark_group_discussion_notice_read", {
    ...expected(carlo),
    p_notice_id: noticePage[0].notice_id,
  });
  equal(
    (await notices(carlo, { p_limit: 1 }))[0].is_read,
    true,
    "Activity ACK is independent of human unread",
  );
  await sql`update private.group_discussions set frozen_at=clock_timestamp() where id=${restricted}::uuid`;
  await denied(
    bea,
    "send_group_discussion_message",
    { ...command(bea, restricted), p_body: "Denied after conversion freeze" },
    "55000",
  );
  await denied(manager, "join_group_discussion", command(manager, restricted));
  equal(
    (await history(carlo, restricted)).items.length,
    2,
    "Frozen source preserves original planning history",
  );
  // A concrete membership episode ending must not cancel an independent role,
  // and role loss must not cancel a surviving independent Group membership.
  const beforeOverlap = (await get(carlo, idea)).admission_id;
  const [overlapOffer] = await rpc(alice, "create_group_authority_invitation", {
    ...command(alice),
    p_group_id: group,
    p_role: "co_organizer",
  });
  await rpc(carlo, "accept_group_authority_invitation", {
    ...command(carlo),
    p_token: overlapOffer.invite_token,
  });
  await rpc(carlo, "leave_group", {
    ...command(carlo),
    p_membership_id: memberships.get(carlo.id).relationship_id,
  });
  equal(
    (await get(carlo, idea)).admission_id,
    beforeOverlap,
    "Ending membership preserves an independently supported room admission",
  );
  const [newMembership] = await rpc(
    carlo,
    "accept_group_participant_invitation",
    {
      ...command(carlo),
      p_token: sharing.invite_token,
    },
  );
  const [overlapRole] = await rpc(carlo, "get_own_group_role", {
    ...expected(carlo),
    p_group_id: group,
  });
  await rpc(alice, "revoke_group_delegate", {
    ...command(alice),
    p_delegate_id: overlapRole.delegate_id,
  });
  equal(
    (await get(carlo, idea)).admission_id,
    beforeOverlap,
    "Ending a role preserves an independently supported room admission",
  );
  await rpc(carlo, "leave_group", {
    ...command(carlo),
    p_membership_id: newMembership.relationship_id,
  });
  equal(
    (await get(carlo, idea)).access,
    "former",
    "Ending the final Group right closes current room access",
  );
  equal(
    await notices(carlo),
    [],
    "Queued source notices reauthorize after Group exit",
  );
  await denied(carlo, "list_group_discussion_people", {
    ...expected(carlo),
    p_room_id: idea,
  });
  equal(
    (await history(carlo, idea)).items.length > 0,
    true,
    "Former planner history remains readable after Group exit",
  );
  console.log(`Group Ideas real Auth verifier passed: ${checks} assertions.`);
} finally {
  await sql.end();
}
