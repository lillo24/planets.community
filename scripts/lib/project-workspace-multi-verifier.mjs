import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

// Uses only the caller-selected local stack and real authenticated clients.
export async function verifyWorkspaceCollection({
  sql,
  rpc,
  denied,
  creator,
  manager,
  member,
  projectId,
  createProject,
}) {
  const list = (user, project = projectId) =>
    rpc(user, "list_project_workspace_links", {
      p_expected_profile_id: user.id,
      p_project_id: project,
    });
  const save = (user, name, url, id = null, project = projectId) =>
    rpc(user, "save_project_workspace_link", {
      p_expected_manager_profile_id: user.id,
      p_project_id: project,
      p_display_name: name,
      p_workspace_url: url,
      p_link_id: id,
    });
  const remove = (user, id, project = projectId) =>
    rpc(user, "remove_project_workspace_link", {
      p_expected_manager_profile_id: user.id,
      p_project_id: project,
      p_link_id: id,
    });
  const [legacy] = await list(creator);
  const [first, second] = await Promise.all([
    save(
      creator,
      "Documento privato verifier",
      "https://example.org/private-document",
    ),
    save(manager, "Sheet Budget verifier", "https://example.org/private-sheet"),
  ]);
  const initial = await list(member);
  assert.equal(initial.length, 3);
  assert.equal(new Set(initial.map((x) => x.id)).size, 3);
  await Promise.all([
    save(
      creator,
      "Documento aggiornato",
      "https://example.org/updated-document",
      first,
    ),
    save(
      manager,
      "Budget aggiornato",
      "https://example.org/updated-sheet",
      second,
    ),
  ]);
  const updated = await list(member);
  assert.deepEqual(
    updated.map((x) => x.id),
    initial.map((x) => x.id),
  );
  assert.equal(
    updated.find((x) => x.id === legacy.id).workspace_url,
    legacy.workspace_url,
  );
  assert.equal(
    updated.find((x) => x.id === first).display_name,
    "Documento aggiornato",
  );
  assert.equal(
    updated.find((x) => x.id === second).workspace_url,
    "https://example.org/updated-sheet",
  );
  // A draft has no source-linked template retention dependency. Delete only
  // this disposable fixture when proving Project-to-link cascade cleanup.
  const otherProject = await createProject(creator, false);
  for (const operation of [
    "save_project_workspace_link",
    "remove_project_workspace_link",
  ]) {
    const fields = operation.startsWith("save")
      ? { p_display_name: "Denied", p_workspace_url: "https://example.org" }
      : {};
    await denied(
      creator.client.rpc(operation, {
        p_expected_manager_profile_id: creator.id,
        p_project_id: otherProject,
        p_link_id: first,
        ...fields,
      }),
      "cross-Project identity",
      "42501",
    );
    await denied(
      member.client.rpc(operation, {
        p_expected_manager_profile_id: member.id,
        p_project_id: projectId,
        p_link_id: first,
        ...fields,
      }),
      "member item mutation",
      "42501",
    );
    await denied(
      creator.client.rpc(operation, {
        p_expected_manager_profile_id: member.id,
        p_project_id: projectId,
        p_link_id: first,
        ...fields,
      }),
      "mutation identity mismatch",
      "42501",
    );
  }
  await denied(
    creator.client.rpc("list_project_workspace_links", {
      p_expected_profile_id: member.id,
      p_project_id: projectId,
    }),
    "list identity mismatch",
    "42501",
  );
  for (const name of ["", " ", "x".repeat(121), "bad\nname"]) {
    await denied(
      creator.client.rpc("save_project_workspace_link", {
        p_expected_manager_profile_id: creator.id,
        p_project_id: projectId,
        p_display_name: name,
        p_workspace_url: "https://example.org",
      }),
      "invalid name",
      "22023",
    );
  }
  await rpc(creator, "set_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
    p_workspace_url: "https://example.org/legacy-update",
  });
  assert.equal((await list(creator)).length, 3);
  await rpc(creator, "clear_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
  });
  assert.equal((await list(member)).length, 2);
  assert.equal(
    (
      await rpc(creator, "get_own_project_shared_workspace", {
        p_expected_profile_id: creator.id,
        p_project_id: projectId,
      })
    ).length,
    0,
  );
  await rpc(creator, "set_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
    p_workspace_url: legacy.workspace_url,
  });
  await remove(creator, first);
  assert.ok((await list(member)).some((x) => x.id === second));
  await remove(manager, second);
  const cleanup = await save(
    creator,
    "Cleanup",
    "https://example.org/cleanup",
    null,
    otherProject,
  );
  await sql`delete from public.proposals where id=${otherProject}::uuid`;
  assert.equal(
    (
      await sql`select id from public.project_shared_workspaces where id=${cleanup}::uuid`
    ).length,
    0,
  );
  const [leaks] = await sql`select
    (select count(*) from private.audit_events where metadata::text like '%Documento aggiornato%' or metadata::text like '%updated-document%') +
    (select count(*) from private.outbox_events where payload::text like '%Documento aggiornato%' or payload::text like '%updated-document%') as total`;
  assert.equal(Number(leaks.total), 0);
  console.log(
    "Authenticated multi-link CRUD, concurrency, ordering, validation, identity/cross-Project denial, legacy coexistence and deletion cleanup passed.",
  );
}

export async function verifyWorkspaceUpgrade({ sql, repositoryRoot, apiUrl }) {
  assert.ok(
    process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
    "Upgrade resets the selected local stack; designate PLANETS_DISPOSABLE_QA=1.",
  );
  assert.ok(["127.0.0.1", "localhost"].includes(new URL(apiUrl).hostname));
  function cli(args) {
    const result = spawnSync("supabase", args, {
      cwd: repositoryRoot,
      encoding: "utf8",
      shell: process.platform === "win32",
      maxBuffer: 16 * 1024 * 1024,
    });
    // Never emit start/status output or credential-bearing raw diagnostics.
    if (result.error || result.status !== 0)
      throw new Error(
        `Workspace upgrade ${args[0]} failed (${result.status ?? result.error?.code}).`,
      );
  }
  cli(["db", "reset", "--local", "--version", "20261011094930"]);
  const actor = "fa110000-0000-4000-8000-000000000001";
  const project = "fa120000-0000-4000-8000-000000000001";
  await sql`insert into auth.users(id,email) values(${actor}::uuid,'workspace-upgrade@planets.invalid')`;
  await sql`insert into public.profiles(id,display_name) values(${actor}::uuid,'Workspace upgrade')`;
  await sql`insert into public.proposals(id,creator_profile_id,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,administrative_area,public_location_label)
    values(${project}::uuid,${actor}::uuid,'Upgrade Project','Upgrade summary','Upgrade description',now()+interval '2 days',now()+interval '3 days','Europe/Rome','IT','Trento','Trento','Trento')`;
  await sql`insert into public.project_shared_workspaces(project_id,workspace_url,created_at,updated_at)
    values(${project}::uuid,'https://example.org/preserved','2026-09-29T10:00:00Z','2026-10-01T11:00:00Z')`;
  cli(["migration", "up", "--local"]);
  const before =
    await sql`select * from public.project_shared_workspaces where project_id=${project}::uuid`;
  assert.equal(before.length, 1);
  assert.equal(before[0].display_name, "Workspace");
  assert.equal(before[0].workspace_url, "https://example.org/preserved");
  assert.equal(before[0].created_at.toISOString(), "2026-09-29T10:00:00.000Z");
  assert.equal(before[0].updated_at.toISOString(), "2026-10-01T11:00:00.000Z");
  assert.equal(before[0].legacy_slot, true);
  cli(["migration", "up", "--local"]);
  assert.deepEqual(
    await sql`select * from public.project_shared_workspaces where project_id=${project}::uuid`,
    before,
  );
  console.log(
    "Populated upgrade preserves URL, default name, identity, timestamps and legacy designation; repeated migration-up creates no duplicates.",
  );
}
