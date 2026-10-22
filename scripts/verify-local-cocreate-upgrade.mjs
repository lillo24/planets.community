import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  mkdir,
  readFile,
  readdir,
  realpath,
  writeFile,
} from "node:fs/promises";
import { createRequire } from "node:module";
import { arch } from "node:os";
import path from "node:path";
import postgres from "postgres";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Actual immutable parent of A00, including its precise backdated inventory.
// Materialize separately: never rename/remove the working migration directory.
const base = "675bc5929c79332d1f4dcaf3446780c3020ef214";
const root = await realpath(process.cwd());
const config = await readFile(path.join(root, "supabase/config.toml"), "utf8");
const project = config.match(/^project_id\s*=\s*"([^"]+)"/m)?.[1];
assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit disposable reset opt-in required",
);
assert.ok(
  project && project !== "planets-community",
  "Never reset the default project",
);
assert.equal(
  process.env.PLANETS_UPGRADE_QA_PROJECT,
  project,
  "Exact disposable project opt-in required",
);
const opened = openCocreateLocalBackend(),
  status = opened.status;
await opened.sql.end();
const require = createRequire(import.meta.url);
const platform = process.platform === "win32" ? "windows" : process.platform;
const cli = path.join(
  path.dirname(
    require.resolve(`@supabase/cli-${platform}-${arch()}/package.json`),
  ),
  "bin",
  `supabase${process.platform === "win32" ? ".exe" : ""}`,
);
const redact = (s) =>
  s
    .replace(/postgres(?:ql)?:\/\/[^\s]+/g, "postgresql://[redacted]")
    .replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, "[redacted-token]");
function run(binary, args, cwd = root) {
  const r = spawnSync(binary, args, {
    cwd,
    encoding: "utf8",
    shell: false,
    timeout: 600000,
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(
    r.status,
    0,
    `${binary === cli ? "Local migration operation" : binary} failed: ${redact(r.stderr || r.stdout || String(r.error)).slice(-1800)}`,
  );
  return r.stdout;
}
const sha = (s) => createHash("sha256").update(s).digest("hex");
const target = path.join(root, ".local", `cocreate-upgrade-${randomUUID()}`);
await mkdir(path.join(target, "supabase/migrations"), { recursive: true });
const files = run("git", [
  "ls-tree",
  "-r",
  "--name-only",
  base,
  "--",
  "supabase/migrations",
])
  .trim()
  .split(/\r?\n/);
assert.ok(
  files.length === 123 &&
    files.every((f) => /^supabase\/migrations\/\d{14}_[\w-]+\.sql$/.test(f)),
  "Exact base inventory required",
);
const inventory = [];
for (const file of files) {
  const bytes = run("git", ["show", `${base}:${file}`]);
  assert.equal(
    (await readFile(path.join(root, file), "utf8")).replace(/\r\n/g, "\n"),
    bytes.replace(/\r\n/g, "\n"),
    `Published base migration must be unchanged: ${file}`,
  );
  await writeFile(path.join(target, file), bytes);
  inventory.push({ file, sha256: sha(bytes) });
}
const baseConfig = run("git", ["show", `${base}:supabase/config.toml`]);
const overlay = baseConfig
  .replace(/^project_id\s*=\s*"[^"]+"/m, `project_id = "${project}"`)
  .replace(
    /(\[api\][\s\S]*?\nport\s*=\s*)\d+/,
    (_, prefix) => prefix + new URL(status.apiUrl).port,
  );
await writeFile(path.join(target, "supabase/config.toml"), overlay);
await writeFile(
  path.join(target, "supabase/seed.sql"),
  run("git", ["show", `${base}:supabase/seed.sql`]),
);
for (const file of run("git", [
  "ls-tree",
  "-r",
  "--name-only",
  base,
  "--",
  "supabase/templates",
])
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)) {
  assert.match(file, /^supabase\/templates\/[\w.-]+\.html$/);
  await mkdir(path.dirname(path.join(target, file)), { recursive: true });
  await writeFile(
    path.join(target, file),
    run("git", ["show", `${base}:${file}`]),
  );
}
const manifest = {
  base,
  project,
  apiPort: new URL(status.apiUrl).port,
  databasePort: new URL(status.databaseUrl).port,
  inventory,
  baseConfigSha256: sha(baseConfig),
  overlaySha256: sha(overlay),
  state: "before-reset",
  note: "Only project ID/API port overlaid; exact Git migration bytes. Synthetic fixtures only. No hosted target.",
};
const save = async (state) => {
  manifest.state = state;
  await writeFile(
    path.join(target, "manifest.json"),
    JSON.stringify(manifest, null, 2) + "\n",
  );
};
await save("resetting-exact-base");
console.log(
  `Q00 actual-base upgrade: ${files.length} immutable migrations; checkpoint ${target}`,
);
run(cli, [
  "--workdir",
  target,
  "db",
  "reset",
  "--db-url",
  status.databaseUrl,
  "--yes",
]);
let sql = postgres(status.databaseUrl, { max: 3, onnotice: () => {} });
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
async function rpc(u, name, args) {
  const r = await u.client.rpc(name, args);
  equal(
    r.error?.code ?? null,
    null,
    `${name}: ${r.error?.message ?? "succeeds"}`,
  );
  return r.data;
}
try {
  await sql`notify pgrst,'reload schema'`;
  const tag = randomUUID().slice(0, 8);
  const u = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: `cocreate-base-${tag}@planets.invalid`,
    verifierName: "cocreate-upgrade",
  });
  await sql`insert into public.profiles(id,display_name) values(${u.id}::uuid,${"Synthetic base owner " + tag})`;
  await rpc(u, "accept_policy_bundle", {
    p_expected_account_id: u.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  const proposal = await rpc(u, "create_editor_proposal_draft", {
    p_expected_creator_profile_id: u.id,
    p_client_request_id: randomUUID(),
    p_title: "Synthetic pre-programme Project",
    p_summary: "",
    p_description: "Private native content preserved",
    p_starts_at: null,
    p_ends_at: null,
    p_event_timezone: "Europe/Rome",
    p_country_code: "",
    p_locality: "",
    p_administrative_area: "",
    p_public_location_label: "",
    p_exact_meeting_text: "Private meeting preserved",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: null,
    p_count_organizers_toward_capacity: false,
  });
  const registered = await rpc(u, "create_group_draft", {
    p_expected_profile_id: u.id,
    p_client_request_id: randomUUID(),
    p_content: {
      name: "Synthetic pre-programme registered Group",
      description: "Private group draft",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  const tavolo = await rpc(u, "create_recurring_activity_draft", {
    p_expected_creator_profile_id: u.id,
    p_title: "Synthetic pre-programme Tavolo",
    p_summary: null,
    p_description: null,
    p_topic: null,
    p_country_code: null,
    p_locality: null,
    p_administrative_area: null,
    p_public_location_label: null,
    p_exact_meeting_text: "Private native Tavolo",
    p_exact_location_visibility: "participants",
    p_recurrence_type: null,
    p_weekday: null,
    p_day_of_month: null,
    p_local_start_time: null,
    p_duration_minutes: null,
    p_event_timezone: null,
    p_effective_from: null,
    p_people_capacity: 20,
  });
  const resource = await rpc(u, "create_resource_listing_draft", {
    p_expected_owner_profile_id: u.id,
    p_listing_mode: "donate",
    p_title: "Synthetic pre-programme Resource",
    p_description: "Private listing draft",
    p_country_code: null,
    p_locality: null,
    p_administrative_area: null,
    p_public_location_label: null,
  });
  const tables =
    await sql`select table_schema||'.'||table_name name,array_agg(column_name order by ordinal_position) columns from information_schema.columns where table_schema in ('public','private') and table_name in(select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') group by table_schema,table_name order by 1`;
  const snapshot = async (table) =>
    (
      await sql`select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]'::jsonb) rows from (select ${sql(table.columns)} from ${sql(table.name)}) r`
    )[0].rows;
  for (const table of tables) table.rows = await snapshot(table);
  const signatures = [
    "public.block_user(uuid,uuid)",
    "public.create_editor_proposal_draft(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[],integer,boolean)",
    "public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)",
  ];
  const identities = () =>
    sql`select p.oid,p.oid::regprocedure::text signature,p.proacl::text acl,pg_get_function_result(p.oid) result_shape from pg_proc p where p.oid in(select to_regprocedure(value) from jsonb_array_elements_text(${sql.json(signatures)}) a(value)) order by p.oid`;
  const before = await identities();
  equal(before.length, 3, "Critical native identities exist at actual base");
  manifest.snapshot = tables.map((t) => ({
    name: t.name,
    columns: t.columns,
    count: t.rows.length,
    sha256: sha(JSON.stringify(t.rows)),
  }));
  await save("populated-base-before-upgrade");
  await sql.end();
  run(cli, [
    "migration",
    "up",
    "--db-url",
    status.databaseUrl,
    "--include-all",
    "--yes",
  ]);
  sql = postgres(status.databaseUrl, { max: 3, onnotice: () => {} });
  for (const table of tables)
    equal(
      await snapshot(table),
      table.rows,
      `Native common-column rows preserved: ${table.name}`,
    );
  equal(
    await identities(),
    before,
    "Native OID/ACL/result contracts preserved",
  );
  const current = (await readdir(path.join(root, "supabase/migrations")))
    .filter((f) => f.endsWith(".sql"))
    .map((f) => f.slice(0, 14))
    .sort();
  equal(
    (
      await sql`select version from supabase_migrations.schema_migrations order by version`
    ).map((r) => r.version),
    current,
    "All current migrations, including backdated merged main, applied",
  );
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Experiment defaults OFF on populated upgrade",
  );
  await sql`notify pgrst,'reload schema'`;
  const native = await rpc(u, "get_own_proposal", {
    p_expected_creator_profile_id: u.id,
    p_proposal_id:
      typeof proposal === "string" ? proposal : proposal.proposal_id,
  });
  equal(
    native[0].title,
    "Synthetic pre-programme Project",
    "Native authenticated ownership survives actual-base upgrade",
  );
  for (const [name, args] of [
    ["get_own_group", { p_expected_profile_id: u.id, p_group_id: registered }],
    [
      "get_own_recurring_activity",
      { p_expected_creator_profile_id: u.id, p_recurring_activity_id: tavolo },
    ],
    [
      "get_own_resource_listing",
      { p_expected_owner_profile_id: u.id, p_listing_id: resource },
    ],
  ])
    equal(
      (await rpc(u, name, args)).length,
      1,
      `${name} still authorizes the original native owner with co-creation OFF`,
    );
  manifest.checks = checks;
  await save("native-snapshots-preserved-current-schema");
  console.log(
    `Q00 populated actual-base upgrade passed: ${checks} assertions, ${tables.length} native table snapshots; activation OFF.`,
  );
} finally {
  await sql.end();
}
