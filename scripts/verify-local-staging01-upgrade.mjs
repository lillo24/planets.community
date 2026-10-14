import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  cp,
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  realpath,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// One-time STAGING01 rehearsal. Never connect to hosted data. The recorded
// history contains identifiers and statement hashes only, not tester content.
assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
const root = process.cwd();
const status = readLocalSupabaseStatus(root);
const mailpitUrl = process.env.MAILPIT_URL;
for (const value of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(value, "Explicit local API/database/mailbox required.");
  assert.equal(new URL(value).hostname, "127.0.0.1");
}
assert.notEqual(
  new URL(status.apiUrl).port,
  "54321",
  "Use a separate QA stack.",
);
const workdir = process.env.SUPABASE_WORKDIR;
assert.ok(workdir, "Explicit disposable SUPABASE_WORKDIR required.");
const config = await readFile(
  path.join(workdir, "supabase/config.toml"),
  "utf8",
);
assert.match(config, /project_id\s*=\s*"planets-staging01-qa"/u);
const evidence = path.join(root, "docs/development/evidence/staging01");
const remote = JSON.parse(
  await readFile(
    path.join(evidence, "remote-migration-fingerprints.json"),
    "utf8",
  ),
);
assert.equal(
  remote.length,
  83,
  "Re-inventory if the recorded staging baseline changes.",
);
const files = (await readdir(path.join(root, "supabase/migrations")))
  .filter((f) => f.endsWith(".sql"))
  .sort();
const workdirFiles = (await readdir(path.join(workdir, "supabase/migrations")))
  .filter((f) => f.endsWith(".sql"))
  .sort();
assert.deepEqual(
  workdirFiles,
  files,
  "Disposable workdir must contain the same canonical migration set.",
);
for (const file of files) {
  assert.deepEqual(
    await readFile(path.join(workdir, "supabase/migrations", file)),
    await readFile(path.join(root, "supabase/migrations", file)),
    `Disposable migration bytes differ: ${file}`,
  );
}
const applied = new Set(remote.map((r) => `${r.version}_${r.name}.sql`));
for (const name of applied)
  assert.ok(files.includes(name), `Unknown remote migration ${name}`);
const pending = files.filter((f) => !applied.has(f));
assert.equal(pending.length, 13, "Re-review a changed migration set.");
const manifest = JSON.parse(
  await readFile(path.join(evidence, "pending-migration-sha256.json"), "utf8"),
);
assert.deepEqual(
  manifest.map((row) => row.file),
  pending,
  "Pending file list changed.",
);
for (const row of manifest) {
  const bytes = await readFile(
    path.join(root, "supabase/migrations", row.file),
  );
  assert.equal(
    createHash("sha256").update(bytes).digest("hex"),
    row.sha256,
    `Reviewed migration changed: ${row.file}`,
  );
}
function command(executable, args) {
  const resolvedExecutable =
    executable === "supabase" && process.platform === "win32"
      ? path.join(
          root,
          "node_modules/@supabase/cli-windows-x64/bin/supabase.exe",
        )
      : executable;
  const result = spawnSync(resolvedExecutable, args, {
    cwd: root,
    encoding: "utf8",
    shell: false,
    maxBuffer: 32 * 1024 * 1024,
    timeout: 600000,
  });
  if (result.error || result.status !== 0) {
    // Connection diagnostics and synthetic sessions also stay out of evidence.
    const diagnostic = `${result.stderr ?? ""}\n${result.stdout ?? ""}`
      .split(/\r?\n/u)
      .filter((line) =>
        /error|failed|not found|cannot|invalid|could not/iu.test(line),
      )
      .map((line) =>
        line
          .replace(/(?:postgres(?:ql)?|https?):\/\/\S+/giu, "[connection]")
          .replace(/eyJ[A-Za-z0-9_.-]+/gu, "[token]"),
      )
      .slice(-3)
      .join("; ");
    throw new Error(
      `STAGING01 ${args[0]} failed (${result.status ?? result.error?.code}): ${diagnostic}`,
    );
  }
  return result.stdout;
}
const temp = await mkdtemp(path.join(tmpdir(), "planets-staging01-baseline-"));
let sql;
try {
  await mkdir(path.join(temp, "supabase/migrations"), { recursive: true });
  await writeFile(path.join(temp, "supabase/config.toml"), config);
  await cp(
    path.join(workdir, "supabase/seed.sql"),
    path.join(temp, "supabase/seed.sql"),
  );
  await cp(
    path.join(workdir, "supabase/templates"),
    path.join(temp, "supabase/templates"),
    { recursive: true },
  );
  for (const file of applied)
    await cp(
      path.join(root, "supabase/migrations", file),
      path.join(temp, "supabase/migrations", file),
    );
  // Same task-owned project ID/ports, with exactly the 83 applied files. This
  // does not truncate by timestamp and therefore does not include WORKSPACE02.
  if (!process.argv.includes("--continue-after-replay"))
    command("supabase", ["db", "reset", "--local", "--workdir", temp, "--yes"]);
  sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
  const local =
    await sql`select version,name,cardinality(statements) as statement_count,
    md5(array_to_string(statements,E'\n')) as joined_md5
    from supabase_migrations.schema_migrations order by version`;
  assert.deepEqual(
    local.map((r) => r.version),
    remote.map((r) => r.version),
    "Exact 83-version baseline required, including when continuing a prior replay.",
  );
  const historyComparison = await Promise.all(
    remote.map(async (r) => {
      const l = local.find((item) => item.version === r.version);
      const source = await readFile(
        path.join(root, "supabase/migrations", `${r.version}_${r.name}.sql`),
        "utf8",
      );
      // Two recorded deployments stored the complete SQL file as one statement.
      // Compare exact file bytes after CRLF/terminal-whitespace normalization,
      // never erase internal whitespace or repair hosted history to match CLI.
      const wholeFileMatch =
        r.statement_count === 1 &&
        r.trimmed_file_md5 ===
          createHash("md5")
            .update(source.replaceAll("\r\n", "\n").trim())
            .digest("hex");
      const exactMatch =
        l?.statement_count === r.statement_count &&
        l?.joined_md5 === r.joined_md5;
      return {
        version: r.version,
        name: r.name,
        match_kind: exactMatch
          ? "exact_statement_array"
          : wholeFileMatch
            ? "exact_complete_file"
            : "mismatch",
      };
    }),
  );
  await writeFile(
    path.join(evidence, "history-comparison.json"),
    JSON.stringify(historyComparison, null, 2) + "\n",
  );
  assert.ok(
    historyComparison.every((r) => r.match_kind !== "mismatch"),
    "Stored staging migration statements differ from canonical replay; review before deployment.",
  );
  console.log(
    "STAGING01 exact 83-migration baseline replay and history comparison passed.",
  );
  // Explicitly reproduce the inspected extra hosted RLS event trigger only in
  // this disposable database. It is not a canonical PLANETS migration, and no
  // hosted history or grants are changed. Verify its exact hash/ACL below.
  await sql.unsafe(
    await readFile(path.join(evidence, "hosted-rls-event-trigger.sql"), "utf8"),
  );
  const remoteRoutines = JSON.parse(
    await readFile(
      path.join(evidence, "remote-routine-fingerprints.json"),
      "utf8",
    ),
  );
  const localRoutines =
    await sql`select n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' as signature,
    md5(replace(pg_get_functiondef(p.oid),E'\r\n',E'\n')) as definition_md5,p.proacl::text as grants
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prokind='f' and not exists
    (select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') order by 1`;
  const routineDrift = remoteRoutines
    .filter((r) => {
      const l = localRoutines.find((item) => item.signature === r.signature);
      return (
        !l || l.definition_md5 !== r.definition_md5 || l.grants !== r.grants
      );
    })
    .map((r) => r.signature);
  const absentRemote = localRoutines
    .filter((l) => !remoteRoutines.some((r) => r.signature === l.signature))
    .map((l) => l.signature);
  await writeFile(
    path.join(evidence, "routine-comparison.json"),
    JSON.stringify(
      { compared: remoteRoutines.length, routineDrift, absentRemote },
      null,
      2,
    ) + "\n",
  );
  assert.deepEqual(
    routineDrift,
    [],
    "Hosted baseline routine definitions/grants drifted.",
  );
  assert.deepEqual(absentRemote, [], "Hosted baseline routines are missing.");
  console.log(
    `STAGING01 ${remoteRoutines.length} baseline routine definitions/grants match.`,
  );
  // Existing canonical verifiers supply fictional persistent histories through
  // genuine local OTP/API flows, without relying on newer demo schema columns.
  for (const name of [
    "project-delegates",
    "participant-invitations",
    "persistent-groups",
    "resource-exchange-agreements",
    "template-application",
    "policy-acceptance",
  ]) {
    command(process.execPath, [`scripts/verify-local-${name}.mjs`]);
    console.log(`STAGING01 predecessor fixture: ${name} passed.`);
  }
  const [project] =
    await sql`select id,creator_profile_id from public.proposals order by id limit 1`;
  assert.ok(project);
  await sql`insert into public.project_shared_workspaces(project_id,workspace_url)
    values(${project.id}::uuid,'https://example.org/staging01-preserved')`;
  const tables = await sql`select table_schema||'.'||table_name as name,
    array_agg(column_name order by ordinal_position) as columns from information_schema.columns
    where table_schema in ('public','private') and table_name in
    (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='r')
    group by table_schema,table_name order by 1`;
  async function snapshot(table) {
    const [{ rows }] =
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) as rows
      from (select ${sql(table.columns)} from ${sql(table.name)}) r`;
    return {
      count: rows.length,
      sha256: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  }
  const before = new Map();
  for (const table of tables) before.set(table.name, await snapshot(table));
  for (const name of [
    "public.profiles",
    "public.proposals",
    "public.recurring_activities",
    "public.project_memberships",
    "public.project_chat_messages",
    "public.resource_listings",
    "public.resource_exchange_agreements",
    "public.project_shared_workspaces",
    "private.community_groups",
    "private.moderation_reports",
    "private.proposal_templates",
    "private.policy_acceptances",
  ])
    assert.ok(
      before.get(name)?.count > 0,
      `Missing representative fixture ${name}`,
    );
  // --include-all is required for the older unapplied WORKSPACE02 timestamp.
  command("supabase", [
    "db",
    "push",
    "--local",
    "--skip-vault",
    "--include-all",
    "--dry-run",
  ]);
  command("supabase", ["migration", "up", "--local", "--include-all"]);
  command("supabase", ["migration", "up", "--local", "--include-all"]);
  for (const table of tables)
    assert.deepEqual(
      await snapshot(table),
      before.get(table.name),
      `Changed predecessor content: ${table.name}`,
    );
  const [{ n }] =
    await sql`select count(*)::int as n from public.projects p where
    p.attributed_group_id is not null or p.attribution_version<>0 or
    p.first_published_at is distinct from coalesce(
    (select published_at from public.proposals where id=p.id),
    (select published_at from public.recurring_activities where id=p.id))`;
  assert.equal(n, 0, "Only expected personal publication provenance backfill.");
  const history =
    await sql`select version from supabase_migrations.schema_migrations order by version`;
  assert.deepEqual(
    history.map((r) => r.version),
    files.map((f) => f.split("_")[0]),
  );
  const publicClient = createClient(status.apiUrl, status.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  async function rpc(client, name, args) {
    // CLI completion can precede PostgREST schema-cache notification. Retry
    // only the bounded read-only missing-cache error; all other failures stop.
    for (let attempt = 0; attempt < 50; attempt++) {
      const response = await client.rpc(name, args);
      if (response.error?.code === "PGRST202" && attempt < 49) {
        await new Promise((resolve) => setTimeout(resolve, 200));
        continue;
      }
      assert.equal(
        response.error?.code ?? null,
        null,
        `${name} API error code`,
      );
      return response.data;
    }
  }
  const page = await rpc(publicClient, "list_public_proposals_v2", {
    p_limit: 10,
  });
  assert.ok(page.length > 0, "Public proposal fixture required.");
  assert.deepEqual(
    await rpc(publicClient, "get_public_project_groups", {
      p_project_ids: page.map((p) => p.proposal_id),
    }),
    [],
  );
  assert.deepEqual(
    await rpc(publicClient, "get_public_project_groups", { p_project_ids: [] }),
    [],
  );
  const [reader] =
    await sql`select a.id,a.email from auth.users a join public.projects p on p.creator_profile_id=a.id
    join public.project_group_chats c on c.project_id=p.id
    where exists(select 1 from public.project_chat_messages m where m.chat_id=c.id)
    order by a.id limit 1`;
  assert.ok(reader?.email.endsWith("@planets.invalid"));
  const user = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: reader.email,
    shouldCreateUser: false,
    verifierName: "STAGING01",
  });
  assert.equal(user.id, reader.id);
  const args = { p_expected_profile_id: user.id, p_scope: "all", p_limit: 20 };
  const v4 = await rpc(
    user.client,
    "list_own_scoped_conversation_items_v4",
    args,
  );
  const v5 = await rpc(
    user.client,
    "list_own_scoped_conversation_items_v5",
    args,
  );
  assert.ok(v4.length > 0, "Populated Messages compatibility required.");
  assert.deepEqual(
    v5.map(({ group_cover_object_path, ...rest }) => rest),
    v4,
  );
  assert.ok(
    v5.every((item) => Object.hasOwn(item, "group_cover_object_path")),
    "V5 additive cover field is required.",
  );
  const denied = await publicClient.rpc(
    "list_own_scoped_conversation_items_v5",
    args,
  );
  assert.equal(
    denied.error?.code,
    "42501",
    "Anonymous Messages remains denied.",
  );
  const wrong = await user.client.rpc("list_own_scoped_conversation_items_v5", {
    ...args,
    p_expected_profile_id: "fa000000-0000-4000-8000-000000000001",
  });
  assert.equal(
    wrong.error?.code,
    "42501",
    "Cross-account Messages remains denied.",
  );
  const result = {
    pending,
    preserved_tables: tables.length,
    preserved_rows: [...before.values()].reduce(
      (sum, row) => sum + row.count,
      0,
    ),
    local_history_count: history.length,
    public_proposal_count: page.length,
    public_group_empty_cases: 2,
    v4_v5_compatibility: true,
    populated_message_count: v5.length,
    anonymous_and_cross_account_denied: true,
  };
  await writeFile(
    path.join(evidence, "upgrade-result.json"),
    JSON.stringify(result, null, 2) + "\n",
  );
  console.log(
    `STAGING01 populated upgrade passed: ${tables.length} tables preserved; all ${pending.length} pending migrations applied locally; public and authenticated RPC checks passed.`,
  );
} finally {
  if (sql) await sql.end({ timeout: 5 });
  const resolvedTemp = await realpath(temp);
  assert.ok(
    resolvedTemp
      .toLowerCase()
      .startsWith((await realpath(tmpdir())).toLowerCase() + path.sep),
  );
  assert.ok(
    path.basename(resolvedTemp).startsWith("planets-staging01-baseline-"),
  );
  await rm(temp, { recursive: true, force: true });
}
