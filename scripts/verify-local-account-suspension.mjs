import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { createConsequenceFixture } from "./lib/moderation-consequence-fixtures.mjs";

const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
if (
  !databaseUrl ||
  !/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/)/u.test(apiUrl)
) {
  throw new Error(
    "Suspension verification requires the project-scoped local stack.",
  );
}
const sql = postgres(databaseUrl, { max: 3, onnotice: () => {} });
const users = {};
const channels = [];
const roles = [
  "admin",
  "moderator",
  "owner",
  "cocreator",
  "coorganizer",
  "requester",
  "member",
  "resourceOwner",
  "resourceRequester",
  "unrelated",
];
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
try {
  for (const role of roles) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
      email: `suspension-${role.toLowerCase()}@planets.invalid`,
      verifierName: `suspension ${role}`,
    });
    const anchor = await user.client.from("profiles").insert({ id: user.id });
    if (anchor.error && anchor.error.code !== "23505")
      throw safeFailure("profile anchor", anchor.error);
    await rpc(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `Suspension ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    users[role] = user;
  }
  const fixture = await createConsequenceFixture(
    sql,
    Object.fromEntries(roles.map((role) => [role, users[role].id])),
  );
  const cases = {};
  for (const role of roles) {
    const id = randomUUID();
    await sql`insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id)
      values(${id}::uuid,'under_review',${users[role].id}::uuid,'profile',${users[role].id}::uuid)`;
    cases[role] = id;
  }
  const profilePhoto = `${users.requester.id}/${randomUUID()}.webp`;
  const image = await readFile(
    new URL("./demo-assets/profiles/sara.webp", import.meta.url),
  );
  const uploaded = await users.requester.client.storage
    .from("profile-photos")
    .upload(profilePhoto, image, { contentType: "image/webp", upsert: false });
  if (uploaded.error) throw safeFailure("private photo upload", uploaded.error);
  await rpc(users.requester, "set_own_profile_photo", {
    p_expected_profile_id: users.requester.id,
    p_object_path: profilePhoto,
    p_audience: "interactions",
  });
  assert.equal(
    (
      await users.requester.client.storage
        .from("profile-photos")
        .download(profilePhoto)
    ).error,
    null,
  );
  const pendingProject = await request(users.requester, fixture, false);
  const pendingResource = await request(users.requester, fixture, true);
  const acceptedProject = await request(users.member, fixture, false);
  const acceptedResource = await request(users.member, fixture, true);
  await rpc(users.owner, "accept_project_join_request", {
    p_expected_creator_profile_id: users.owner.id,
    p_request_id: acceptedProject,
  });
  await rpc(users.resourceOwner, "accept_resource_listing_request", {
    p_expected_owner_profile_id: users.resourceOwner.id,
    p_request_id: acceptedResource,
  });
  const otherResource = await request(users.resourceRequester, fixture, true);
  await rpc(users.resourceOwner, "accept_resource_listing_request", {
    p_expected_owner_profile_id: users.resourceOwner.id,
    p_request_id: otherResource,
  });
  await rpc(users.owner, "set_project_shared_workspace", {
    p_expected_manager_profile_id: users.owner.id,
    p_project_id: fixture.projectId,
    p_workspace_url: "https://example.invalid/suspension",
  });
  await rpc(users.requester, "block_user", {
    p_expected_blocker_profile_id: users.requester.id,
    p_blocked_profile_id: users.unrelated.id,
  });
  const safety = await rpc(users.moderator, "apply_moderation_consequence", {
    p_expected_staff_profile_id: users.moderator.id,
    p_case_id: cases.requester,
    p_consequence_type: "safety_notice",
    p_user_reason: "Synthetic safety reason",
    p_internal_note: "Synthetic safety note",
  });
  await denied(
    users.moderator,
    "apply_account_suspension",
    applyArgs(users.moderator, cases.requester),
    "42501",
  );
  await denied(
    users.unrelated,
    "apply_account_suspension",
    applyArgs(users.unrelated, cases.requester),
    "42501",
  );
  await denied(
    users.admin,
    "apply_account_suspension",
    applyArgs(users.admin, cases.admin),
    "42501",
  );
  const episode = await suspend(users.admin, cases.requester);
  const status = (
    await rpc(users.requester, "get_own_account_suspension_status", {
      p_expected_profile_id: users.requester.id,
    })
  )[0];
  assert.deepEqual(Object.keys(status).sort(), [
    "applied_at",
    "consequence_id",
    "is_suspended",
    "user_reason",
  ]);
  assert.equal(status.is_suspended, true);
  assert.equal(status.consequence_id, episode);
  assert.equal(status.user_reason, "Synthetic suspension reason");
  await denied(
    users.unrelated,
    "get_own_account_suspension_status",
    { p_expected_profile_id: users.requester.id },
    "42501",
  );
  assert.ok(
    (
      await anonymous.rpc("get_own_account_suspension_status", {
        p_expected_profile_id: users.requester.id,
      })
    ).error,
  );
  for (const name of [
    "list_own_notifications",
    "list_own_notification_preferences",
    "get_own_unread_notification_count",
    "list_own_blocked_profiles",
    "get_own_profile_photo",
    "list_own_resource_listings",
    "list_own_resource_listing_requests",
    "list_own_resource_saved_searches",
    "list_own_project_join_requests",
    "list_own_project_memberships",
    "list_own_moderation_reports",
    "list_own_moderation_consequences",
    "get_own_interaction_restriction_status",
  ]) {
    const expectedArgument =
      {
        list_own_blocked_profiles: "p_expected_blocker_profile_id",
        list_own_resource_listings: "p_expected_owner_profile_id",
        list_own_resource_listing_requests: "p_expected_requester_profile_id",
        list_own_project_join_requests: "p_expected_requester_profile_id",
        list_own_project_memberships: "p_expected_participant_profile_id",
        list_own_moderation_reports: "p_expected_reporter_profile_id",
      }[name] ?? "p_expected_profile_id";
    await denied(
      users.requester,
      name,
      { [expectedArgument]: users.requester.id },
      "PT403",
    );
  }
  await denied(
    users.requester,
    "list_own_proposals",
    { p_expected_creator_profile_id: users.requester.id },
    "PT403",
  );
  await denied(
    users.requester,
    "list_own_recurring_activities",
    { p_expected_creator_profile_id: users.requester.id },
    "PT403",
  );
  await denied(
    users.requester,
    "list_own_moderation_evidence_requests",
    { p_expected_recipient_profile_id: users.requester.id },
    "PT403",
  );
  await denied(
    users.requester,
    "request_resource_listing",
    {
      p_expected_requester_profile_id: users.requester.id,
      p_listing_id: fixture.listingId,
      p_message: null,
    },
    "PT403",
  );
  assert.equal(
    (await users.requester.client.from("profiles").select("id")).data.length,
    0,
  );
  assert.ok(
    (
      await users.requester.client.storage
        .from("profile-photos")
        .download(profilePhoto)
    ).error,
  );
  const removal = await users.requester.client.storage
    .from("profile-photos")
    .remove([profilePhoto]);
  assert.ok(removal.error || removal.data.length === 0);
  await denied(
    users.moderator,
    "revoke_account_suspension",
    revokeArgs(users.moderator, episode),
    "42501",
  );
  await denied(
    users.moderator,
    "revoke_moderation_consequence",
    revokeArgs(users.moderator, episode),
    "42501",
  );
  for (const [table, id] of [
    ["project_join_requests", pendingProject],
    ["resource_listing_requests", pendingResource],
  ]) {
    assert.equal(
      (
        await sql`select status from ${sql("public." + table)} where id=${id}::uuid`
      )[0].status,
      "withdrawn",
    );
  }
  assert.equal(
    (
      await sql`select revoked_at from private.moderation_consequences where id=${safety}::uuid`
    )[0].revoked_at,
    null,
  );
  assert.equal(
    (
      await sql`select count(*)::int as value from private.user_block_episodes where blocker_profile_id=${users.requester.id}::uuid and unblocked_at is null`
    )[0].value,
    1,
  );
  await revoke(users.admin, episode);
  assert.equal(
    (
      await rpc(users.requester, "get_own_account_suspension_status", {
        p_expected_profile_id: users.requester.id,
      })
    )[0].is_suspended,
    false,
  );
  const restoredHistory = await rpc(
    users.requester,
    "list_own_moderation_consequences",
    {
      p_expected_profile_id: users.requester.id,
    },
  );
  const removedSuspension = restoredHistory.find(
    (row) => row.consequence_id === episode,
  );
  assert.ok(
    removedSuspension,
    "removed suspension becomes general own history only after restoration",
  );
  assert.equal(removedSuspension.consequence_type, "account_suspension");
  assert.equal(removedSuspension.is_active, false);
  assert.equal(removedSuspension.apply_reason, "Synthetic suspension reason");
  assert.equal(removedSuspension.revoke_reason, "Synthetic access restored");
  assert.equal(typeof removedSuspension.applied_at, "string");
  assert.equal(typeof removedSuspension.revoked_at, "string");
  assert.equal(removedSuspension.content_id, null);
  assert.deepEqual(
    Object.keys(removedSuspension).sort(),
    [
      "consequence_id",
      "consequence_type",
      "is_active",
      "applied_at",
      "apply_reason",
      "revoked_at",
      "revoke_reason",
      "content_kind",
      "content_id",
      "content_title",
    ].sort(),
  );
  assert.equal(
    (
      await users.requester.client.storage
        .from("profile-photos")
        .download(profilePhoto)
    ).error,
    null,
  );

  // Deliberately keep authorized sockets open across suspension. The server's
  // per-recipient fan-out filter must work without cooperative client teardown.
  const group = (
    await rpc(users.owner, "get_own_project_group_chat", {
      p_expected_profile_id: users.owner.id,
      p_project_id: fixture.projectId,
    })
  )[0];
  const resourceChat = (
    await sql`select id from public.resource_request_chats where request_id=${acceptedResource}::uuid`
  )[0].id;
  const projectRequestChat = (
    await sql`select id from public.project_join_request_chats where request_id=${acceptedProject}::uuid`
  )[0].id;
  const groupTopic = `project-chat:${group.chat_id}:profile:${users.member.id}`;
  const resourceTopic = `resource-chat:${resourceChat}:profile:${users.member.id}`;
  const subjectGroup = await subscribe(
    users.member,
    groupTopic,
    "project.chat_message_sent",
    true,
  );
  const subjectResource = await subscribe(
    users.member,
    resourceTopic,
    "resource.chat_message_sent",
    true,
  );
  const observerGroup = await subscribe(
    users.owner,
    `project-chat:${group.chat_id}:profile:${users.owner.id}`,
    "project.chat_message_sent",
    true,
  );
  const observerResource = await subscribe(
    users.resourceOwner,
    `resource-chat:${resourceChat}:profile:${users.resourceOwner.id}`,
    "resource.chat_message_sent",
    true,
  );
  const beforeGroup = await send(
    users.owner,
    "send_project_chat_message",
    group.chat_id,
  );
  const beforeResource = await send(
    users.resourceOwner,
    "send_resource_request_chat_message",
    resourceChat,
  );
  await waitSignal(subjectGroup, beforeGroup.message_id);
  await waitSignal(subjectResource, beforeResource.message_id);
  const memberEpisode = await suspend(users.admin, cases.member);
  await denied(
    users.member,
    "get_own_project_shared_workspace",
    { p_expected_profile_id: users.member.id, p_project_id: fixture.projectId },
    "PT403",
  );
  await denied(
    users.member,
    "send_project_chat_message",
    {
      p_expected_profile_id: users.member.id,
      p_chat_id: group.chat_id,
      p_body: "Synthetic denied message",
    },
    "PT403",
  );
  await denied(
    users.member,
    "send_resource_request_chat_message",
    {
      p_expected_profile_id: users.member.id,
      p_chat_id: resourceChat,
      p_body: "Synthetic denied message",
    },
    "PT403",
  );
  const afterGroup = await send(
    users.owner,
    "send_project_chat_message",
    group.chat_id,
  );
  const afterResource = await send(
    users.resourceOwner,
    "send_resource_request_chat_message",
    resourceChat,
  );
  await waitSignal(observerGroup, afterGroup.message_id);
  await waitSignal(observerResource, afterResource.message_id);
  const [fanout] =
    await sql`select count(*)::int as value from realtime.messages where topic in (${groupTopic},${resourceTopic})
    and payload->>'message_id' in (${afterGroup.message_id},${afterResource.message_id})`;
  assert.equal(
    fanout.value,
    0,
    "No post-suspension private topic publication for cached recipient",
  );
  await new Promise((resolve) => setTimeout(resolve, 250));
  assert.ok(
    !subjectGroup.events.some(
      (row) => row.message_id === afterGroup.message_id,
    ),
  );
  assert.ok(
    !subjectResource.events.some(
      (row) => row.message_id === afterResource.message_id,
    ),
  );
  await close(subjectGroup);
  await close(subjectResource);
  await subscribe(users.member, groupTopic, "project.chat_message_sent", false);
  await subscribe(
    users.member,
    resourceTopic,
    "resource.chat_message_sent",
    false,
  );
  await subscribe(
    users.member,
    `project-request-chat:${projectRequestChat}:profile:${users.member.id}`,
    "project.join_request_chat_message_sent",
    false,
  );
  await revoke(users.admin, memberEpisode);
  const restored = await subscribe(
    users.member,
    groupTopic,
    "project.chat_message_sent",
    true,
  );
  await subscribe(
    users.member,
    resourceTopic,
    "resource.chat_message_sent",
    true,
  );
  await subscribe(
    users.member,
    `project-request-chat:${projectRequestChat}:profile:${users.member.id}`,
    "project.join_request_chat_message_sent",
    true,
  );
  const restoredMessage = await send(
    users.owner,
    "send_project_chat_message",
    group.chat_id,
  );
  await waitSignal(restored, restoredMessage.message_id);

  const beforeRelations = await relationSnapshot(fixture);
  for (const role of [
    "owner",
    "cocreator",
    "coorganizer",
    "resourceOwner",
    "resourceRequester",
    "moderator",
  ]) {
    const id = await suspend(users.admin, cases[role]);
    await denied(
      users[role],
      "list_own_notifications",
      { p_expected_profile_id: users[role].id },
      "PT403",
    );
    if (["owner", "cocreator", "coorganizer"].includes(role)) {
      await denied(
        users[role],
        "get_own_project_management_role",
        {
          p_expected_profile_id: users[role].id,
          p_project_id: fixture.projectId,
        },
        "PT403",
      );
      const other = role === "cocreator" ? users.coorganizer : users.cocreator;
      await rpc(other, "list_project_members_for_manager", {
        p_expected_manager_profile_id: other.id,
        p_project_id: fixture.projectId,
      });
    }
    if (role === "moderator") {
      await denied(
        users.moderator,
        "get_own_moderation_staff_access",
        { p_expected_profile_id: users.moderator.id },
        "PT403",
      );
    }
    assert.deepEqual(await relationSnapshot(fixture), beforeRelations);
    assert.equal(
      (
        await anonymous.rpc("get_public_proposal", {
          p_proposal_id: fixture.projectId,
        })
      ).data.length,
      1,
    );
    assert.equal(
      (
        await anonymous.rpc("get_public_resource_listing", {
          p_listing_id: fixture.listingId,
        })
      ).data.length,
      1,
    );
    await revoke(users.admin, id);
  }
  // Separate current admin to exercise suspended-admin denial and later recovery.
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${users.unrelated.id}::uuid,'admin')`;
  const adminEpisode = await suspend(users.unrelated, cases.admin);
  await denied(
    users.admin,
    "get_own_moderation_staff_access",
    { p_expected_profile_id: users.admin.id },
    "PT403",
  );
  await denied(
    users.admin,
    "revoke_account_suspension",
    revokeArgs(users.admin, adminEpisode),
    "PT403",
  );
  await revoke(users.unrelated, adminEpisode);
  await rpc(users.admin, "get_own_moderation_staff_access", {
    p_expected_profile_id: users.admin.id,
  });
  const [privacy] =
    await sql`select not exists(select 1 from private.audit_events where metadata::text like '%Synthetic suspension reason%'
    or metadata::text like '%Synthetic private suspension note%') and not exists(select 1 from private.outbox_events where payload::text like '%Synthetic suspension reason%'
    or payload::text like '%Synthetic private suspension note%') as safe`;
  assert.equal(privacy.safe, true);
  console.log(
    "Account suspension real-auth and Realtime passed: 10 identities, privacy/storage/private-domain denial, preserved relationships/co-manager access, staff recovery, three new-topic denials and cached Project/Resource socket fan-out suppression.",
  );
} finally {
  await Promise.allSettled(channels.map(close));
  await Promise.allSettled(
    Object.values(users).map((user) => user.client.removeAllChannels()),
  );
  await sql.end({ timeout: 5 });
}

function applyArgs(user, caseId) {
  return {
    p_expected_staff_profile_id: user.id,
    p_case_id: caseId,
    p_user_reason: "Synthetic suspension reason",
    p_internal_note: "Synthetic private suspension note",
  };
}
function revokeArgs(user, id) {
  return {
    p_expected_staff_profile_id: user.id,
    p_consequence_id: id,
    p_user_reason: "Synthetic access restored",
    p_internal_note: "Synthetic private revocation note",
  };
}
async function suspend(user, caseId) {
  return rpc(user, "apply_account_suspension", applyArgs(user, caseId));
}
async function revoke(user, id) {
  return rpc(user, "revoke_account_suspension", revokeArgs(user, id));
}
async function rpc(user, name, params) {
  const result = await user.client.rpc(name, params);
  if (result.error) throw safeFailure(name, result.error);
  return result.data;
}
async function denied(user, name, params, code) {
  const result = await user.client.rpc(name, params);
  assert.equal(result.error?.code, code, `${name} must deny with safe ${code}`);
}
function safeFailure(action, error) {
  return new Error(
    `${action} failed (${error?.code ?? error?.statusCode ?? "unknown"}).`,
  );
}
async function request(user, fixture, resource) {
  return rpc(
    user,
    resource ? "request_resource_listing" : "request_to_join_project",
    resource
      ? {
          p_expected_requester_profile_id: user.id,
          p_listing_id: fixture.listingId,
          p_message: null,
        }
      : {
          p_expected_requester_profile_id: user.id,
          p_project_id: fixture.projectId,
        },
  );
}
async function send(user, name, chatId) {
  return (
    await rpc(user, name, {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_body: "Synthetic suspension transport message",
    })
  )[0];
}
async function relationSnapshot(fixture) {
  const [row] = await sql`select jsonb_build_object(
    'memberships',(select jsonb_agg(to_jsonb(m) order by m.id) from public.project_memberships m where m.project_id=${fixture.projectId}::uuid),
    'delegates',(select jsonb_agg(to_jsonb(d) order by d.id) from public.project_delegates d where d.project_id=${fixture.projectId}::uuid),
    'agreements',(select jsonb_agg(to_jsonb(a) order by a.id) from public.resource_exchange_agreements a join public.resource_listing_requests r on r.id=a.request_id where r.listing_id=${fixture.listingId}::uuid),
    'project',(select to_jsonb(p) from public.projects p where p.id=${fixture.projectId}::uuid),
    'listing',(select to_jsonb(l) from public.resource_listings l where l.id=${fixture.listingId}::uuid)) as value`;
  return row.value;
}
async function subscribe(user, topic, event, shouldSucceed) {
  const entry = {
    user,
    channel: user.client.channel(topic, { config: { private: true } }),
    events: [],
  };
  channels.push(entry);
  entry.channel.on("broadcast", { event }, (signal) =>
    entry.events.push(signal.payload ?? signal),
  );
  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("Private topic authorization timed out.")),
      10000,
    );
    entry.channel.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        clearTimeout(timer);
        shouldSucceed
          ? resolve()
          : reject(new Error("Suspended profile joined a private topic."));
      }
      if (["CHANNEL_ERROR", "TIMED_OUT", "CLOSED"].includes(status)) {
        clearTimeout(timer);
        shouldSucceed
          ? reject(
              new Error("Active profile private topic authorization failed."),
            )
          : resolve();
      }
    });
  });
  if (!shouldSucceed) await close(entry);
  return entry;
}
async function close(entry) {
  await entry.user.client.removeChannel(entry.channel);
}
async function waitSignal(entry, id) {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    if (entry.events.some((row) => row.message_id === id)) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("Expected committed private signal was not delivered.");
}
