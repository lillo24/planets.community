import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

assert.ok(
  process.env.PLANETS_DISPOSABLE_QA === "1" || process.env.CI === "true",
  "CHECK01 writes synthetic fixtures and requires a disposable local stack",
);
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
    "CHECK01 is loopback-only",
  );
}
const db = postgres(databaseUrl, { max: 8, onnotice: () => {} });
const anonymous = {
  client: createClient(apiUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  }),
};
let checks = 0;
const check = (value, label) => {
  assert.ok(value, label);
  checks++;
};
const call = async (user, name, params) => {
  const { data, error } = await user.client.rpc(name, params);
  if (error)
    throw new Error(`CHECK01 ${name} failed (${error.code}): ${error.message}`);
  return data;
};
const denied = async (user, name, params, code) => {
  const { error } = await user.client.rpc(name, params);
  check(
    error?.code === code,
    `${name} expected ${code}, received ${error?.code}`,
  );
};
const params = (user, id) => ({
  p_expected_profile_id: user.id,
  p_project_id: id,
});
const read = (user, id) =>
  call(user, "get_project_organization_v1", params(user, id));
const mutation = (user, id, revision, command, request = randomUUID()) => ({
  ...params(user, id),
  p_expected_revision: revision,
  p_request_id: request,
  p_command: command,
});
const command = async (user, id, value) => {
  const snapshot = await read(user, id);
  return call(
    user,
    "mutate_project_organization_v1",
    mutation(user, id, snapshot.revision, value),
  );
};
const propose = (user, id, kind, value) =>
  command(user, id, { action: "save_decision", kind, value });
const confirm = (user, id, kind) =>
  command(user, id, { action: "confirm_decision", kind });
const publicDetail = async (id) =>
  (await call(anonymous, "get_public_proposal_v2", { p_proposal_id: id }))[0];
const capacity = async (id) =>
  (
    await call(anonymous, "list_public_project_capacity_statuses", {
      p_project_ids: [id],
    })
  )[0];
const input = (user, fields = {}) => ({
  p_expected_creator_profile_id: user.id,
  p_title: "CHECK01 synthetic collaboration",
  p_summary: "Agree on a place and multi-day activity together.",
  p_description: "Synthetic disposable local fixture.",
  p_starts_at: null,
  p_ends_at: null,
  p_event_timezone: null,
  p_country_code: null,
  p_locality: null,
  p_administrative_area: null,
  p_public_location_label: null,
  p_exact_meeting_text: null,
  p_exact_location_visibility: "participants",
  p_skill_ids: [],
  p_skill_importances: [],
  p_registration_capacity: null,
  p_count_organizers_toward_capacity: false,
  ...fields,
});
const idea = async (user, fields = {}) => {
  const id = await call(user, "create_proposal_draft", input(user, fields));
  await call(user, "publish_proposal_idea", {
    p_expected_creator_profile_id: user.id,
    p_proposal_id: id,
  });
  return id;
};
const delegate = async (owner, user, id, role) => {
  const [link] = await call(owner, "create_project_delegate_invitation", {
    p_expected_owner_profile_id: owner.id,
    p_project_id: id,
    p_requested_authority_role: role,
  });
  return call(user, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: user.id,
    p_token: link.invite_token,
  });
};
const invitation = async (owner, id) =>
  (
    await call(
      owner,
      "create_project_participant_invitation",
      params(owner, id),
    )
  )[0];
const accept = (user, link) => ({
  p_expected_profile_id: user.id,
  p_token: link.invite_token,
  p_client_action_id: randomUUID(),
});
const schedule = {
  starts_at: new Date(Date.now() + 3 * 86400000).toISOString(),
  ends_at: new Date(Date.now() + 5 * 86400000).toISOString(),
  timezone: "Europe/Rome",
};
try {
  const users = await Promise.all(
    ["owner", "member", "peer", "cocreator", "organizer"].map((role) =>
      signInLocalOtpUser({
        apiUrl,
        publishableKey,
        mailpitUrl,
        email: `check01-${role}@planets.invalid`,
        verifierName: "CHECK01",
      }),
    ),
  );
  const [owner, member, peer, coCreator, organizer] = users;
  for (const user of users) {
    const { error } = await user.client
      .from("profiles")
      .insert({ id: user.id });
    if (error && error.code !== "23505")
      throw new Error(`CHECK01 profile anchor (${error.code})`);
    await call(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: "Synthetic Organization actor",
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "public",
    });
    await ensureLocalProfilePhoto(user);
  }
  const id = await idea(owner, {
    p_country_code: "IT",
    p_locality: "Trento",
    p_public_location_label: "Trento",
    p_starts_at: schedule.starts_at,
    p_ends_at: schedule.ends_at,
    p_event_timezone: schedule.timezone,
    p_registration_capacity: 10,
  });
  const initial = await read(owner, id);
  check(
    initial.proposals.location.text === "Trento" &&
      initial.proposals.capacity.limit === 10,
    "publication captures draft suggestions privately",
  );
  check(
    (await publicDetail(id)).locality === null &&
      (await publicDetail(id)).starts_at === null &&
      (await capacity(id)).registration_capacity === null,
    "no draft logistics or cap in public reads",
  );
  check(
    (
      await db`select count(*)::int n from public.project_group_chats where project_id=${id}`
    )[0].n === 0,
    "creator planner never creates chat",
  );
  await denied(
    anonymous,
    "get_project_organization_v1",
    params(owner, id),
    "42501",
  );
  await denied(peer, "get_project_organization_v1", params(peer, id), "42501");
  await denied(peer, "get_project_organization_v1", params(owner, id), "42501");
  const req = await call(member, "request_to_join_project", {
    p_expected_requester_profile_id: member.id,
    p_project_id: id,
    p_request_message: null,
  });
  await denied(
    member,
    "get_project_organization_v1",
    params(member, id),
    "42501",
  );
  check(
    (await publicDetail(id)).locality === null,
    "pending requester sees only undecided public detail",
  );
  const membership = await call(owner, "accept_project_join_request", {
    p_expected_creator_profile_id: owner.id,
    p_request_id: req,
  });
  const coId = await delegate(owner, coCreator, id, "co_creator");
  await delegate(owner, organizer, id, "co_organizer");
  for (const user of [member, coCreator, organizer])
    check(
      (await read(user, id)).proposals.schedule.timezone === "Europe/Rome",
      "current group reads private schedule",
    );
  for (const user of [member, organizer]) {
    const s = await read(user, id);
    await denied(
      user,
      "mutate_project_organization_v1",
      mutation(user, id, s.revision, {
        action: "confirm_decision",
        kind: "location",
      }),
      "42501",
    );
    await denied(
      user,
      "mutate_project_organization_v1",
      mutation(user, id, s.revision, {
        action: "save_decision",
        kind: "capacity",
        value: { limit: 1, count_organizers: false },
      }),
      "42501",
    );
  }
  await confirm(coCreator, id, "location");
  check(
    (await publicDetail(id)).locality === "Trento" &&
      (await publicDetail(id)).definition_phase === "idea" &&
      (await publicDetail(id)).starts_at === null,
    "only confirmed city public, no promotion",
  );
  await propose(owner, id, "location", { text: "Trento o Rovereto" });
  check(
    (await publicDetail(id)).locality === "Trento",
    "pending alternative preserves public official value",
  );
  let s = await read(owner, id);
  await denied(
    owner,
    "mutate_project_organization_v1",
    mutation(owner, id, s.revision, {
      action: "confirm_decision",
      kind: "location",
    }),
    "22023",
  );
  await propose(owner, id, "location", {
    text: "Rovereto",
    country_code: "IT",
    locality: "Rovereto",
    label: "Rovereto",
  });
  s = await read(owner, id);
  const confirmation = mutation(owner, id, s.revision, {
    action: "confirm_decision",
    kind: "location",
  });
  const first = await call(
    owner,
    "mutate_project_organization_v1",
    confirmation,
  );
  const replay = await call(
    owner,
    "mutate_project_organization_v1",
    confirmation,
  );
  check(
    first.revision === replay.revision && !replay.proposals.location,
    "lost response retry recovers consumed proposal without duplicate mutation",
  );
  await denied(
    owner,
    "mutate_project_organization_v1",
    {
      ...confirmation,
      p_command: { action: "confirm_decision", kind: "schedule" },
    },
    "22023",
  );
  check(
    (
      await db`select count(*)::int n from private.audit_events where target_id=${id} and action='project.organization.confirmed'`
    )[0].n === 2,
    "retry does not duplicate confirmation audit",
  );
  await command(member, id, {
    action: "add_task",
    task_id: randomUUID(),
    title: "Prepare a poster",
  });
  await denied(owner, "mutate_project_organization_v1", confirmation, "PT409");
  check(
    (await publicDetail(id)).locality === "Rovereto",
    "superseded retry never reverts official city",
  );
  for (const endpoint of ["get_public_proposal", "get_own_proposal"]) {
    const args =
      endpoint === "get_own_proposal"
        ? { p_expected_creator_profile_id: owner.id, p_proposal_id: id }
        : { p_proposal_id: id };
    check(
      (await call(owner, endpoint, args)).length === 0,
      "strict v1 readers continue to exclude Ideas",
    );
  }
  // Old installed clients cannot alter either canonical logistics or cap.
  await denied(
    owner,
    "update_own_proposal",
    {
      ...input(owner, {
        p_locality: "Private alternative",
        p_public_location_label: "Private alternative",
      }),
      p_proposal_id: id,
    },
    "PT409",
  );
  await denied(
    owner,
    "update_own_proposal",
    { ...input(owner, { p_registration_capacity: 1 }), p_proposal_id: id },
    "PT409",
  );
  check(
    (await publicDetail(id)).locality === "Rovereto",
    "denied old write rolls back fully",
  );
  const root = randomUUID(),
    child = randomUUID(),
    third = randomUUID();
  await command(member, id, {
    action: "add_task",
    task_id: root,
    title: "Organizzare i materiali",
  });
  await command(member, id, {
    action: "set_task_done",
    task_id: root,
    done: true,
  });
  await command(organizer, id, {
    action: "add_task",
    task_id: child,
    parent_id: root,
    title: "Contattare chi ha gli attrezzi",
  });
  check(
    !(await read(member, id)).tasks.find((t) => t.id === root).done,
    "adding a child reopens a checked parent",
  );
  s = await read(member, id);
  await denied(
    member,
    "mutate_project_organization_v1",
    mutation(member, id, s.revision, {
      action: "add_task",
      task_id: third,
      parent_id: child,
      title: "Forbidden third level",
    }),
    "22023",
  );
  await denied(
    member,
    "mutate_project_organization_v1",
    mutation(member, id, s.revision, { action: "remove_task", task_id: root }),
    "42501",
  );
  await denied(
    member,
    "mutate_project_organization_v1",
    mutation(member, id, s.revision, {
      action: "edit_task",
      task_id: child,
      title: "Other author",
    }),
    "42501",
  );
  await command(member, id, {
    action: "set_task_done",
    task_id: child,
    done: true,
  });
  check(
    (await read(member, id)).tasks.find((t) => t.id === root).done,
    "parent completion derives from children across authors",
  );
  await command(coCreator, id, {
    action: "edit_task",
    task_id: child,
    title: "Revised by Co-creator",
  });
  await command(owner, id, { action: "move_task", task_id: root, position: 0 });
  check(
    (await read(owner, id)).tasks.filter((t) => !t.parent_id)[0].id === root,
    "structural authority reorders roots",
  );
  await command(owner, id, { action: "move_task", task_id: root, position: 1 });
  check(
    (await read(owner, id)).tasks.filter((t) => !t.parent_id)[1].id === root,
    "moving a root down keeps deterministic sibling order",
  );
  // Serialized competing clients: one winner; retrying stale done cannot undo it.
  s = await read(member, id);
  const race = await Promise.all(
    [true, false].map((done) =>
      member.client.rpc(
        "mutate_project_organization_v1",
        mutation(member, id, s.revision, {
          action: "set_task_done",
          task_id: child,
          done,
        }),
      ),
    ),
  );
  check(
    race.filter((r) => !r.error).length === 1 &&
      race.filter((r) => r.error?.code === "PT409").length === 1,
    "concurrent toggles have one CAS winner",
  );
  await propose(owner, id, "capacity", { limit: 1, count_organizers: true });
  s = await read(owner, id);
  await denied(
    owner,
    "mutate_project_organization_v1",
    mutation(owner, id, s.revision, {
      action: "confirm_decision",
      kind: "capacity",
    }),
    "PT409",
  );
  check(
    (await capacity(id)).registration_capacity === null,
    "failed official cap preserves undecided admission state",
  );
  await propose(owner, id, "capacity", { limit: 10, count_organizers: true });
  await confirm(owner, id, "capacity");
  await confirm(owner, id, "schedule");
  check(
    (await publicDetail(id)).derived_status === null,
    "confirmed Idea schedule never completes/operationalizes it",
  );
  const [anchor] =
    await db`select id from public.project_group_chats where project_id=${id}`;
  await call(owner, "promote_proposal_idea", {
    p_expected_profile_id: owner.id,
    p_proposal_id: id,
  });
  check(
    (await publicDetail(id)).definition_phase === "defined" &&
      (
        await db`select id from public.project_group_chats where project_id=${id}`
      )[0].id === anchor.id,
    "promotion preserves existing chat/identity",
  );
  await command(member, id, {
    action: "add_task",
    task_id: randomUUID(),
    title: "Defined group continues",
  });
  await call(owner, "revoke_project_delegate", {
    p_expected_owner_profile_id: owner.id,
    p_delegate_id: coId,
  });
  await denied(
    coCreator,
    "get_project_organization_v1",
    params(coCreator, id),
    "42501",
  );
  await call(member, "leave_project", {
    p_expected_participant_profile_id: member.id,
    p_membership_id: membership,
  });
  await denied(
    member,
    "get_project_organization_v1",
    params(member, id),
    "42501",
  );
  await denied(
    member,
    "mutate_project_organization_v1",
    mutation(member, id, (await read(owner, id)).revision, {
      action: "set_task_done",
      task_id: child,
      done: false,
    }),
    "42501",
  );
  await db`update public.proposals set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where id=${id}`;
  s = await read(owner, id);
  check(!s.can_mutate, "ended planner is a current-group-only archive");
  await denied(
    owner,
    "mutate_project_organization_v1",
    mutation(owner, id, s.revision, {
      action: "add_task",
      task_id: randomUUID(),
      title: "Too late",
    }),
    "55000",
  );
  const cancelled = await idea(owner);
  await call(owner, "cancel_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: cancelled,
  });
  s = await read(owner, cancelled);
  check(!s.can_mutate, "cancellation freezes organization");
  await denied(
    owner,
    "mutate_project_organization_v1",
    mutation(owner, cancelled, s.revision, {
      action: "add_task",
      task_id: randomUUID(),
      title: "Too late",
    }),
    "55000",
  );
  // Confirming a capacity races real invitation admissions under existing locks.
  for (let round = 0; round < 3; round++) {
    const item = await idea(owner);
    const link = await invitation(owner, item);
    s = await propose(owner, item, "capacity", {
      limit: 1,
      count_organizers: false,
    });
    const results = await Promise.all([
      owner.client.rpc(
        "mutate_project_organization_v1",
        mutation(owner, item, s.revision, {
          action: "confirm_decision",
          kind: "capacity",
        }),
      ),
      member.client.rpc(
        "accept_project_participant_invitation",
        accept(member, link),
      ),
      peer.client.rpc(
        "accept_project_participant_invitation",
        accept(peer, link),
      ),
    ]);
    check(
      results.every(
        (r) => !r.error || ["22023", "PT409"].includes(r.error.code),
      ),
      "capacity/invitation race has only legal outcomes",
    );
    const cap = await capacity(item);
    check(
      cap.registration_capacity === null ||
        cap.capacity_used_count <= cap.registration_capacity,
      "confirmation race never leaves overbooked finite cap",
    );
  }
  console.log(
    `CHECK01: ${checks} real OTP/JWT privacy, role, retry, task and concurrency checks passed.`,
  );
} finally {
  await db.end();
}
