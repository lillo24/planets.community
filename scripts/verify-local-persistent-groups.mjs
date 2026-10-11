import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readdir } from "node:fs/promises";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

const root = process.cwd();
const status = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    endpoint &&
      ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
    "Group verification requires loopback API, database and mailbox.",
  );
}
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
const guest = {
  client: createClient(status.apiUrl, status.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  }),
};
const content = (name = `Fictional group ${run}`, extra = {}) => ({
  name,
  description: "Fictional local people collaborating in a shared garden.",
  group_kind: "informal",
  locality: "Trento",
  volunteering_focus: true,
  ...extra,
});
const expected = (person) => ({ p_expected_profile_id: person.id });
const groupArgs = (person, id) => ({ ...expected(person), p_group_id: id });
const rpc = async (person, name, args = {}) => {
  const result = await person.client.rpc(name, args);
  assert.equal(
    result.error?.code ?? null,
    null,
    `${name} failed: ${result.error?.code} ${result.error?.message}`,
  );
  return result.data;
};
const denied = async (person, name, args, code = "42501") => {
  const result = await person.client.rpc(name, args);
  assert.equal(
    result.error?.code,
    code,
    `${name} must fail with ${code}, received ${result.error?.code}`,
  );
};
const own = async (person, id) =>
  (await rpc(person, "get_own_group", groupArgs(person, id)))[0];
const create = (person, page = content(), key = randomUUID()) =>
  rpc(person, "create_group_draft", {
    ...expected(person),
    p_client_request_id: key,
    p_content: page,
  });
const state = async (person, id, next, version, key = randomUUID()) =>
  rpc(person, "set_group_publication_state", {
    ...groupArgs(person, id),
    p_client_request_id: key,
    p_expected_version: version ?? (await own(person, id)).version,
    p_publication_state: next,
  });
const edit = (person, id, version, page, key = randomUUID()) =>
  rpc(person, "update_group", {
    ...groupArgs(person, id),
    p_client_request_id: key,
    p_expected_version: version,
    p_content: page,
  });
const staffArgs = (person, id) => ({
  p_expected_staff_profile_id: person.id,
  p_group_id: id,
});
const suppress = (staff, id, version, hidden, key = randomUUID()) =>
  rpc(staff, "set_group_directory_suppression", {
    ...staffArgs(staff, id),
    p_client_request_id: key,
    p_expected_version: version,
    p_directory_suppressed: hidden,
    p_reason: "Fictional private staff review reason.",
  });
const publicDetail = (id) => rpc(guest, "get_public_group", { p_group_id: id });
const list = (args = {}) => rpc(guest, "list_public_groups", args);

async function user(label, complete = true) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `grp-${run}-${label}@planets.invalid`,
    verifierName: "persistent-groups",
  });
  if (complete)
    await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional ${label}`})`;
  return person;
}
function command(executable, args) {
  const result = spawnSync(executable, args, {
    cwd: root,
    encoding: "utf8",
    shell: process.platform === "win32" && executable === "supabase",
    timeout: 240000,
    maxBuffer: 16 * 1024 * 1024,
  });
  // CLI status/Auth output can contain capabilities. Never emit raw child output.
  if (result.error || result.status !== 0)
    throw new Error(
      `Group upgrade ${executable === process.execPath ? args[0] : executable + " " + args[0]} failed (${result.status ?? result.error?.code}).`,
    );
}
async function upgrade() {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade resets the selected local database; designate it disposable explicitly.",
  );
  const migrations = (await readdir("supabase/migrations"))
    .filter((name) => name.endsWith(".sql"))
    .sort();
  const index = migrations.findIndex((name) =>
    name.endsWith("_persistent_groups_backend.sql"),
  );
  assert.ok(index > 0, "Canonical GRP01 baseline must exist.");
  command("supabase", [
    "db",
    "reset",
    "--local",
    "--version",
    migrations[index - 1].split("_")[0],
  ]);
  command(process.execPath, ["scripts/seed-local-demo-world.mjs"]);
  command(process.execPath, ["scripts/verify-local-moderation.mjs"]);
  await sql`insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from public.profiles limit 1 on conflict do nothing`;
  const tables =
    await sql`select table_schema||'.'||table_name as name,array_agg(column_name order by ordinal_position) as columns
    from information_schema.columns where table_schema in ('public','private') and table_name in
    (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') group by table_schema,table_name order by 1`;
  const snapshot = async (table) => {
    const [{ rows }] =
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) as rows from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
    return {
      count: rows.length,
      hash: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  };
  const before = new Map();
  for (const table of tables) before.set(table.name, await snapshot(table));
  for (const name of [
    "public.profiles",
    "public.projects",
    "public.project_chat_messages",
    "private.policy_acceptances",
    "private.moderation_reports",
    "private.proposal_templates",
  ])
    assert.ok(
      before.get(name)?.count > 0,
      `Populated upgrade requires ${name}.`,
    );
  command("supabase", ["migration", "up", "--local"]);
  command("supabase", ["migration", "up", "--local"]);
  for (const table of tables)
    assert.deepEqual(
      await snapshot(table),
      before.get(table.name),
      `Upgrade preserves every existing column and row in ${table.name}.`,
    );
  assert.equal(
    (await sql`select count(*)::int as n from private.community_groups`)[0].n,
    0,
  );
  console.log(
    `GRP01 populated upgrade passed: ${tables.length} existing tables preserved, including profiles, Projects, chats, policies, reports and official templates; second migration application harmless.`,
  );
}

async function verify() {
  const [owner, other, staff, inactive, incomplete] = await Promise.all([
    user("owner"),
    user("other"),
    user("staff"),
    user("inactive"),
    user("incomplete", false),
  ]);
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at) values (${staff.id}::uuid,'moderator',true,null),(${inactive.id}::uuid,'admin',false,clock_timestamp())`;
  const creationKey = randomUUID();
  const page = content(`Fictional ${run} 100%_\\ Garden`);
  const ids = await Promise.all(
    Array.from({ length: 12 }, () => create(owner, page, creationKey)),
  );
  const id = ids[0];
  assert.ok(
    ids.every((candidate) => candidate === id),
    "Concurrent duplicate deliveries establish one stable group ID.",
  );
  const [{ managers, creations, appointments }] = await sql`select
    (select count(*)::int from private.community_group_managers where group_id=${id}::uuid) as managers,
    (select count(*)::int from private.audit_events where target_id=${id}::uuid and action='group.created') as creations,
    (select count(*)::int from private.audit_events where target_id=${id}::uuid and action='group.manager_appointed') as appointments`;
  assert.deepEqual(
    { managers, creations, appointments },
    { managers: 1, creations: 1, appointments: 1 },
  );
  assert.deepEqual(
    await rpc(owner, "recover_group_command", {
      ...expected(owner),
      p_client_request_id: creationKey,
    }),
    [{ group_id: id, accepted_version: 1 }],
  );
  assert.deepEqual(
    await rpc(other, "recover_group_command", {
      ...expected(other),
      p_client_request_id: creationKey,
    }),
    [],
  );
  assert.deepEqual(
    await rpc(owner, "recover_group_command", {
      ...expected(owner),
      p_client_request_id: randomUUID(),
    }),
    [],
  );
  await denied(
    owner,
    "create_group_draft",
    {
      ...expected(owner),
      p_client_request_id: creationKey,
      p_content: content("Changed"),
    },
    "22023",
  );
  const separateId = await create(
    other,
    content(`Separate ${run}`),
    creationKey,
  );
  assert.notEqual(
    id,
    separateId,
    "Same UUID belongs to separate account namespaces.",
  );
  const invalidContent = [
    null,
    [],
    { ...page, verified_ets: true },
    { ...page, manager_profile_id: other.id },
    { ...page, directory_suppressed: false },
    { ...page, original_actor_id: other.id },
    { ...page, logo_url: "https://example.invalid/logo" },
    { ...page, group_kind: "ets" },
    { ...page, volunteering_focus: "true" },
    { ...page, name: "Planets Community Official" },
    { ...page, name: "Planets Community Staff" },
    { ...page, name: "PLANETS" },
    { ...page, description: "x".repeat(4001) },
    { ...page, locality: "x".repeat(121) },
  ];
  for (const p_content of invalidContent)
    await denied(
      owner,
      "create_group_draft",
      { ...expected(owner), p_client_request_id: randomUUID(), p_content },
      "22023",
    );
  for (const person of [guest, incomplete])
    await denied(person, "create_group_draft", {
      ...expected(owner),
      p_client_request_id: randomUUID(),
      p_content: page,
    });
  await denied(
    incomplete,
    "create_group_draft",
    {
      ...expected(incomplete),
      p_client_request_id: randomUUID(),
      p_content: page,
    },
    "55000",
  );
  await denied(owner, "create_group_draft", {
    ...expected(other),
    p_client_request_id: randomUUID(),
    p_content: page,
  });
  await denied(other, "get_own_group", groupArgs(other, id));
  await denied(other, "get_own_group", groupArgs(other, randomUUID()));
  assert.deepEqual(await publicDetail(id), []);
  const publishKey = randomUUID();
  assert.equal(await state(owner, id, "published", 1, publishKey), 2);
  assert.equal(
    await state(owner, id, "published", 1, publishKey),
    2,
    "Lifecycle retry recovers without a new version or audit.",
  );
  await denied(
    owner,
    "update_group",
    {
      ...groupArgs(owner, id),
      p_client_request_id: randomUUID(),
      p_expected_version: 1,
      p_content: page,
    },
    "PT409",
  );
  const updateKey = randomUUID();
  const edited = { ...page, description: page.description + " More purpose." };
  assert.equal(await edit(owner, id, 2, edited, updateKey), 3);
  assert.equal(await edit(owner, id, 2, edited, updateKey), 3);
  assert.equal((await own(owner, id)).version, 3);
  const publicRows = await publicDetail(id);
  assert.equal(publicRows.length, 1);
  assert.deepEqual(
    Object.keys(publicRows[0]).sort(),
    [
      "group_id",
      "name",
      "description",
      "group_kind",
      "locality",
      "volunteering_focus",
      "version",
      "created_at",
      "updated_at",
    ].sort(),
  );
  for (const person of [owner, other, guest]) {
    for (const table of [
      "community_groups",
      "community_group_managers",
      "community_group_command_receipts",
      "community_group_suppression_actions",
      "moderation_cases",
    ]) {
      assert.ok(
        (await person.client.schema("private").from(table).select("*")).error,
      );
      assert.ok((await person.client.from(table).select("*")).error);
    }
    assert.ok(
      (
        await person.client
          .schema("private")
          .rpc("group_is_public", { p_group_id: id })
      ).error,
    );
  }

  // All filters are combined by the server. '%' '_' and '\\' are literal text.
  for (const p_search of ["100%_\\", "GARDEN", "more PURPOSE"])
    assert.equal(
      (
        await list({
          p_search,
          p_group_kind: "informal",
          p_volunteering_focus: true,
          p_locality: "TRENTO",
        })
      ).filter((row) => row.group_id === id).length,
      1,
    );
  assert.deepEqual(
    await list({ p_search: run, p_group_kind: "organization" }),
    [],
  );
  assert.deepEqual(
    await list({ p_search: "no-such-group-" + randomUUID() }),
    [],
  );
  for (const args of [
    { p_group_kind: "verified_ets" },
    { p_group_kind: "" },
    { p_before_id: id },
    { p_before_created_at: publicRows[0].created_at },
    { p_before_id: id, p_before_created_at: "infinity" },
    { p_limit: 0 },
    { p_limit: 51 },
    { p_limit: null },
    { p_search: "x".repeat(121) },
    { p_locality: " Trento" },
    { p_locality: "Trento\t" },
  ])
    await denied(guest, "list_public_groups", args, "22023");
  await denied(
    guest,
    "list_public_groups",
    { p_before_id: "malformed", p_before_created_at: publicRows[0].created_at },
    "22P02",
  );
  await denied(
    guest,
    "list_public_groups",
    { p_verified_ets: true },
    "PGRST202",
  );
  const tied = [id];
  for (let index = 0; index < 4; index++) {
    const next = await create(
      owner,
      content(`Pagination ${run} ${index}`, {
        group_kind: index % 2 ? "organization" : "informal",
        volunteering_focus: index % 2 === 0,
      }),
    );
    await state(owner, next, "published", 1);
    tied.push(next);
  }
  // Trusted synthetic fixtures make the immutable sort key exactly equal.
  await sql.begin(async (transaction) => {
    await transaction`alter table private.community_groups disable trigger community_group_identity_immutable`;
    await transaction`update private.community_groups set created_at='2026-01-01T00:00:00Z' where id=any(${tied}::uuid[])`;
    await transaction`alter table private.community_groups enable trigger community_group_identity_immutable`;
  });
  let cursor = {};
  const visited = [];
  for (let pageNumber = 0; pageNumber < 5; pageNumber++) {
    const rows = await list({ p_search: run, p_limit: 2, ...cursor });
    if (rows.length === 0) break;
    visited.push(...rows.map((row) => row.group_id));
    const last = rows.at(-1);
    cursor = {
      p_before_created_at: last.created_at,
      p_before_id: last.group_id,
    };
  }
  assert.deepEqual(
    visited,
    [...tied].sort().reverse(),
    "Tied keyset visits every unique ID once and terminates.",
  );
  const ownIds = (
    await rpc(owner, "list_own_groups", { ...expected(owner), p_limit: 50 })
  ).map((row) => row.group_id);
  assert.ok(tied.every((candidate) => ownIds.includes(candidate)));
  assert.ok(!ownIds.includes(separateId));
  await denied(
    owner,
    "list_own_groups",
    { ...expected(owner), p_before_id: id },
    "22023",
  );
  const ownFirstPage = await rpc(owner, "list_own_groups", {
    ...expected(owner),
    p_limit: 2,
  });
  const ownLast = ownFirstPage.at(-1);
  const ownNextPage = await rpc(owner, "list_own_groups", {
    ...expected(owner),
    p_limit: 50,
    p_before_created_at: ownLast.created_at,
    p_before_id: ownLast.group_id,
  });
  assert.deepEqual(
    [...ownFirstPage, ...ownNextPage].map((row) => row.group_id),
    visited,
  );

  const reportArgs = {
    p_expected_reporter_profile_id: other.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "Fictional group report with private free text.",
    p_target_kind: "group",
    p_target_id: id,
  };
  const reports = await Promise.all(
    Array.from({ length: 8 }, () =>
      rpc(other, "submit_moderation_report", reportArgs),
    ),
  );
  assert.ok(
    reports.every(
      (report) => JSON.stringify(report) === JSON.stringify(reports[0]),
    ),
  );
  const caseId = reports[0][0].case_id;
  assert.equal(
    (await own(owner, id)).directory_suppressed,
    false,
    "Reporting never automatically hides a group.",
  );
  await denied(
    other,
    "submit_moderation_report",
    { ...reportArgs, p_explanation: "Changed report explanation" },
    "22023",
  );
  await denied(
    other,
    "submit_moderation_report",
    {
      ...reportArgs,
      p_client_submission_id: randomUUID(),
      p_context_kind: "project",
      p_context_id: randomUUID(),
    },
    "22023",
  );
  await denied(
    owner,
    "submit_moderation_report",
    {
      ...reportArgs,
      p_expected_reporter_profile_id: owner.id,
      p_client_submission_id: randomUUID(),
    },
    "22023",
  );
  assert.ok(
    (
      await rpc(other, "list_own_moderation_reports", {
        p_expected_reporter_profile_id: other.id,
      })
    ).some((row) => row.target_kind === "group"),
  );
  assert.deepEqual(
    await rpc(owner, "list_own_moderation_reports", {
      p_expected_reporter_profile_id: owner.id,
    }),
    [],
  );
  for (const person of [owner, other, inactive]) {
    await denied(person, "get_group_staff_context", staffArgs(person, id));
    await denied(person, "get_moderation_case_group", {
      p_expected_staff_profile_id: person.id,
      p_case_id: caseId,
    });
    await denied(person, "set_group_directory_suppression", {
      ...staffArgs(person, id),
      p_client_request_id: randomUUID(),
      p_expected_version: 3,
      p_directory_suppressed: false,
      p_reason: "Fictional private review reason.",
    });
  }
  const caseContext = await rpc(staff, "get_moderation_case_group", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: caseId,
  });
  assert.equal(caseContext.manager_profile_id, owner.id);
  assert.equal(caseContext.report_version, 3);
  const detail = (
    await rpc(staff, "get_moderation_case_detail", {
      p_expected_staff_profile_id: staff.id,
      p_case_id: caseId,
    })
  )[0];
  assert.equal(detail.subject_profile_id, owner.id);
  assert.equal(detail.target_kind, "group");
  for (const field of [
    "project_context_id",
    "resource_listing_context_id",
    "resource_request_context_id",
    "resource_chat_context_id",
  ])
    assert.equal(detail[field], null);
  assert.equal(
    (
      await sql`select count(*)::int as n from private.moderation_evidence_requests where case_id=${caseId}::uuid`
    )[0].n,
    0,
  );
  const hideKey = randomUUID();
  assert.equal(await suppress(staff, id, 3, true, hideKey), 4);
  assert.equal(await suppress(staff, id, 3, true, hideKey), 4);
  assert.deepEqual(await publicDetail(id), []);
  assert.deepEqual(
    await rpc(other, "submit_moderation_report", reportArgs),
    reports[0],
    "Lost report response recovers after hiding.",
  );
  await denied(other, "submit_moderation_report", {
    ...reportArgs,
    p_client_submission_id: randomUUID(),
  });
  const hiddenEdit = { ...edited, name: `Edited hidden ${run}` };
  assert.equal(await edit(owner, id, 4, hiddenEdit), 5);
  assert.equal(await state(owner, id, "draft", 5), 6);
  assert.equal(await state(owner, id, "published", 6), 7);
  assert.deepEqual(
    await publicDetail(id),
    [],
    "Owner publish never clears staff suppression.",
  );
  assert.equal(await state(owner, id, "archived", 7), 8);
  assert.equal(await suppress(staff, id, 8, false), 9);
  assert.deepEqual(
    await publicDetail(id),
    [],
    "Staff restore does not publish an archived page.",
  );
  await denied(
    owner,
    "set_group_publication_state",
    {
      ...groupArgs(owner, id),
      p_client_request_id: randomUUID(),
      p_expected_version: 9,
      p_publication_state: "published",
    },
    "55000",
  );
  await denied(
    owner,
    "update_group",
    {
      ...groupArgs(owner, id),
      p_client_request_id: randomUUID(),
      p_expected_version: 9,
      p_content: page,
    },
    "55000",
  );
  assert.equal(await state(owner, id, "draft", 9), 10);
  assert.equal(await state(owner, id, "published", 10), 11);
  const beforeNoop = (
    await sql`select count(*)::int as n from private.audit_events where target_id=${id}::uuid`
  )[0].n;
  assert.equal(await state(owner, id, "published", 11), 11);
  assert.equal(await state(owner, id, "published", 1, publishKey), 2);
  assert.equal(
    (await own(owner, id)).version,
    11,
    "Old receipts never replay mutations over current state.",
  );
  assert.equal(
    (
      await sql`select count(*)::int as n from private.audit_events where target_id=${id}::uuid`
    )[0].n,
    beforeNoop,
  );
  await sql`update public.profiles set display_name=null where id=${owner.id}::uuid`;
  assert.deepEqual(
    await publicDetail(id),
    [],
    "Loss of current canonical profile completion removes public eligibility.",
  );
  await denied(owner, "get_own_group", groupArgs(owner, id), "55000");
  await sql`update public.profiles set display_name='Fictional owner' where id=${owner.id}::uuid`;
  assert.equal((await publicDetail(id)).length, 1);

  const orphan = await user("orphan");
  const orphanId = await create(orphan);
  await state(orphan, orphanId, "published", 1);
  await sql`delete from public.profiles where id=${orphan.id}::uuid`;
  await sql`delete from auth.users where id=${orphan.id}::uuid`;
  assert.deepEqual(await publicDetail(orphanId), []);
  await denied(orphan, "get_own_group", groupArgs(orphan, orphanId), "55000");
  const [orphanRow] =
    await sql`select g.original_actor_id,m.profile_id from private.community_groups g join private.community_group_managers m on m.group_id=g.id where g.id=${orphanId}::uuid`;
  assert.equal(orphanRow.original_actor_id, orphan.id);
  assert.equal(orphanRow.profile_id, null);
  const sparse = await create(owner, content("", { description: "" }));
  const raceId = await create(owner, content("Concurrent edit fixture"));
  const competing = await Promise.all(
    ["One", "Two"].map((name) =>
      owner.client.rpc("update_group", {
        ...groupArgs(owner, raceId),
        p_client_request_id: randomUUID(),
        p_expected_version: 1,
        p_content: content(`Concurrent edit ${name}`),
      }),
    ),
  );
  assert.deepEqual(
    competing.map((result) => result.error?.code ?? "accepted").sort(),
    ["PT409", "accepted"].sort(),
  );
  assert.equal(
    (await own(owner, raceId)).version,
    2,
    "Only one competing device edit commits.",
  );
  await denied(
    owner,
    "set_group_publication_state",
    {
      ...groupArgs(owner, sparse),
      p_client_request_id: randomUUID(),
      p_expected_version: 1,
      p_publication_state: "published",
    },
    "22023",
  );
  assert.deepEqual(await publicDetail(sparse), []);
  assert.deepEqual(await publicDetail(randomUUID()), []);
  const [{ leaked }] =
    await sql`select count(*)::int as leaked from private.audit_events where target_type='community_group' and (metadata ?| array['name','description','reason','url','explanation'])`;
  assert.equal(leaked, 0);
  const official = await rpc(guest, "list_public_proposal_templates_v2", {
    p_limit: 50,
  });
  assert.equal(
    official.filter(
      (row) =>
        row.is_official &&
        row.creator_display_name === "Planets Community Official",
    ).length,
    8,
  );
  assert.deepEqual(await list({ p_search: "Planets Community Official" }), []);
  console.log(
    "GRP01 HTTP/Auth passed: 12-way creation, receipts, identity/grant denials, stale edits, literal combined filters, tied keysets, 8-way reports, staff/owner lifecycle isolation, orphan deletion and official provenance.",
  );
}
try {
  if (process.argv.includes("--upgrade")) await upgrade();
  else await verify();
} finally {
  await sql.end();
}
