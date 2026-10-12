import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Fictional fixtures only. Upgrade mode resets its explicitly disposable stack.
const root = process.cwd();
const status = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl])
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
    "Group membership verification requires loopback endpoints.",
  );
const sql = postgres(status.databaseUrl, { max: 12, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
const equal = (actual, wanted, label) => {
  assert.deepEqual(actual, wanted, label);
  checks++;
};
const expected = (person) => ({ p_expected_profile_id: person.id });
const args = (person, group) => ({ ...expected(person), p_group_id: group });
const key = () => ({ p_client_request_id: randomUUID() });
async function rpc(person, name, parameters = {}) {
  const result = await person.client.rpc(name, parameters);
  // Never include arguments, tokens, sessions, or raw provider responses.
  assert.equal(
    result.error?.code ?? null,
    null,
    `${name}: ${result.error?.code ?? "success"}`,
  );
  return result.data;
}
async function denied(person, name, parameters, code = "42501") {
  const result = await person.client.rpc(name, parameters);
  equal(result.error?.code, code, `${name} denial`);
}
async function attempt(person, name, parameters) {
  const result = await person.client.rpc(name, parameters);
  assert.ok(
    !result.error || ["PT409", "42501"].includes(result.error.code),
    `${name}: unexpected ${result.error?.code}`,
  );
  return result;
}
async function user(label, complete = true) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `grp03-${run}-${label}@planets.invalid`,
    verifierName: "group-membership",
  });
  await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${complete ? `Fictional ${label}` : null})`;
  return person;
}
async function photo(person) {
  await sql`insert into public.profile_photos(profile_id,object_path,audience) values(${person.id}::uuid,${`${person.id}/${randomUUID()}.webp`},'interactions') on conflict(profile_id) do nothing`;
}
const content = {
  name: `Fictional GRP03 ${run}`,
  description: "Fictional local people collaborating in a garden.",
  group_kind: "informal",
  locality: "Trento",
  volunteering_focus: true,
};
async function group(creator) {
  const id = await rpc(creator, "create_group_draft", {
    ...expected(creator),
    ...key(),
    p_content: content,
  });
  await rpc(creator, "set_group_publication_state", {
    ...args(creator, id),
    ...key(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  return id;
}
async function invite(creator, recipient, id, role = "co_organizer") {
  const [invitation] = await rpc(creator, "create_group_authority_invitation", {
    ...args(creator, id),
    ...key(),
    p_role: role,
  });
  const [accepted] = await rpc(recipient, "accept_group_authority_invitation", {
    ...expected(recipient),
    ...key(),
    p_token: invitation.invite_token,
  });
  return { invitation, accepted };
}
async function link(manager, id) {
  return (
    await rpc(manager, "create_group_participant_invitation", {
      ...args(manager, id),
      ...key(),
    })
  )[0];
}
async function join(person, sharing, command = key()) {
  return (
    await rpc(person, "accept_group_participant_invitation", {
      ...expected(person),
      ...command,
      p_token: sharing.invite_token,
    })
  )[0];
}
async function request(person, id, command = key()) {
  return (
    await rpc(person, "create_group_join_request", {
      ...args(person, id),
      ...command,
      p_note: "Private fictional request.",
    })
  )[0];
}
async function asUser(tx, person, operation) {
  await tx`select set_config('request.jwt.claim.sub',${person.id},true)`;
  await tx.unsafe("set local role authenticated");
  const value = await operation(tx);
  await tx.unsafe("reset role");
  return value;
}
// Hold a real independent database transaction, observe PostgREST waiting, then
// commit a competing transition. This verifies rechecks after actual lock waits.
async function afterWait(id, functionName, launch, transition) {
  let ready, release;
  const locked = new Promise((resolve) => {
    ready = resolve;
  });
  const resume = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    await tx`select id from private.community_groups where id=${id}::uuid for update`;
    ready();
    await resume;
    await transition(tx);
  });
  await locked;
  const pending = launch();
  try {
    let waiting = false;
    for (let i = 0; i < 100; i++) {
      const [state] =
        await sql`select exists(select 1 from pg_stat_activity where pid<>pg_backend_pid() and wait_event_type='Lock' and query ilike ${`%${functionName}%`}) as waiting`;
      if (state.waiting) {
        waiting = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    assert.ok(
      waiting,
      `${functionName} must wait on the independent transaction`,
    );
  } finally {
    release();
  }
  await holder;
  return pending;
}
function command(executable, parameters) {
  const result = spawnSync(executable, parameters, {
    cwd: root,
    encoding: "utf8",
    shell: process.platform === "win32" && executable === "supabase",
    timeout: 300000,
    maxBuffer: 32 * 1024 * 1024,
  });
  if (result.error || result.status !== 0)
    throw new Error(
      `Group membership upgrade command failed: ${executable === process.execPath ? parameters[0] : executable + " " + parameters[0]} (${result.status ?? result.error?.code}).`,
    );
}
async function upgrade() {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade requires an explicitly disposable local stack.",
  );
  const migrations = (await readdir("supabase/migrations"))
    .filter((name) => name.endsWith(".sql"))
    .sort();
  const index = migrations.findIndex((name) =>
    name.endsWith("_group_membership_and_authority.sql"),
  );
  assert.ok(index > 0);
  command("supabase", [
    "db",
    "reset",
    "--local",
    "--version",
    migrations[index - 1].split("_")[0],
  ]);
  command(process.execPath, ["scripts/seed-local-demo-world.mjs"]);
  command(process.execPath, ["scripts/verify-local-project-delegates.mjs"]);
  command(process.execPath, [
    "scripts/verify-local-participant-invitations.mjs",
  ]);
  command(process.execPath, ["scripts/verify-local-persistent-groups.mjs"]);
  await sql`insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from public.profiles limit 1 on conflict do nothing`;
  const warmBlocker = await user("upgrade-blocker"),
    warmRequester = await user("upgrade-requester");
  await rpc(warmBlocker, "block_user", {
    p_expected_blocker_profile_id: warmBlocker.id,
    p_blocked_profile_id: warmRequester.id,
  });
  await rpc(warmBlocker, "unblock_user", {
    p_expected_blocker_profile_id: warmBlocker.id,
    p_blocked_profile_id: warmRequester.id,
  });
  const [{ oid: hookOid }] =
    await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid as oid`;
  const tables =
    await sql`select table_schema||'.'||table_name as name,array_agg(column_name order by ordinal_position) as columns from information_schema.columns
    where table_schema in ('public','private') and table_name in (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') group by table_schema,table_name order by 1`;
  async function snapshot(table) {
    const [{ rows }] =
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) as rows from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
    return {
      count: rows.length,
      hash: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  }
  const before = new Map();
  for (const table of tables) before.set(table.name, await snapshot(table));
  for (const name of [
    "private.community_groups",
    "private.community_group_command_receipts",
    "private.community_group_suppression_actions",
    "private.moderation_reports",
    "public.project_memberships",
    "public.project_delegates",
    "public.project_delegate_invitations",
    "public.project_chat_messages",
    "private.policy_acceptances",
  ])
    assert.ok(
      before.get(name)?.count > 0,
      `Populated upgrade requires ${name}`,
    );
  command("supabase", ["migration", "up", "--local"]);
  command("supabase", ["migration", "up", "--local"]);
  equal(
    (
      await sql`select 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid as oid`
    )[0].oid,
    hookOid,
    "Upgrade preserves warmed blocking hook OID",
  );
  for (const table of tables)
    equal(
      await snapshot(table),
      before.get(table.name),
      `Upgrade preserves ${table.name}`,
    );
  equal(
    (await sql`select count(*)::int as n from private.group_memberships`)[0].n,
    0,
    "No membership copied from Projects",
  );
  equal(
    (await sql`select count(*)::int as n from private.group_delegates`)[0].n,
    0,
    "No authority copied from Projects",
  );
  const warmGroup = await group(warmBlocker);
  await photo(warmRequester);
  const warmRequest = await request(warmRequester, warmGroup);
  await rpc(warmBlocker, "block_user", {
    p_expected_blocker_profile_id: warmBlocker.id,
    p_blocked_profile_id: warmRequester.id,
  });
  equal(
    (
      await rpc(
        warmRequester,
        "list_own_group_join_requests",
        expected(warmRequester),
      )
    ).find((row) => row.request_id === warmRequest.relationship_id).status,
    "rejected",
    "Warmed block_user invokes group convergence after upgrade",
  );
  console.log(
    `GRP03A populated upgrade passed: ${tables.length} existing tables preserved; no group membership/delegate seeding; repeat application harmless.`,
  );
}

async function verify() {
  const [
    creator,
    coCreator,
    organizer,
    member,
    other,
    applicant,
    staff,
    incomplete,
  ] = await Promise.all(
    [
      "creator",
      "co-creator",
      "organizer",
      "member",
      "other",
      "applicant",
      "staff",
      "incomplete",
    ].map((name) => user(name, name !== "incomplete")),
  );
  const guest = {
    client: createClient(status.apiUrl, status.publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    }),
  };
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active) values(${staff.id}::uuid,'moderator',true)`;
  await Promise.all([photo(member), photo(applicant), photo(organizer)]);
  const id = await group(creator);
  const structural = await invite(creator, coCreator, id, "co_creator");
  const operational = await invite(coCreator, organizer, id);
  const sharing = await link(organizer, id);
  equal(
    (
      await rpc(guest, "get_group_participant_invitation_preview", {
        p_token: sharing.invite_token,
      })
    )[0].group_id,
    id,
    "Anonymous minimal preview",
  );
  equal(
    (
      await rpc(guest, "get_group_participant_invitation_preview", {
        p_token: "invalid",
      })
    )[0].available,
    false,
    "Neutral invalid preview",
  );
  await denied(organizer, "get_group_structural_context", args(organizer, id));
  await denied(coCreator, "get_own_group", args(coCreator, id));
  await denied(staff, "list_current_group_people", args(staff, id));
  await denied(
    other,
    "create_group_join_request",
    { ...args(other, id), ...key() },
    "55000",
  );
  await denied(
    incomplete,
    "accept_group_participant_invitation",
    { ...expected(incomplete), ...key(), p_token: sharing.invite_token },
    "55000",
  );
  const requestKey = key();
  const duplicates = await Promise.all(
    Array.from({ length: 10 }, () => request(member, id, requestKey)),
  );
  equal(
    new Set(duplicates.map((row) => row.relationship_id)).size,
    1,
    "Concurrent request retry has one attempt",
  );
  await denied(
    member,
    "create_group_join_request",
    { ...args(member, id), ...key() },
    "PT409",
  );
  await denied(
    member,
    "create_group_join_request",
    { ...args(member, id), ...requestKey, p_note: "Changed intent" },
    "PT409",
  );
  await denied(member, "list_current_group_people", args(member, id));
  const pending = duplicates[0];
  const race = await Promise.all([
    attempt(organizer, "accept_group_join_request", {
      ...expected(organizer),
      ...key(),
      p_request_id: pending.relationship_id,
    }),
    attempt(member, "accept_group_participant_invitation", {
      ...expected(member),
      ...key(),
      p_token: sharing.invite_token,
    }),
  ]);
  assert.ok(race.some((result) => !result.error));
  const [episode] =
    await sql`select id from private.group_memberships where group_id=${id}::uuid and profile_id=${member.id}::uuid and ended_at is null`;
  equal(
    (
      await sql`select count(*)::int as n from private.group_memberships where group_id=${id}::uuid and profile_id=${member.id}::uuid`
    )[0].n,
    1,
    "Approval versus direct admission creates one interval",
  );
  const directKey = key();
  const admissions = await Promise.all(
    Array.from({ length: 10 }, () => join(other, sharing, directKey)),
  );
  equal(
    new Set(admissions.map((row) => row.relationship_id)).size,
    1,
    "Duplicate direct acceptance creates one interval",
  );
  const otherEpisode = admissions[0].relationship_id;
  await Promise.all([
    rpc(other, "leave_group", {
      ...expected(other),
      ...key(),
      p_membership_id: otherEpisode,
    }),
    join(other, sharing, directKey),
  ]);
  equal(
    (await join(other, sharing, directKey)).current_status,
    "left",
    "Retry after leave recovers ended interval",
  );
  const reentryKey = key();
  const reentered = await join(other, sharing, reentryKey);
  assert.notEqual(reentered.relationship_id, otherEpisode);
  const removeKey = key();
  await Promise.all([
    rpc(organizer, "remove_group_member", {
      ...expected(organizer),
      ...removeKey,
      p_membership_id: reentered.relationship_id,
    }),
    join(other, sharing, reentryKey),
  ]);
  equal(
    (
      await rpc(organizer, "remove_group_member", {
        ...expected(organizer),
        ...removeKey,
        p_membership_id: reentered.relationship_id,
      })
    )[0].current_status,
    "removed",
    "Removal retry cannot recreate membership",
  );
  equal(
    (await join(other, sharing, reentryKey)).current_status,
    "removed",
    "Direct admission retry after removal recovers the removed interval",
  );
  const organizerMember = await join(organizer, sharing);
  await denied(organizer, "remove_group_member", {
    ...expected(organizer),
    ...key(),
    p_membership_id: organizerMember.relationship_id,
  });
  const ownPending = await request(applicant, id);
  const applicantMember = await join(applicant, sharing);
  const ownHistory = await rpc(
    applicant,
    "list_own_group_join_requests",
    expected(applicant),
  );
  equal(
    ownHistory.find((row) => row.request_id === ownPending.relationship_id)
      .resolution_reason,
    "direct_participant_invitation",
    "Direct admission preserves reasoned withdrawal",
  );
  equal(
    ownHistory.find((row) => row.request_id === ownPending.relationship_id)
      .superseded_by_membership_id,
    applicantMember.relationship_id,
    "Withdrawal points to exact admitted interval",
  );
  const people = await rpc(
    member,
    "list_current_group_people",
    args(member, id),
  );
  equal(
    new Set(people.map((row) => row.profile_id)).size,
    people.length,
    "People deduplicates organizer/participant overlap",
  );
  equal(
    people.filter((row) => row.profile_id === organizer.id).length,
    1,
    "Organizer who participates appears once",
  );
  const paged = [];
  let cursor = {};
  while (true) {
    const page = await rpc(member, "list_current_group_people", {
      ...args(member, id),
      p_limit: 1,
      ...cursor,
    });
    if (!page.length) break;
    paged.push(page[0].profile_id);
    cursor = {
      p_after_role_rank: page[0].role_rank,
      p_after_profile_id: page[0].profile_id,
    };
  }
  equal(
    paged,
    people.map((row) => row.profile_id),
    "Stable People pagination",
  );
  await denied(member, "list_group_join_requests", args(member, id));
  await denied(
    member,
    "get_current_group_participant_invitation",
    args(member, id),
  );
  const offerKey = key();
  const [offer] = await rpc(coCreator, "create_group_role_offer", {
    ...args(coCreator, id),
    ...offerKey,
    p_membership_id: episode.id,
    p_role: "co_organizer",
  });
  await denied(other, "accept_group_role_offer", {
    ...expected(other),
    ...key(),
    p_offer_id: offer.relationship_id,
  });
  const stale = await afterWait(
    id,
    "accept_group_role_offer",
    () =>
      attempt(member, "accept_group_role_offer", {
        ...expected(member),
        ...key(),
        p_offer_id: offer.relationship_id,
      }),
    (tx) =>
      asUser(
        tx,
        member,
        (db) =>
          db`select * from public.leave_group(${member.id}::uuid,${episode.id}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  equal(
    stale.error?.code,
    "PT409",
    "Offer rejects an episode ended during lock wait",
  );
  const freshMember = await join(member, sharing);
  await denied(
    member,
    "accept_group_role_offer",
    { ...expected(member), ...key(), p_offer_id: offer.relationship_id },
    "PT409",
  );
  const [freshOffer] = await rpc(creator, "create_group_role_offer", {
    ...args(creator, id),
    ...key(),
    p_membership_id: freshMember.relationship_id,
    p_role: "co_creator",
  });
  const acceptedKey = key();
  const [memberDelegate] = await rpc(member, "accept_group_role_offer", {
    ...expected(member),
    ...acceptedKey,
    p_offer_id: freshOffer.relationship_id,
  });
  await rpc(member, "step_down_group_authority", {
    ...expected(member),
    ...key(),
    p_delegate_id: memberDelegate.relationship_id,
  });
  equal(
    (
      await rpc(member, "accept_group_role_offer", {
        ...expected(member),
        ...acceptedKey,
        p_offer_id: freshOffer.relationship_id,
      })
    )[0].current_status,
    "revoked",
    "Accepted offer retry never regrants authority",
  );
  equal(
    (
      await rpc(member, "accept_group_role_offer", {
        ...expected(member),
        ...key(),
        p_offer_id: freshOffer.relationship_id,
      })
    )[0].relationship_id,
    memberDelegate.relationship_id,
    "Accepted offer new retry recovers original delegate",
  );
  equal(
    (await rpc(member, "get_own_group_role", args(member, id)))[0]
      .current_membership_id,
    freshMember.relationship_id,
    "Step down preserves membership",
  );
  const [lostSecret] = await rpc(creator, "create_group_authority_invitation", {
    ...args(creator, id),
    ...requestKey,
    p_role: "co_organizer",
  });
  const [recovery] = await rpc(creator, "create_group_authority_invitation", {
    ...args(creator, id),
    ...requestKey,
    p_role: "co_organizer",
  });
  equal(recovery.invite_token === null, true, "Authority secret returned once");
  equal(
    recovery.relationship_id,
    lostSecret.relationship_id,
    "Lost secret recovers metadata only",
  );
  await rpc(creator, "revoke_group_authority_invitation", {
    ...expected(creator),
    ...key(),
    p_invitation_id: recovery.relationship_id,
  });
  const [issuerPending] = await rpc(
    coCreator,
    "create_group_authority_invitation",
    { ...args(coCreator, id), ...key(), p_role: "co_creator" },
  );
  await rpc(creator, "change_group_delegate_role", {
    ...expected(creator),
    ...key(),
    p_delegate_id: structural.accepted.relationship_id,
    p_role: "co_organizer",
  });
  equal(
    (
      await rpc(guest, "get_group_authority_invitation_preview", {
        p_token: issuerPending.invite_token,
      })
    )[0].available,
    false,
    "Issuer structural role loss invalidates invitation",
  );
  await denied(
    other,
    "accept_group_authority_invitation",
    { ...expected(other), ...key(), p_token: issuerPending.invite_token },
    "PT409",
  );
  await rpc(creator, "change_group_delegate_role", {
    ...expected(creator),
    ...key(),
    p_delegate_id: structural.accepted.relationship_id,
    p_role: "co_creator",
  });
  equal(
    (
      await rpc(coCreator, "get_group_structural_context", args(coCreator, id))
    )[0].version,
    2,
    "Membership activity leaves content version alone",
  );
  await denied(coCreator, "change_group_delegate_role", {
    ...expected(coCreator),
    ...key(),
    p_delegate_id: structural.accepted.relationship_id,
    p_role: "co_organizer",
  });
  // Both blocking directions against all three manager roles, plus pending convergence.
  for (const manager of [creator, coCreator, organizer]) {
    await rpc(applicant, "leave_group", {
      ...expected(applicant),
      ...key(),
      p_membership_id: (
        await rpc(applicant, "get_own_group_role", args(applicant, id))
      )[0].current_membership_id,
    });
    for (const inbound of [false, true]) {
      const pendingRequest = await request(applicant, id);
      const blocker = inbound ? manager : applicant,
        blocked = inbound ? applicant : manager;
      await rpc(blocker, "block_user", {
        p_expected_blocker_profile_id: blocker.id,
        p_blocked_profile_id: blocked.id,
      });
      equal(
        (
          await rpc(
            applicant,
            "list_own_group_join_requests",
            expected(applicant),
          )
        ).find((row) => row.request_id === pendingRequest.relationship_id)
          .status,
        inbound ? "rejected" : "withdrawn",
        "Direction-safe pending convergence",
      );
      await denied(
        applicant,
        "accept_group_participant_invitation",
        { ...expected(applicant), ...key(), p_token: sharing.invite_token },
        "PT409",
      );
      await denied(
        applicant,
        "create_group_join_request",
        { ...args(applicant, id), ...key() },
        "PT409",
      );
      await rpc(blocker, "unblock_user", {
        p_expected_blocker_profile_id: blocker.id,
        p_blocked_profile_id: blocked.id,
      });
    }
    await join(applicant, sharing);
  }
  await rpc(organizer, "block_user", {
    p_expected_blocker_profile_id: organizer.id,
    p_blocked_profile_id: applicant.id,
  });
  equal(
    (await rpc(applicant, "get_own_group_role", args(applicant, id)))[0]
      .membership_status,
    "current",
    "Blocks retain accepted relationships",
  );
  await rpc(creator, "revoke_group_delegate", {
    ...expected(creator),
    ...key(),
    p_delegate_id: operational.accepted.relationship_id,
  });
  await rpc(applicant, "leave_group", {
    ...expected(applicant),
    ...key(),
    p_membership_id: (
      await rpc(applicant, "get_own_group_role", args(applicant, id))
    )[0].current_membership_id,
  });
  await join(applicant, sharing);
  checks++;
  await rpc(organizer, "unblock_user", {
    p_expected_blocker_profile_id: organizer.id,
    p_blocked_profile_id: applicant.id,
  });
  // Revocation after a blocked review's snapshot must invalidate operational authority.
  const managerAgain = await invite(creator, organizer, id);
  await photo(other);
  const heldRequest = await request(other, id);
  const revokedReview = await afterWait(
    id,
    "accept_group_join_request",
    () =>
      attempt(organizer, "accept_group_join_request", {
        ...expected(organizer),
        ...key(),
        p_request_id: heldRequest.relationship_id,
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select * from public.revoke_group_delegate(${creator.id}::uuid,${managerAgain.accepted.relationship_id}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  assert.ok(["42501", "PT409"].includes(revokedReview.error?.code));
  checks++;
  // Suppression, archive and rotation committed while admission waits all deny it.
  for (const transition of ["suppress", "archive", "rotate"]) {
    const isolated = await group(creator),
      isolatedLink = await link(creator, isolated);
    const deniedAdmission = await afterWait(
      isolated,
      "accept_group_participant_invitation",
      () =>
        attempt(other, "accept_group_participant_invitation", {
          ...expected(other),
          ...key(),
          p_token: isolatedLink.invite_token,
        }),
      async (tx) => {
        if (transition === "suppress")
          await asUser(
            tx,
            staff,
            (db) =>
              db`select public.set_group_directory_suppression(${staff.id}::uuid,${isolated}::uuid,${randomUUID()}::uuid,2,true,'Fictional suppression reason')`,
          );
        else if (transition === "archive")
          await asUser(
            tx,
            creator,
            (db) =>
              db`select public.set_group_publication_state(${creator.id}::uuid,${isolated}::uuid,${randomUUID()}::uuid,2,'archived')`,
          );
        else
          await asUser(
            tx,
            creator,
            (db) =>
              db`select * from public.regenerate_group_participant_invitation(${creator.id}::uuid,${isolated}::uuid,${randomUUID()}::uuid)`,
          );
      },
    );
    equal(
      deniedAdmission.error?.code,
      "PT409",
      `${transition} after lock wait denies admission`,
    );
  }
  // Co-creator can archive/restore, then loses all draft content access.
  const archiveKey = key();
  await rpc(coCreator, "set_managed_group_publication_state", {
    ...args(coCreator, id),
    ...archiveKey,
    p_expected_version: 2,
    p_publication_state: "archived",
  });
  const restoreKey = key();
  await rpc(coCreator, "set_managed_group_publication_state", {
    ...args(coCreator, id),
    ...restoreKey,
    p_expected_version: 3,
    p_publication_state: "draft",
  });
  equal(
    await rpc(coCreator, "set_managed_group_publication_state", {
      ...args(coCreator, id),
      ...restoreKey,
      p_expected_version: 3,
      p_publication_state: "draft",
    }),
    4,
    "Restore retry recovers version without draft read",
  );
  await denied(coCreator, "get_group_structural_context", args(coCreator, id));
  await denied(coCreator, "set_managed_group_publication_state", {
    ...args(coCreator, id),
    ...key(),
    p_expected_version: 4,
    p_publication_state: "published",
  });
  equal(
    (await rpc(creator, "get_own_group", args(creator, id)))[0]
      .publication_state,
    "draft",
    "Creator keeps draft ownership",
  );
  await rpc(creator, "set_group_publication_state", {
    ...args(creator, id),
    ...key(),
    p_expected_version: 4,
    p_publication_state: "published",
  });
  // Additional independent fixtures keep content versions and recovery explicit.
  const editorGroup = await group(creator);
  const editorDelegate = await invite(
    creator,
    coCreator,
    editorGroup,
    "co_creator",
  );
  const editorLink = await link(creator, editorGroup);
  const editorKey = key();
  const edited = {
    ...content,
    description: "Fictional updated shared group purpose and responsibilities.",
  };
  equal(
    await rpc(coCreator, "update_managed_group", {
      ...args(coCreator, editorGroup),
      ...editorKey,
      p_expected_version: 2,
      p_content: edited,
    }),
    3,
    "Co-creator edits published content",
  );
  equal(
    await rpc(coCreator, "update_managed_group", {
      ...args(coCreator, editorGroup),
      ...editorKey,
      p_expected_version: 2,
      p_content: edited,
    }),
    3,
    "Structural command retry recovers version",
  );
  await denied(
    coCreator,
    "update_managed_group",
    {
      ...args(coCreator, editorGroup),
      ...key(),
      p_expected_version: 2,
      p_content: content,
    },
    "PT409",
  );
  await denied(
    applicant,
    "create_group_join_request",
    { ...args(applicant, editorGroup), ...key(), p_note: "界".repeat(501) },
    "22023",
  );
  const longNote = await rpc(applicant, "create_group_join_request", {
    ...args(applicant, editorGroup),
    ...key(),
    p_note: "界".repeat(500),
  });
  await rpc(applicant, "withdraw_group_join_request", {
    ...expected(applicant),
    ...key(),
    p_request_id: longNote[0].relationship_id,
  });
  await photo(coCreator);
  const selfRequest = await request(coCreator, editorGroup);
  await denied(coCreator, "accept_group_join_request", {
    ...expected(coCreator),
    ...key(),
    p_request_id: selfRequest.relationship_id,
  });
  await rpc(coCreator, "withdraw_group_join_request", {
    ...expected(coCreator),
    ...key(),
    p_request_id: selfRequest.relationship_id,
  });
  const freshActions = await Promise.all([
    join(other, editorLink),
    join(other, editorLink),
  ]);
  equal(
    new Set(freshActions.map((row) => row.relationship_id)).size,
    1,
    "Independent simultaneous actions share one current episode",
  );
  const requestRaceGroup = await group(creator);
  const requestRace = await Promise.all(
    Array.from({ length: 2 }, () =>
      attempt(other, "create_group_join_request", {
        ...args(other, requestRaceGroup),
        ...key(),
      }),
    ),
  );
  equal(
    requestRace.filter((result) => !result.error).length,
    1,
    "Independent concurrent request actions admit one pending attempt",
  );
  equal(
    (
      await sql`select count(*)::int as n from private.group_join_requests where group_id=${requestRaceGroup}::uuid and requester_id=${other.id}::uuid and status='pending'`
    )[0].n,
    1,
    "Pending-request uniqueness survives distinct action keys",
  );
  const oldAction = key(),
    oldAdmission = await join(applicant, editorLink, oldAction);
  const rotateKey = key();
  const [rotated] = await rpc(
    creator,
    "regenerate_group_participant_invitation",
    { ...args(creator, editorGroup), ...rotateKey },
  );
  equal(
    (await join(applicant, editorLink, oldAction)).relationship_id,
    oldAdmission.relationship_id,
    "Revoked-generation retry recovers original interval",
  );
  await denied(
    applicant,
    "accept_group_participant_invitation",
    { ...expected(applicant), ...oldAction, p_token: rotated.invite_token },
    "PT409",
  );
  await rpc(creator, "regenerate_group_participant_invitation", {
    ...args(creator, editorGroup),
    ...key(),
  });
  const [oldRotation] = await rpc(
    creator,
    "regenerate_group_participant_invitation",
    { ...args(creator, editorGroup), ...rotateKey },
  );
  equal(
    oldRotation.invite_token === null,
    true,
    "Rotation retry never retrieves a replaced secret",
  );
  equal(
    oldRotation.invitation_id,
    rotated.invitation_id,
    "Rotation retry retains original generation metadata",
  );
  // Complete profile/photo removal does not prevent safe exits or revoke roles.
  await sql`delete from public.profile_photos where profile_id=${applicant.id}::uuid`;
  await sql`update public.profiles set display_name=null where id=${applicant.id}::uuid`;
  await rpc(applicant, "leave_group", {
    ...expected(applicant),
    ...key(),
    p_membership_id: oldAdmission.relationship_id,
  });
  await sql`update public.profiles set display_name='Fictional applicant' where id=${applicant.id}::uuid`;
  await photo(applicant);
  const offerGroup = await group(creator),
    offerLink = await link(creator, offerGroup);
  const offeredMember = await join(other, offerLink);
  const [declinable] = await rpc(creator, "create_group_role_offer", {
    ...args(creator, offerGroup),
    ...key(),
    p_membership_id: offeredMember.relationship_id,
    p_role: "co_organizer",
  });
  const declineKey = key();
  equal(
    (
      await rpc(other, "decline_group_role_offer", {
        ...expected(other),
        ...declineKey,
        p_offer_id: declinable.relationship_id,
      })
    )[0].current_status,
    "declined",
    "Recipient can decline targeted authority",
  );
  equal(
    (await rpc(other, "get_own_group_role", args(other, offerGroup)))[0]
      .authority_role,
    null,
    "Decline grants no role",
  );
  // Expiry is evaluated after waiting using wall clock, not transaction start.
  const expiryToken = "x".repeat(43),
    expiryInvitation = randomUUID();
  await sql`insert into private.group_authority_invitations(id,group_id,issuer_id,offered_role,token_digest,created_at,expires_at)
    values(${expiryInvitation}::uuid,${offerGroup}::uuid,${creator.id}::uuid,'co_organizer',encode(extensions.digest(${expiryToken},'sha256'),'hex'),clock_timestamp()-interval '7 days',clock_timestamp()+interval '250 milliseconds')`;
  const expired = await afterWait(
    offerGroup,
    "accept_group_authority_invitation",
    () =>
      attempt(applicant, "accept_group_authority_invitation", {
        ...expected(applicant),
        ...key(),
        p_token: expiryToken,
      }),
    async (tx) => {
      await tx`select pg_sleep(0.35)`;
    },
  );
  equal(
    expired.error?.code,
    "PT409",
    "Authority expiry is rechecked after row wait",
  );
  const acceptedBearer = await invite(creator, applicant, offerGroup);
  await rpc(creator, "revoke_group_delegate", {
    ...expected(creator),
    ...key(),
    p_delegate_id: acceptedBearer.accepted.relationship_id,
  });
  equal(
    (
      await rpc(applicant, "accept_group_authority_invitation", {
        ...expected(applicant),
        ...key(),
        p_token: acceptedBearer.invitation.invite_token,
      })
    )[0].current_status,
    "revoked",
    "Accepted bearer retries do not regrant revoked role",
  );
  const issuing = await invite(creator, coCreator, offerGroup, "co_creator");
  const [losingOffer] = await rpc(coCreator, "create_group_role_offer", {
    ...args(coCreator, offerGroup),
    ...key(),
    p_membership_id: offeredMember.relationship_id,
    p_role: "co_creator",
  });
  const issuerLoss = await afterWait(
    offerGroup,
    "accept_group_role_offer",
    () =>
      attempt(other, "accept_group_role_offer", {
        ...expected(other),
        ...key(),
        p_offer_id: losingOffer.relationship_id,
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select * from public.revoke_group_delegate(${creator.id}::uuid,${issuing.accepted.relationship_id}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  equal(
    issuerLoss.error?.code,
    "PT409",
    "Issuer loss during acceptance wait invalidates offer",
  );
  const heldAdmissionGroup = await group(creator),
    heldLink = await link(creator, heldAdmissionGroup);
  const heldManager = await invite(creator, organizer, heldAdmissionGroup);
  const managerSet = await afterWait(
    heldAdmissionGroup,
    "accept_group_participant_invitation",
    () =>
      attempt(applicant, "accept_group_participant_invitation", {
        ...expected(applicant),
        ...key(),
        p_token: heldLink.invite_token,
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select * from public.revoke_group_delegate(${creator.id}::uuid,${heldManager.accepted.relationship_id}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  equal(
    managerSet.error?.code,
    "PT409",
    "Admission retries if its locked manager set changes",
  );
  await join(applicant, heldLink);
  await rpc(coCreator, "step_down_group_authority", {
    ...expected(coCreator),
    ...key(),
    p_delegate_id: editorDelegate.accepted.relationship_id,
  });
  // Orphaned accountable identity fails closed despite active delegates.
  const orphanCreator = await user("orphan-creator");
  const orphan = await group(orphanCreator);
  await invite(orphanCreator, coCreator, orphan, "co_creator");
  const orphanLink = await link(coCreator, orphan);
  await sql`delete from public.profiles where id=${orphanCreator.id}::uuid`;
  await sql`delete from auth.users where id=${orphanCreator.id}::uuid`;
  equal(
    (
      await rpc(guest, "get_group_participant_invitation_preview", {
        p_token: orphanLink.invite_token,
      })
    )[0].available,
    false,
    "Orphan invitation fails closed",
  );
  await denied(
    coCreator,
    "get_group_structural_context",
    args(coCreator, orphan),
  );
  await denied(
    other,
    "accept_group_participant_invitation",
    { ...expected(other), ...key(), p_token: orphanLink.invite_token },
    "PT409",
  );
  const [privacy] =
    await sql`select not exists(select 1 from private.group_relationship_receipts where result ? 'invite_token') as receipts_clean,
    not exists(select 1 from private.audit_events where target_type='community_group' and metadata::text like ${`%${sharing.invite_token}%`}) as audits_clean`;
  equal(
    privacy,
    { receipts_clean: true, audits_clean: true },
    "No raw secrets in receipts/audit",
  );
  console.log(
    `GRP03A Auth/PostgREST verification passed: ${checks} assertions, concurrent retries/admissions, observed lock waits, role/state/privacy/blocking/recovery contracts.`,
  );
}
try {
  if (process.argv.includes("--upgrade")) await upgrade();
  else await verify();
} finally {
  await sql.end();
}
