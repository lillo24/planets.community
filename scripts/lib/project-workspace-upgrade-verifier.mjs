import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  copyFile,
  cp,
  mkdir,
  mkdtemp,
  readdir,
  realpath,
  rm,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import postgres from "postgres";

const batchMigrations = new Set([
  "20261011132245_project_workspace_named_links.sql",
  "20261013175400_project_workspace_paging_and_recovery.sql",
]);

// The earlier timestamp is intentional: latest-main environments have already
// applied migrations after WORKSPACE02 without applying WORKSPACE02 itself.
export async function verifyWorkspaceUpgrade({
  repositoryRoot,
  apiUrl,
  databaseUrl,
}) {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade resets the selected local stack; designate PLANETS_DISPOSABLE_QA=1.",
  );
  assert.ok(["127.0.0.1", "localhost"].includes(new URL(apiUrl).hostname));
  assert.ok(["127.0.0.1", "localhost"].includes(new URL(databaseUrl).hostname));
  function cli(args) {
    const result = spawnSync("supabase", args, {
      cwd: repositoryRoot,
      encoding: "utf8",
      shell: process.platform === "win32",
      maxBuffer: 16 * 1024 * 1024,
      timeout: 180000,
    });
    // Never expose status/start credentials or raw connection diagnostics.
    if (result.error || result.status !== 0) {
      const diagnostic = `${result.stderr ?? ""} ${result.stdout ?? ""}`
        .split(/\r?\n/u)
        .filter((line) => /error|failed|cannot|missing|not found/iu.test(line))
        .map((line) =>
          line
            .replace(/(?:postgres(?:ql)?|https?):\/\/\S+/giu, "[connection]")
            .replace(/eyJ[A-Za-z0-9_.-]+/gu, "[token]"),
        )
        .slice(-3)
        .join("; ");
      throw new Error(
        `Workspace upgrade ${args[0]} failed (${result.status ?? result.error?.code}): ${diagnostic}`,
      );
    }
  }

  async function fixtureAndUpgrade(label) {
    // Use a fresh pool after each reset, rather than reusing terminated sockets.
    const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
    try {
      const actor = "fa110000-0000-4000-8000-000000000001",
        project = "fa120000-0000-4000-8000-000000000001";
      await sql`insert into auth.users(id,email) values(${actor}::uuid,'workspace-upgrade@planets.invalid')`;
      await sql`insert into public.profiles(id,display_name) values(${actor}::uuid,'Workspace upgrade')`;
      await sql`insert into public.proposals(id,creator_profile_id,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,administrative_area,public_location_label)
        values(${project}::uuid,${actor}::uuid,'Upgrade Project','Upgrade summary','Upgrade description','2098-01-02T10:00:00Z','2098-01-03T10:00:00Z','Europe/Rome','IT','Trento','Trento','Trento')`;
      await sql`insert into public.project_shared_workspaces(project_id,workspace_url,created_at,updated_at)
        values(${project}::uuid,'https://example.org/preserved','2026-09-29T10:00:00Z','2026-10-01T11:00:00Z')`;
      cli(["migration", "up", "--local", "--include-all"]);
      const before =
        await sql`select * from public.project_shared_workspaces where project_id=${project}::uuid`;
      assert.equal(before.length, 1);
      assert.equal(before[0].display_name, "Workspace");
      assert.equal(before[0].workspace_url, "https://example.org/preserved");
      assert.equal(
        before[0].created_at.toISOString(),
        "2026-09-29T10:00:00.000Z",
      );
      assert.equal(
        before[0].updated_at.toISOString(),
        "2026-10-01T11:00:00.000Z",
      );
      assert.equal(before[0].legacy_slot, true);
      assert.equal(Number(before[0].version), 1);
      assert.match(before[0].id, /^[0-9a-f-]{36}$/u);
      cli(["migration", "up", "--local", "--include-all"]);
      assert.deepEqual(
        await sql`select * from public.project_shared_workspaces where project_id=${project}::uuid`,
        before,
      );
      const [receipts] =
        await sql`select count(*)::int as total from private.project_workspace_add_receipts`;
      assert.equal(receipts.total, 0);
      console.log(
        `Populated ${label} upgrade preserves URL, name, UUID, timestamps, version and legacy designation; repeated up creates no duplicate backfill.`,
      );
    } finally {
      await sql.end();
    }
  }

  cli(["db", "reset", "--local", "--version", "20261011094930"]);
  await fixtureAndUpgrade("original pre-WORKSPACE02");

  const temp = await mkdtemp(path.join(tmpdir(), "planets-workspace-upgrade-"));
  const ownedRoot = await realpath(temp),
    temporaryRoot = await realpath(tmpdir());
  try {
    await mkdir(path.join(temp, "supabase/migrations"), { recursive: true });
    await copyFile(
      path.join(repositoryRoot, "supabase/config.toml"),
      path.join(temp, "supabase/config.toml"),
    );
    await copyFile(
      path.join(repositoryRoot, "supabase/seed.sql"),
      path.join(temp, "supabase/seed.sql"),
    );
    await cp(
      path.join(repositoryRoot, "supabase/templates"),
      path.join(temp, "supabase/templates"),
      { recursive: true },
    );
    const migrations = await readdir(
      path.join(repositoryRoot, "supabase/migrations"),
      { withFileTypes: true },
    );
    for (const file of migrations) {
      if (!file.isFile() || batchMigrations.has(file.name)) continue;
      assert.match(file.name, /^\d{14}_[a-z0-9_]+\.sql$/u);
      await copyFile(
        path.join(repositoryRoot, "supabase/migrations", file.name),
        path.join(temp, "supabase/migrations", file.name),
      );
    }
    // Same explicitly disposable project/ports, different migration input set.
    // No tracked file is moved and no linked/shared/hosted project is selected.
    cli(["db", "reset", "--local", "--workdir", temp]);
    await fixtureAndUpgrade(
      "latest main missing the earlier named-links migration",
    );
  } finally {
    // Only this mkdtemp-owned, resolved, non-junction tree is eligible for rm.
    assert.equal(await realpath(temp), ownedRoot);
    assert.equal(path.dirname(ownedRoot), temporaryRoot);
    assert.ok(
      path.basename(ownedRoot).startsWith("planets-workspace-upgrade-"),
    );
    await rm(ownedRoot, { recursive: true, force: true });
  }
}
