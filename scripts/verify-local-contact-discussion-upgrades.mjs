import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  mkdtemp,
  readdir,
  readFile,
  realpath,
  rename,
  writeFile,
} from "node:fs/promises";
import { createRequire } from "node:module";
import { arch, tmpdir } from "node:os";
import path from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Exact independent published histories, not timestamp cutoffs through a merged
// tree. This resets ONLY the selected disposable loopback database, serially.
const lanes = {
  C: {
    head: "89292af4b084dc2bbd9748797227531b13abe8cc",
    scripts: [
      "group-discussions",
      "group-discussion-links",
      "group-ideas",
      "group-discussion-conversion",
    ],
  },
  D: {
    head: "9ea6ca3fa332ead763f98f5d19c7a7d63872748b",
    scripts: ["group-contact", "group-coordination", "member-contact"],
  },
};
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "Combined upgrades require an explicitly disposable stack.",
);
const root = await realpath(process.cwd());
const migrationRoot = await realpath(path.join(root, "supabase/migrations"));
if (process.env.CI !== "true") {
  const config = await readFile(
    path.join(root, "supabase/config.toml"),
    "utf8",
  );
  const project = config.match(/^project_id\s*=\s*"([^"]+)"/m)?.[1];
  assert.ok(
    project && project !== "planets-community",
    "Use an isolated disposable project, never the repository's default stack.",
  );
  assert.equal(
    process.env.PLANETS_UPGRADE_QA_PROJECT,
    project,
    "Set PLANETS_UPGRADE_QA_PROJECT to the exact owned disposable config project before reset.",
  );
}
const status = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
    "Combined upgrades require loopback endpoints.",
  );
}
const files = (await readdir(migrationRoot))
  .filter((name) => name.endsWith(".sql"))
  .sort();
const require = createRequire(import.meta.url);
const platform = process.platform === "win32" ? "windows" : process.platform;
const cli = path.join(
  path.dirname(
    require.resolve(`@supabase/cli-${platform}-${arch()}/package.json`),
  ),
  "bin",
  `supabase${process.platform === "win32" ? ".exe" : ""}`,
);
const redact = (value) =>
  value
    .replace(/postgres(?:ql)?:\/\/[^\s]+/g, "postgresql://[redacted]")
    .replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, "[redacted-token]");
function run(binary, args, operation, timeout = 600000) {
  const result = spawnSync(binary, args, {
    cwd: root,
    encoding: "utf8",
    shell: false,
    maxBuffer: 32 * 1024 * 1024,
    timeout,
  });
  assert.equal(
    result.status,
    0,
    `${operation} failed (${result.error?.code ?? result.status}): ${redact(result.stderr || result.stdout || "").slice(-600)}`,
  );
  return result.stdout;
}
const command = (args) =>
  run(cli, args, `Combined upgrade CLI ${args[0]} ${args[1]}`);
const fixture = (name) => {
  const output = run(
    process.execPath,
    [`scripts/verify-local-${name}.mjs`],
    `Combined upgrade fixture ${name}`,
  );
  const summary = output.trim().split(/\r?\n/).at(-1);
  console.log(`${name}: ${redact(summary ?? "completed")}`);
};
const connect = () =>
  postgres(status.databaseUrl, { max: 2, onnotice: () => {} });
const signatures = [
  "private.close_pending_direct_requests_for_user_block(uuid,uuid)",
  "private.member_contact_previous_block_convergence(uuid,uuid)",
  "public.process_notification_outbox_batch(integer)",
  "public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)",
  "public.get_moderation_case_detail(uuid,uuid)",
];
// The driver serializes JSONB once. Pre-encoded JSON becomes a scalar string.
const identities = (
  sql,
) => sql`select p.oid, p.oid::regprocedure::text signature, p.proacl::text acl, pg_get_function_result(p.oid) result_shape
  from pg_proc p where p.oid in (select to_regprocedure(value) from jsonb_array_elements_text(${sql.json(signatures)}) a(value)) order by p.oid`;
async function snapshot(sql) {
  const tables =
    await sql`select table_schema||'.'||table_name name,array_agg(column_name order by ordinal_position) columns
    from information_schema.columns where table_schema in ('public','private') and table_name in
    (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r')
    group by table_schema,table_name order by 1`;
  const values = [];
  for (const table of tables)
    values.push({ ...table, ...(await tableSnapshot(sql, table)) });
  return values;
}
async function tableSnapshot(sql, table) {
  const [{ rows }] =
    await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) rows
    from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
  return {
    count: rows.length,
    hash: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
  };
}
async function resetToLane(lane) {
  const tracked = run(
    "git",
    ["ls-tree", "-r", "--name-only", lane.head, "--", "supabase/migrations"],
    "Read immutable lane migration inventory",
  )
    .trim()
    .split(/\r?\n/)
    .map((name) => path.basename(name));
  assert.ok(
    tracked.length > 96 && tracked.every((name) => files.includes(name)),
    "Lane history is absent from the combined tree.",
  );
  for (const name of tracked) {
    const source = run(
      "git",
      ["show", `${lane.head}:supabase/migrations/${name}`],
      "Read immutable migration",
    ).replace(/\r\n/g, "\n");
    assert.equal(
      (await readFile(path.join(migrationRoot, name), "utf8")).replace(
        /\r\n/g,
        "\n",
      ),
      source,
      `Published migration must remain unchanged: ${name}`,
    );
  }
  const backup = await realpath(
    await mkdtemp(path.join(tmpdir(), "planets-cd-migration-set-")),
  );
  const excluded = files.filter((name) => !tracked.includes(name));
  // A crash leaves this manifest and only original SQL files in OS temporary
  // storage. Restore them to this exact migrationRoot before another command.
  const manifest = path.join(backup, "restore.json");
  await writeFile(
    manifest,
    JSON.stringify({ migrationRoot, head: lane.head, excluded }, null, 2),
  );
  const moved = [];
  try {
    for (const name of excluded) {
      assert.match(name, /^\d{14}_[a-z0-9_]+\.sql$/);
      const from = path.resolve(migrationRoot, name),
        to = path.resolve(backup, name);
      assert.equal(path.dirname(from), migrationRoot);
      assert.equal(path.dirname(to), backup);
      await rename(from, to);
      moved.push(name);
    }
    command(["db", "reset", "--db-url", status.databaseUrl, "--yes"]);
  } finally {
    for (const name of moved)
      await rename(path.join(backup, name), path.join(migrationRoot, name));
  }
  // Retain a tiny manifest for traceability; never recursively remove paths.
  console.log(
    `Replayed ${tracked.length} exact lane migrations; restored all combined files. Recovery manifest: ${manifest}`,
  );
}
async function mixedChecks(sql) {
  const targets = [
    "target_profile_id",
    "target_project_id",
    "target_project_chat_message_id",
    "target_resource_listing_id",
    "target_resource_request_id",
    "target_resource_chat_message_id",
    "target_proposal_template_id",
    "target_group_id",
    "target_group_contact_request_id",
    "target_group_contact_message_id",
    "target_group_coordination_id",
    "target_member_contact_request_id",
    "target_member_contact_message_id",
    "target_group_discussion_message_id",
  ];
  const contexts = [
    "project_context_id",
    "resource_listing_context_id",
    "resource_request_context_id",
    "resource_chat_context_id",
    "group_contact_context_id",
    "member_contact_context_id",
  ];
  const cases =
    await sql`select to_jsonb(c) row from private.moderation_cases c`;
  for (const { row } of cases) {
    assert.equal(
      targets.filter((key) => row[key] != null).length,
      1,
      "Every mixed case retains exactly one typed target.",
    );
    assert.ok(
      contexts.filter((key) => row[key] != null).length <= 1,
      "Contexts are separate from typed targets.",
    );
    if (row.target_kind === "group_discussion_message") {
      assert.ok(row.group_discussion_evidence && row.subject_profile_id);
      assert.equal(contexts.filter((key) => row[key] != null).length, 0);
    }
  }
  const kinds = [
    "group_discussion_message",
    "group_contact_request",
    "group_contact_message",
    "group_coordination_proposal",
    "member_contact_request",
    "member_contact_message",
  ];
  for (const kind of kinds)
    assert.ok(
      cases.some(({ row }) => row.target_kind === kind),
      `Populated mixed coverage requires ${kind}.`,
    );
  const checks =
    await sql`select conname,pg_get_expr(conbin,conrelid) expression from pg_constraint where conrelid='private.moderation_cases'::regclass and conname in
    ('moderation_cases_target_kind_valid','moderation_cases_one_typed_target','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid','moderation_cases_discussion_shape','moderation_cases_template_provenance_valid')`;
  assert.equal(
    checks.length,
    6,
    "All effective mixed target/context/provenance checks exist.",
  );
  async function allows(row) {
    for (const check of checks) {
      const [{ allowed }] = await sql.unsafe(
        `select (${check.expression}) is not false allowed from jsonb_populate_record(null::private.moderation_cases,$1::jsonb) c`,
        [row],
      );
      if (!allowed) return false;
    }
    return true;
  }
  const c = cases.find(
    ({ row }) => row.target_kind === "group_discussion_message",
  ).row;
  const d = cases.find(
    ({ row }) => row.target_kind === "group_contact_message",
  ).row;
  const m = cases.find(
    ({ row }) => row.target_kind === "member_contact_message",
  ).row;
  assert.equal(await allows(c), true);
  assert.equal(await allows(d), true);
  assert.equal(await allows(m), true);
  assert.equal(
    await allows({ ...c, subject_profile_id: null }),
    false,
    "The erased-subject exception never extends to C reports.",
  );
  assert.equal(
    await allows({ ...d, group_contact_context_id: null }),
    false,
    "Representative message context remains required.",
  );
  assert.equal(
    await allows({
      ...c,
      target_group_contact_message_id: d.target_group_contact_message_id,
    }),
    false,
    "C plus D target rejected.",
  );
  assert.equal(
    await allows({
      ...d,
      member_contact_context_id: m.member_contact_context_id,
    }),
    false,
    "Cross-family contexts rejected.",
  );
  assert.equal(
    await allows({ ...m, member_contact_context_id: null }),
    false,
    "Member message context remains required.",
  );
  const reports =
    await sql`select distinct on (c.target_kind) c.target_kind,r.*,u.email,c.target_group_discussion_message_id
    from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id join auth.users u on u.id=r.reporter_profile_id
    join public.profiles reporter on reporter.id=u.id
    where c.target_kind in ${sql(kinds)} and u.email like '%@planets.invalid'
      and u.deleted_at is null and (u.banned_until is null or u.banned_until<=clock_timestamp())
    order by c.target_kind,r.created_at desc`;
  assert.equal(
    reports.length,
    kinds.length,
    "Every family has a genuine active synthetic reporter.",
  );
  const [before] =
    await sql`select count(*) count from private.moderation_reports`;
  // Several target kinds can share a reporter. Reuse its genuine session rather
  // than request back-to-back OTPs against the configured one-second interval.
  const sessions = new Map();
  for (const report of reports) {
    assert.match(report.email, /^[a-z0-9-]+@planets\.invalid$/);
    let actor = sessions.get(report.email);
    if (!actor) {
      actor = await signInLocalOtpUser({
        ...status,
        mailpitUrl,
        email: report.email,
        verifierName: "C/D populated upgrade",
        shouldCreateUser: false,
      });
      sessions.set(report.email, actor);
    }
    assert.equal(actor.id, report.reporter_profile_id);
    try {
      const call = async (name, args = {}) => {
        const result = await actor.client.rpc(name, {
          p_expected_profile_id: actor.id,
          ...args,
        });
        assert.equal(
          result.error?.code ?? null,
          null,
          `${name} failed (${result.error?.code}).`,
        );
        return result.data;
      };
      const base = await call("get_own_message_unread_summary"),
        contacts = await call("get_own_message_unread_summary_v3"),
        discussions = await call(
          "get_own_message_unread_summary_with_discussions",
        ),
        combined = await call(
          "get_own_message_unread_summary_with_contacts_and_discussions",
        );
      for (const bucket of ["total", "private", "groups"])
        assert.equal(
          combined[bucket],
          contacts[bucket] + discussions[bucket] - base[bucket],
          `Combined ${bucket} counts shared legacy once.`,
        );
      const own = await actor.client.rpc("list_own_moderation_reports_v4", {
        p_expected_reporter_profile_id: actor.id,
        p_limit: 20,
        p_before_created_at: null,
        p_before_report_id: null,
      });
      assert.equal(own.error?.code ?? null, null);
      assert.ok(
        own.data.some(
          (row) =>
            row.report_id === report.id &&
            row.target_kind === report.target_kind &&
            row.target_summary,
        ),
        "Own v4 retains typed evidence labels.",
      );
      const reuse =
        report.target_kind === "group_discussion_message"
          ? await actor.client.rpc("submit_moderation_report", {
              p_expected_reporter_profile_id: actor.id,
              p_client_submission_id: report.client_submission_id,
              p_category: report.category,
              p_explanation: report.explanation,
              p_target_kind: "group_contact_message",
              p_target_id: d.target_group_contact_message_id,
            })
          : await actor.client.rpc("submit_group_discussion_report", {
              p_expected_reporter_profile_id: actor.id,
              p_client_submission_id: report.client_submission_id,
              p_category: report.category,
              p_explanation: report.explanation,
              p_message_id: c.target_group_discussion_message_id,
            });
      assert.ok(
        ["22023", "PT409"].includes(reuse.error?.code),
        `Cross-family key reuse must reject intent (${report.target_kind}).`,
      );
      const wrongActor = await actor.client.rpc(
        "get_own_message_unread_summary_with_contacts_and_discussions",
        { p_expected_profile_id: randomUUID() },
      );
      assert.equal(wrongActor.error?.code, "42501");
    } finally {
      await actor.client.removeAllChannels();
    }
  }
  const [after] =
    await sql`select count(*) count from private.moderation_reports`;
  assert.equal(
    after.count,
    before.count,
    "Rejected reused keys create no report or case receipt.",
  );
  console.log(
    `Mixed C/D/M: ${cases.length} exact typed cases, all six new kinds, cross-family rejection, genuine own labels and combined unread/auth parity passed.`,
  );
}

for (const [name, lane] of Object.entries(lanes)) {
  await resetToLane(lane);
  run(
    process.execPath,
    ["scripts/seed-local-demo-world.mjs"],
    "Seed deterministic predecessor",
  );
  for (const script of lane.scripts) fixture(script);
  let sql = connect();
  const before = await snapshot(sql),
    functions = await identities(sql);
  assert.ok(
    before.find((table) => table.name === "private.moderation_reports")?.count >
      0,
  );
  await sql.end();
  command(["migration", "up", "--db-url", status.databaseUrl, "--include-all"]);
  command(["migration", "up", "--db-url", status.databaseUrl, "--include-all"]);
  sql = connect();
  try {
    for (const table of before)
      assert.deepEqual(
        await tableSnapshot(sql, table),
        { count: table.count, hash: table.hash },
        `${name}-first preserves ${table.name}.`,
      );
    const afterFunctions = await identities(sql);
    for (const old of functions)
      assert.deepEqual(
        afterFunctions.find((item) => item.signature === old.signature),
        old,
        `${name}-first preserves ${old.signature} identity/ACL/shape.`,
      );
    const [{ count }] =
      await sql`select count(*)::int count from supabase_migrations.schema_migrations`;
    assert.equal(
      count,
      files.length,
      "All sorted/interleaved combined migrations are installed.",
    );
    console.log(
      `${name}-first: ${before.length} populated table/column snapshots and ${functions.length} warmed function identities/ACLs preserved; repeat application harmless.`,
    );
    await sql`notify pgrst,'reload schema'`;
  } finally {
    await sql.end();
  }
  const other = name === "C" ? lanes.D : lanes.C;
  for (const script of other.scripts) fixture(script);
  sql = connect();
  try {
    await mixedChecks(sql);
  } finally {
    await sql.end();
  }
}
console.log(
  "Both exact populated C→D and D→C histories passed. A separate sorted clean replay/test gate remains required.",
);
