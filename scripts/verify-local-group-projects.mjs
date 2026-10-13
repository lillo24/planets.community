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
    email: `grp03c-${run}-${label}@planets.invalid`,
    verifierName: "group-projects",
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
async function afterWait(id, functionName, launch, transition, source = false) {
  let ready, release;
  const locked = new Promise((resolve) => {
    ready = resolve;
  });
  const resume = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    if (source)
      await tx`select id from public.proposals where id=${id}::uuid for update`;
    else
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

function proposalInput(person, request = randomUUID()) {
  return {
    p_expected_creator_profile_id: person.id,
    p_client_request_id: request,
    p_title: "Fictional group garden",
    p_summary: "Fictional neighbours plan a shared garden together.",
    p_description:
      "Fictional public activity with independently requested participation.",
    p_starts_at: new Date(Date.now() + 7 * 86400000).toISOString(),
    p_ends_at: new Date(Date.now() + 7 * 86400000 + 3600000).toISOString(),
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Trento",
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: 10,
    p_count_organizers_toward_capacity: false,
  };
}
async function proposal(person, id, input = proposalInput(person)) {
  return rpc(person, "create_group_editor_proposal_draft", {
    ...input,
    p_group_id: id,
  });
}
const own = (person, id) =>
  rpc(person, "get_own_project_group", {
    ...expected(person),
    p_project_id: id,
  });
const set = (person, id, version, groupId, request = randomUUID()) =>
  rpc(person, "set_project_group", {
    ...expected(person),
    p_project_id: id,
    p_expected_version: version,
    p_group_id: groupId,
    p_client_request_id: request,
  });
const publish = (person, id, version, groupId, idea = false) =>
  rpc(person, "publish_project_with_group", {
    ...expected(person),
    p_project_id: id,
    p_expected_version: version,
    p_group_id: groupId,
    p_idea: idea,
  });

async function upgrade() {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade requires an explicitly disposable local stack.",
  );
  const migrations = (await readdir("supabase/migrations"))
    .filter((n) => n.endsWith(".sql"))
    .sort();
  const index = migrations.findIndex((n) =>
    n.endsWith("_group_project_attribution.sql"),
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
  command(process.execPath, ["scripts/verify-local-group-membership.mjs"]);
  // Select predecessor columns explicitly, including all populated private
  // planning, authority, chat, template, policy, group and receipt records.
  const tables =
    await sql`select table_schema||'.'||table_name as name,array_agg(column_name order by ordinal_position) as columns
    from information_schema.columns where table_schema in ('public','private') and table_name in
    (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r')
    group by table_schema,table_name order by 1`;
  async function snapshot(table) {
    const [{ rows }] =
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) as rows
      from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
    return {
      count: rows.length,
      hash: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  }
  const before = new Map();
  for (const table of tables) before.set(table.name, await snapshot(table));
  for (const name of [
    "public.projects",
    "private.community_groups",
    "private.group_memberships",
    "private.group_delegates",
    "public.project_memberships",
    "public.project_chat_messages",
    "private.proposal_templates",
  ])
    assert.ok(
      before.get(name)?.count > 0,
      `Populated preservation requires ${name}`,
    );
  command("supabase", ["migration", "up", "--local"]);
  command("supabase", ["migration", "up", "--local"]);
  for (const table of tables)
    equal(
      await snapshot(table),
      before.get(table.name),
      `Preserves ${table.name}`,
    );
  equal(
    (
      await sql`select count(*)::int as n from public.projects where attributed_group_id is not null`
    )[0].n,
    0,
    "No retrofitted attribution",
  );
  equal(
    (
      await sql`select count(*)::int as n from public.projects p join public.proposals o on o.id=p.id
    where o.published_at is not null and p.first_published_at is distinct from o.published_at`
    )[0].n,
    0,
    "Published personal history frozen",
  );
  console.log(
    `GRP03C populated upgrade passed: ${checks} preservation assertions.`,
  );
}

async function verify() {
  const [creator, representative, organizer, outsider, staff] =
    await Promise.all(
      ["creator", "representative", "organizer", "outsider", "staff"].map(
        (label) => user(label),
      ),
    );
  for (const person of [creator, representative, organizer, outsider, staff])
    await photo(person);
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active) values(${staff.id}::uuid,'moderator',true)`;
  const guest = {
    client: createClient(status.apiUrl, status.publishableKey, {
      auth: { persistSession: false },
    }),
  };
  const id = await group(creator),
    otherGroup = await group(outsider);
  const rep = await invite(creator, representative, id, "co_creator");
  await invite(creator, organizer, id, "co_organizer");
  equal(
    (
      await rpc(
        representative,
        "list_my_publishable_groups",
        expected(representative),
      )
    ).map((g) => g.id),
    [id],
    "Representative need not be a member",
  );
  for (const person of [organizer, outsider, staff]) {
    equal(
      (await rpc(person, "list_my_publishable_groups", expected(person))).some(
        (g) => g.id === id,
      ),
      false,
      "No incidental representation",
    );
    await denied(person, "create_group_editor_proposal_draft", {
      ...proposalInput(person),
      p_group_id: id,
    });
  }
  await denied(guest, "list_my_publishable_groups", expected(creator));
  const rejectedInput = { ...proposalInput(outsider), p_group_id: id };
  const rejected = await outsider.client.rpc(
    "create_group_editor_proposal_draft",
    rejectedInput,
  );
  equal(rejected.error?.code, "42501", "Representation denial is explicit");
  equal(
    JSON.parse(rejected.error.details).reason,
    "group_representation_unavailable",
    "Only post-lock representation rejection permits a new intent",
  );
  equal(
    (
      await sql`select count(*)::int n from private.proposal_draft_creations where creator_profile_id=${outsider.id}::uuid and client_request_id=${rejectedInput.p_client_request_id}::uuid`
    )[0].n,
    0,
    "Rejected atomic creation has no accepted destination receipt",
  );
  await denied(outsider, "list_my_publishable_groups", expected(creator));
  const input = proposalInput(representative),
    project = await proposal(representative, id, input);
  equal(
    await proposal(representative, id, input),
    project,
    "Exact creation retry recovers destination",
  );
  equal(
    await Promise.all([
      proposal(representative, id, input),
      proposal(representative, id, input),
    ]),
    [project, project],
    "Concurrent exact deliveries recover one destination",
  );
  await denied(
    representative,
    "create_group_editor_proposal_draft",
    { ...input, p_group_id: otherGroup },
    "22023",
  );
  equal(
    await rpc(representative, "recover_editor_proposal_draft", {
      p_expected_creator_profile_id: representative.id,
      p_client_request_id: input.p_client_request_id,
    }),
    project,
    "Legacy recovery finds atomic group draft",
  );
  equal(
    (await own(representative, project)).group_id,
    id,
    "Canonical selection retained",
  );
  equal(
    await rpc(guest, "get_public_project_groups", { p_project_ids: [project] }),
    [],
    "Draft association private",
  );
  await denied(creator, "get_own_project_group", {
    ...expected(creator),
    p_project_id: project,
  });
  await denied(creator, "set_project_group", {
    ...expected(creator),
    p_project_id: project,
    p_expected_version: 1,
    p_group_id: null,
    ...key(),
  });
  const commandKey = randomUUID();
  const clear = await set(representative, project, 1, null, commandKey);
  equal(clear.version, 2, "Clear advances revision");
  equal(
    await set(representative, project, 1, null, commandKey),
    clear,
    "Exact set receipt replay",
  );
  await denied(
    representative,
    "set_project_group",
    {
      ...expected(representative),
      p_project_id: project,
      p_expected_version: 1,
      p_group_id: id,
      p_client_request_id: commandKey,
    },
    "22023",
  );
  await set(representative, project, 2, id);
  await denied(
    representative,
    "publish_project_with_group",
    {
      ...expected(representative),
      p_project_id: project,
      p_expected_version: 2,
      p_group_id: null,
      p_idea: false,
    },
    "PT409",
  );
  await publish(representative, project, 3, id, true);
  equal(
    await publish(representative, project, 3, id, true),
    project,
    "Exact publication retry returns the same published Project",
  );
  equal(
    (await own(representative, project)).frozen,
    true,
    "Idea freezes association",
  );
  await denied(
    representative,
    "set_project_group",
    {
      ...expected(representative),
      p_project_id: project,
      p_expected_version: 3,
      p_group_id: null,
      ...key(),
    },
    "55000",
  );
  const publicGroup = (
    await rpc(guest, "get_public_project_groups", { p_project_ids: [project] })
  )[0];
  equal(publicGroup.group_id, id, "Public Idea attribution");
  equal(
    Object.keys(publicGroup).sort(),
    ["group_id", "group_kind", "name", "project_id", "state"],
    "Public allowlist",
  );
  equal(
    (await rpc(guest, "list_public_group_projects", { p_group_id: id }))[0]
      .project_id,
    project,
    "Public group feed",
  );
  equal(
    (
      await sql`select creator_profile_id from public.projects where id=${project}::uuid`
    )[0].creator_profile_id,
    representative.id,
    "Real human Creator retained",
  );
  equal(
    (
      await sql`select count(*)::int as n from public.project_delegates where project_id=${project}::uuid`
    )[0].n,
    0,
    "No inherited delegates",
  );
  equal(
    (
      await sql`select count(*)::int as n from public.project_memberships where project_id=${project}::uuid`
    )[0].n,
    0,
    "No inherited memberships",
  );
  const groupVersion = (
    await sql`select version from private.community_groups where id=${id}::uuid`
  )[0].version;
  await rpc(staff, "set_group_directory_suppression", {
    p_expected_staff_profile_id: staff.id,
    p_group_id: id,
    ...key(),
    p_expected_version: groupVersion,
    p_directory_suppressed: true,
    p_reason: "Fictional moderation suppression.",
  });
  equal(
    await rpc(guest, "get_public_project_groups", { p_project_ids: [project] }),
    [{ project_id: project, state: "unavailable" }],
    "Suppression reveals no group UUID/name",
  );
  await denied(guest, "list_public_group_projects", { p_group_id: id });
  await rpc(staff, "set_group_directory_suppression", {
    p_expected_staff_profile_id: staff.id,
    p_group_id: id,
    ...key(),
    p_expected_version: Number(groupVersion) + 1,
    p_directory_suppressed: false,
    p_reason: "Fictional moderation restoration.",
  });
  equal(
    (
      await rpc(guest, "get_public_project_groups", {
        p_project_ids: [project],
      })
    )[0].group_id,
    id,
    "Fresh restore restores badge",
  );
  // Actual PostgREST lock wait: role loss commits before first publication.
  const held = await proposal(representative, id);
  const race = await afterWait(
    id,
    "publish_proposal_idea",
    async () =>
      await representative.client.rpc("publish_proposal_idea", {
        p_expected_creator_profile_id: representative.id,
        p_proposal_id: held,
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select * from public.revoke_group_delegate(${creator.id}::uuid,${rep.accepted.relationship_id}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  equal(
    race.error?.code,
    "42501",
    "Live role loss after lock wait denies publication",
  );
  equal(
    (
      await sql`select lifecycle_state from public.proposals where id=${held}::uuid`
    )[0].lifecycle_state,
    "draft",
    "Denied publish rolls back source",
  );
  equal(
    (await own(representative, held)).frozen,
    false,
    "Denied publish does not freeze",
  );
  equal(
    await proposal(representative, id, { ...input }),
    project,
    "Accepted creation receipt survives role loss",
  );
  equal(
    await publish(representative, project, 3, id, true),
    project,
    "Already published provenance retries without a new representation grant",
  );
  await set(representative, held, 1, null);
  await publish(representative, held, 2, null, true);
  equal(
    await rpc(guest, "get_public_project_groups", { p_project_ids: [held] }),
    [],
    "Cleared retained draft publishes personally",
  );
  // Defined and recurring legacy publication also share the source guard.
  const defined = await proposal(creator, id);
  await rpc(creator, "publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: defined,
  });
  equal(
    (await own(creator, defined)).frozen,
    true,
    "Defined legacy publish freezes",
  );
  const recurring = await rpc(
    creator,
    "create_group_editor_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      ...key(),
      p_group_id: id,
      p_title: "Fictional weekly Tavolo",
      p_summary: "Fictional weekly neighbours discuss their garden.",
      p_description: "Fictional recurring independent Project.",
      p_topic: "Gardening",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
      p_exact_meeting_text: "Fictional meeting instructions",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 1,
      p_day_of_month: null,
      p_local_start_time: "18:00",
      p_duration_minutes: 60,
      p_event_timezone: "Europe/Rome",
      p_effective_from: new Date(Date.now() + 86400000)
        .toISOString()
        .slice(0, 10),
      p_registration_capacity: 10,
      p_count_organizers_toward_capacity: false,
    },
  );
  await rpc(creator, "publish_recurring_activity", {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: recurring,
  });
  equal(
    (await own(creator, recurring)).frozen,
    true,
    "Tavolo legacy publish freezes",
  );
  const page = await rpc(guest, "list_public_group_projects", {
    p_group_id: id,
    p_limit: 1,
  });
  const page2 = await rpc(guest, "list_public_group_projects", {
    p_group_id: id,
    p_limit: 1,
    p_cursor_published_at: page[0].published_at,
    p_cursor_id: page[0].project_id,
  });
  equal(page.length, 1, "Bounded feed");
  equal(
    page[0].project_id === page2[0].project_id,
    false,
    "Stable paired feed cursor",
  );
  await denied(
    guest,
    "list_public_group_projects",
    { p_group_id: id, p_limit: 51 },
    "22023",
  );
  await denied(
    guest,
    "list_public_group_projects",
    { p_group_id: id, p_cursor_id: project },
    "22023",
  );
  await denied(
    guest,
    "get_public_project_groups",
    { p_project_ids: Array(51).fill(project) },
    "22023",
  );
  for (const role of ["anon", "authenticated", "service_role"]) {
    equal(
      (
        await sql`select has_table_privilege(${role},'public.projects','SELECT') as yes`
      )[0].yes,
      false,
      "Anchor remains private",
    );
    equal(
      (
        await sql`select has_table_privilege(${role},'private.project_attribution_receipts','SELECT') as yes`
      )[0].yes,
      false,
      "Receipts remain private",
    );
  }
  // CHECK01 keeps draft logistics as private suggestions on Idea publication.
  // Confirm them through ordinary Project Organization, even after group loss.
  let organization = await rpc(representative, "get_project_organization_v1", {
    ...expected(representative),
    p_project_id: project,
  });
  for (const kind of ["location", "schedule", "capacity"])
    organization = await rpc(representative, "mutate_project_organization_v1", {
      ...expected(representative),
      p_project_id: project,
      p_expected_revision: organization.revision,
      p_request_id: randomUUID(),
      p_command: { action: "confirm_decision", kind },
    });
  equal(
    (
      await rpc(representative, "get_proposal_promotion_requirements", {
        p_expected_profile_id: representative.id,
        p_proposal_id: project,
      })
    ).missing_fields,
    [],
    "Explicit planning confirmation enables promotion",
  );
  await rpc(representative, "promote_proposal_idea", {
    p_expected_profile_id: representative.id,
    p_proposal_id: project,
  });
  equal(
    (await own(representative, project)).group_id,
    id,
    "Idea promotion preserves frozen attribution after role loss",
  );
  await rpc(creator, "pause_recurring_activity", {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: recurring,
  });
  equal(
    (
      await rpc(guest, "get_public_project_groups", {
        p_project_ids: [recurring],
      })
    )[0].group_id,
    id,
    "Paused Tavolo retains attribution",
  );
  await rpc(creator, "end_recurring_activity", {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: recurring,
  });
  equal(
    (await own(creator, recurring)).group_id,
    id,
    "Ended Tavolo preserves publication provenance",
  );

  // Independent transactions really queue the HTTP publisher before each change.
  for (const operation of ["archive", "suppress", "accountability", "photo"]) {
    const raceCreator = await user(`race-${operation}`);
    await photo(raceCreator);
    const raceGroup = await group(raceCreator);
    const raceProject = await proposal(raceCreator, raceGroup);
    const outcome = await afterWait(
      raceGroup,
      "publish_proposal_idea",
      async () =>
        await raceCreator.client.rpc("publish_proposal_idea", {
          p_expected_creator_profile_id: raceCreator.id,
          p_proposal_id: raceProject,
        }),
      async (tx) => {
        const [{ version }] =
          await tx`select version from private.community_groups where id=${raceGroup}::uuid`;
        if (operation === "archive")
          await asUser(
            tx,
            raceCreator,
            (db) =>
              db`select public.set_group_publication_state(${raceCreator.id}::uuid,${raceGroup}::uuid,${randomUUID()}::uuid,${version},'archived')`,
          );
        else if (operation === "suppress")
          await asUser(
            tx,
            staff,
            (db) =>
              db`select public.set_group_directory_suppression(${staff.id}::uuid,${raceGroup}::uuid,${randomUUID()}::uuid,${version},true,'Fictional controlled race')`,
          );
        else if (operation === "accountability")
          await tx`update public.profiles set display_name=null where id=${raceCreator.id}::uuid`;
        else
          await tx`delete from public.profile_photos where profile_id=${raceCreator.id}::uuid`;
      },
    );
    equal(
      outcome.error?.code,
      operation === "photo" ? "PT422" : "42501",
      `${operation} is rechecked after the actual lock wait`,
    );
    equal(
      (
        await sql`select lifecycle_state from public.proposals where id=${raceProject}::uuid`
      )[0].lifecycle_state,
      "draft",
      `${operation} race is atomic`,
    );
    equal(
      (await own(raceCreator, raceProject)).frozen,
      false,
      `${operation} race retains unfrozen private draft`,
    );
  }
  const noPhoto = await user("no-photo"),
    noPhotoGroup = await group(noPhoto);
  const noPhotoProject = await proposal(noPhoto, noPhotoGroup);
  await denied(
    noPhoto,
    "publish_proposal_idea",
    {
      p_expected_creator_profile_id: noPhoto.id,
      p_proposal_id: noPhotoProject,
    },
    "PT422",
  );
  // Trusted direct source changes cannot bypass the group first-publication guard.
  let directError;
  try {
    await sql`update public.proposals set lifecycle_state='published',published_at=clock_timestamp() where id=${noPhotoProject}::uuid`;
  } catch (error) {
    directError = error.code;
  }
  equal(
    directError,
    "42501",
    "Direct source transition without real actor denied",
  );
  try {
    await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub',${noPhoto.id},true)`;
      await tx`update public.proposals set lifecycle_state='published',published_at=clock_timestamp() where id=${noPhotoProject}::uuid`;
    });
  } catch (error) {
    directError = error.code;
  }
  equal(
    directError,
    "PT422",
    "Direct grouped source transition retains human photo gate",
  );

  await sql`update public.proposals set starts_at='2020-01-01T10:00:00Z',ends_at='2020-01-01T11:00:00Z' where id=${defined}::uuid`;
  const [{ template_id: communityTemplate }] =
    await sql`select id template_id from private.proposal_templates where source_proposal_id=${defined}::uuid`;
  const [communityPreview] = await rpc(
    guest,
    "get_public_proposal_template_v2",
    { p_template_id: communityTemplate },
  );
  const templateArgs = {
    p_expected_creator_profile_id: outsider.id,
    p_template_id: communityTemplate,
    p_content_version: communityPreview.content_version,
    p_client_request_id: randomUUID(),
    p_prefill_capacity: true,
  };
  const [personalCopy] = await rpc(
    outsider,
    "create_proposal_draft_from_template",
    templateArgs,
  );
  equal(
    (await own(outsider, personalCopy.proposal_id)).group_id,
    null,
    "Community template never inherits its source group",
  );
  const groupedArgs = {
    ...templateArgs,
    p_client_request_id: randomUUID(),
    p_group_id: otherGroup,
  };
  const [groupedCopy] = await rpc(
    outsider,
    "create_group_proposal_draft_from_template",
    groupedArgs,
  );
  equal(
    (await own(outsider, groupedCopy.proposal_id)).group_id,
    otherGroup,
    "Template creates atomically for independently selected group",
  );
  equal(
    (
      await rpc(
        outsider,
        "create_group_proposal_draft_from_template",
        groupedArgs,
      )
    )[0].proposal_id,
    groupedCopy.proposal_id,
    "Template exact retry returns same destination",
  );
  await denied(
    outsider,
    "create_group_proposal_draft_from_template",
    { ...groupedArgs, p_group_id: null },
    "22023",
  );
  const official = (
    await rpc(guest, "list_public_proposal_templates_v2", { p_limit: 50 })
  ).find((t) => t.is_official);
  assert.ok(official, "Official catalog fixture is available");
  const [officialPreview] = await rpc(
    guest,
    "get_public_proposal_template_v2",
    { p_template_id: official.template_id },
  );
  const [officialCopy] = await rpc(
    outsider,
    "create_group_proposal_draft_from_template",
    {
      ...groupedArgs,
      p_client_request_id: randomUUID(),
      p_template_id: official.template_id,
      p_content_version: officialPreview.content_version,
    },
  );
  equal(
    officialCopy.source_proposal_id,
    null,
    "Official provenance remains catalog-only",
  );
  equal(
    (await own(outsider, officialCopy.proposal_id)).group_id,
    otherGroup,
    "Official template independently selects registered group",
  );
  equal(
    (
      await sql`select creator_profile_id from public.projects where id=${officialCopy.proposal_id}::uuid`
    )[0].creator_profile_id,
    outsider.id,
    "Official template retains real human Creator",
  );
  const changing = await proposal(creator, id);
  const changed = await afterWait(
    changing,
    "publish_project_with_group",
    async () =>
      await creator.client.rpc("publish_project_with_group", {
        ...expected(creator),
        p_project_id: changing,
        p_expected_version: 1,
        p_group_id: id,
        p_idea: true,
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select public.set_project_group(${creator.id}::uuid,${changing}::uuid,${randomUUID()}::uuid,1,null)`,
      ),
    true,
  );
  equal(
    changed.error?.code,
    "PT409",
    "Concurrent selection change invalidates confirmed publication revision",
  );
  equal(
    (await own(creator, changing)).group_id,
    null,
    "Winning clear is retained without accidental publication",
  );
  const publishing = await proposal(creator, id);
  const frozen = await afterWait(
    publishing,
    "set_project_group",
    async () =>
      await creator.client.rpc("set_project_group", {
        ...expected(creator),
        p_project_id: publishing,
        p_expected_version: 1,
        p_group_id: null,
        ...key(),
      }),
    (tx) =>
      asUser(
        tx,
        creator,
        (db) =>
          db`select public.publish_proposal_idea(${creator.id}::uuid,${publishing}::uuid)`,
      ),
    true,
  );
  equal(
    frozen.error?.code,
    "55000",
    "Winning first publication prevents a queued clear",
  );
  equal(
    (await own(creator, publishing)).group_id,
    id,
    "Winning publication freezes original group",
  );
  const accountable = await user("deletable-accountable"),
    orphanGroup = await group(accountable);
  await invite(accountable, outsider, orphanGroup, "co_creator");
  const orphanProject = await proposal(outsider, orphanGroup);
  const orphaned = await afterWait(
    orphanGroup,
    "publish_proposal_idea",
    async () =>
      await outsider.client.rpc("publish_proposal_idea", {
        p_expected_creator_profile_id: outsider.id,
        p_proposal_id: orphanProject,
      }),
    async (tx) => {
      // Existing profiles -> Auth reference is restrictive; follow the current
      // deletion order instead of changing the baseline account lifecycle.
      await tx`delete from public.profiles where id=${accountable.id}::uuid`;
      await tx`delete from auth.users where id=${accountable.id}::uuid`;
    },
  );
  equal(
    orphaned.error?.code,
    "42501",
    "Deleted accountable Auth identity denies post-wait publication",
  );
  equal(
    (await own(outsider, orphanProject)).frozen,
    false,
    "Account erasure adds no provenance blocker and leaves private draft",
  );
  const tied = await Promise.all([
    proposal(creator, id),
    proposal(creator, id),
    proposal(creator, id),
  ]);
  await sql.begin((tx) =>
    asUser(
      tx,
      creator,
      (db) =>
        db`select public.publish_proposal_idea(${creator.id}::uuid,p) from unnest(${tied}::uuid[]) p`,
    ),
  );
  equal(
    (
      await sql`select count(distinct first_published_at)::int n from public.projects where id=any(${tied}::uuid[])`
    )[0].n,
    1,
    "Tie fixture uses one publication statement instant",
  );
  const tiePage = await rpc(guest, "list_public_group_projects", {
    p_group_id: id,
    p_limit: 2,
  });
  const tieNext = await rpc(guest, "list_public_group_projects", {
    p_group_id: id,
    p_limit: 2,
    p_cursor_published_at: tiePage[1].published_at,
    p_cursor_id: tiePage[1].project_id,
  });
  equal(
    [...tiePage, ...tieNext].slice(0, 3).map((row) => row.project_id),
    [...tied].sort().reverse(),
    "Equal publication instants use the paired UUID without skips or duplicates",
  );
  equal(
    Object.keys(tiePage[0]).sort(),
    [
      "definition_phase",
      "lifecycle_state",
      "project_id",
      "project_kind",
      "published_at",
      "summary",
      "title",
    ],
    "Group feed has only allowlisted public presentation and cursor fields",
  );
  console.log(
    `GRP03C Auth/PostgREST passed: ${checks} assertions, observed publication lock waits, frozen selection, public privacy, templates and independent authority.`,
  );
}
try {
  if (process.argv.includes("--upgrade")) await upgrade();
  else await verify();
} finally {
  await sql.end();
}
