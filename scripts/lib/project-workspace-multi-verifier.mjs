import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

export { verifyWorkspaceUpgrade } from "./project-workspace-upgrade-verifier.mjs";

// Actual loopback Auth/PostgREST/SQL, including parallel HTTP mutations. No
// production client ever drains these pages automatically; this verifier knows
// its synthetic fixture count and checks every explicit page against SQL.
export async function verifyWorkspaceCollection({
  sql,
  rpc,
  denied,
  creator,
  manager,
  member,
  projectId,
  createProject,
  anonymousClient,
  projectKind = "proposal",
}) {
  const marker = `workspace-private-${randomUUID()}`;
  const url = (suffix) => `https://example.org/${marker}/${suffix}`;
  const page = (user, project = projectId, limit = 10, cursor = null) =>
    rpc(user, "list_project_workspace_links", {
      p_expected_profile_id: user.id,
      p_project_id: project,
      p_limit: limit,
      p_before_created_at: cursor?.created_at ?? null,
      p_before_id: cursor?.id ?? null,
    });
  const item = (user, id, project = projectId) =>
    rpc(user, "get_project_workspace_link", {
      p_expected_profile_id: user.id,
      p_project_id: project,
      p_link_id: id,
    });
  const receipt = (user, request, project = projectId) =>
    rpc(user, "get_project_workspace_add_receipt", {
      p_expected_manager_profile_id: user.id,
      p_project_id: project,
      p_client_request_id: request,
    });
  const params = (user, name, input, id, project, request, version) => ({
    p_expected_manager_profile_id: user.id,
    p_project_id: project,
    p_display_name: name,
    p_workspace_url: input,
    p_link_id: id,
    p_client_request_id: id === null ? request : null,
    p_expected_version: id === null ? null : version,
  });
  async function save(
    user,
    name,
    input,
    id = null,
    project = projectId,
    { request = randomUUID(), version } = {},
  ) {
    const expected =
      id === null
        ? null
        : (version ?? (await item(user, id, project))?.version);
    return rpc(
      user,
      "save_project_workspace_link",
      params(user, name, input, id, project, request, expected),
    );
  }
  async function remove(user, id, project = projectId, version) {
    return rpc(user, "remove_project_workspace_link", {
      p_expected_manager_profile_id: user.id,
      p_project_id: project,
      p_link_id: id,
      p_expected_version: version ?? (await item(user, id, project))?.version,
    });
  }
  async function all(user, project = projectId, limit = 10) {
    const expected =
      await sql`select id from public.project_shared_workspaces where project_id=${project}::uuid order by created_at desc,id desc`;
    const rows = [],
      cursors = new Set();
    let cursor = null;
    do {
      const result = await page(user, project, limit, cursor);
      assert.equal(typeof result.can_manage, "boolean");
      assert.ok(Array.isArray(result.items) && result.items.length <= limit);
      rows.push(...result.items);
      assert.ok(
        rows.length <= expected.length,
        "Workspace paging exceeded its fixture snapshot.",
      );
      cursor = result.next_cursor;
      if (cursor !== null) {
        assert.equal(result.items.length, limit);
        assert.equal(cursor.id, result.items.at(-1).id);
        assert.equal(cursor.created_at, result.items.at(-1).created_at);
        assert.ok(
          !cursors.has(JSON.stringify(cursor)),
          "Workspace cursor did not advance.",
        );
        cursors.add(JSON.stringify(cursor));
      }
    } while (cursor !== null);
    assert.deepEqual(
      rows.map((row) => row.id),
      expected.map((row) => row.id),
    );
    return rows;
  }

  const [legacy] = await all(creator);
  assert.ok(
    legacy,
    "The legacy fixture must exist before named-link verification.",
  );
  const [first, second] = await Promise.all([
    save(creator, `Documento ${marker}`, url("document")),
    save(manager, `Sheet Budget ${marker}`, url("sheet")),
  ]);
  const initial = await all(member);
  assert.equal(initial.length, 3);
  assert.equal((await page(member)).can_manage, false);
  assert.equal((await page(manager)).can_manage, true);
  await Promise.all([
    save(
      creator,
      `Documento aggiornato ${marker}`,
      url("updated-document"),
      first,
    ),
    save(manager, `Budget aggiornato ${marker}`, url("updated-sheet"), second),
  ]);
  const updated = await all(member);
  assert.deepEqual(
    updated.map((row) => row.id),
    initial.map((row) => row.id),
  );
  assert.equal(
    updated.find((row) => row.id === legacy.id).workspace_url,
    legacy.workspace_url,
  );
  assert.equal((await item(member, first)).version, 2);

  // Same-version edit/edit and edit/remove races: exactly one wins, with no
  // stale overwrite. Version changes are independent of timestamp precision.
  let current = await item(creator, first);
  let races = await Promise.all([
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        `Race A ${marker}`,
        url("race-a"),
        first,
        projectId,
        null,
        current.version,
      ),
    ),
    manager.client.rpc(
      "save_project_workspace_link",
      params(
        manager,
        `Race B ${marker}`,
        url("race-b"),
        first,
        projectId,
        null,
        current.version,
      ),
    ),
  ]);
  assert.equal(
    races.filter((result) => result.error === null && result.data === first)
      .length,
    1,
  );
  assert.equal(
    races.filter((result) => result.error?.code === "40001").length,
    1,
  );
  current = await item(creator, first);
  assert.equal(current.version, 3);
  races = await Promise.all([
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        `Race edit ${marker}`,
        url("edit-remove"),
        first,
        projectId,
        null,
        current.version,
      ),
    ),
    manager.client.rpc("remove_project_workspace_link", {
      p_expected_manager_profile_id: manager.id,
      p_project_id: projectId,
      p_link_id: first,
      p_expected_version: current.version,
    }),
  ]);
  assert.equal(races.filter((result) => result.error === null).length, 1);
  assert.equal(
    races.filter((result) => ["40001", "P0002"].includes(result.error?.code))
      .length,
    1,
  );

  // Simulate a lost response after actual server acceptance, then reconcile and
  // retry the frozen actor/Project/action payload. No name/URL deduplication.
  const action = randomUUID(),
    frozenName = `Frozen ${marker}`,
    frozenUrl = url("frozen");
  await save(creator, `  ${frozenName}  `, ` ${frozenUrl} `, null, projectId, {
    request: action,
  });
  const accepted = await receipt(creator, action);
  assert.equal(accepted.accepted, true);
  assert.equal(accepted.display_name, frozenName);
  assert.equal(accepted.workspace_url, frozenUrl);
  const retry = await save(creator, frozenName, frozenUrl, null, projectId, {
    request: action,
  });
  assert.equal(retry, accepted.link_id);
  assert.equal((await item(creator, retry)).version, 1);
  await denied(
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        `Changed ${marker}`,
        frozenUrl,
        null,
        projectId,
        action,
        null,
      ),
    ),
    "changed-content Add replay",
    "40001",
  );
  assert.equal((await item(creator, retry)).display_name, frozenName);
  const otherAction = await save(creator, frozenName, frozenUrl);
  assert.notEqual(otherAction, retry);
  const parallelAction = randomUUID();
  const duplicateReplies = await Promise.all([
    save(manager, `Parallel ${marker}`, url("parallel"), null, projectId, {
      request: parallelAction,
    }),
    save(manager, `Parallel ${marker}`, url("parallel"), null, projectId, {
      request: parallelAction,
    }),
  ]);
  assert.equal(duplicateReplies[0], duplicateReplies[1]);
  const conflictingAction = randomUUID();
  const differentReplies = await Promise.all([
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        `Payload A ${marker}`,
        url("payload-a"),
        null,
        projectId,
        conflictingAction,
        null,
      ),
    ),
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        `Payload B ${marker}`,
        url("payload-b"),
        null,
        projectId,
        conflictingAction,
        null,
      ),
    ),
  ]);
  assert.equal(
    differentReplies.filter((result) => result.error === null).length,
    1,
  );
  assert.equal(
    differentReplies.filter((result) => result.error?.code === "40001").length,
    1,
  );
  assert.deepEqual(await receipt(manager, action), { accepted: false });
  await denied(
    member.client.rpc("get_project_workspace_add_receipt", {
      p_expected_manager_profile_id: member.id,
      p_project_id: projectId,
      p_client_request_id: action,
    }),
    "member command receipt",
    "42501",
  );
  await denied(
    manager.client.rpc("get_project_workspace_add_receipt", {
      p_expected_manager_profile_id: creator.id,
      p_project_id: projectId,
      p_client_request_id: action,
    }),
    "receipt identity mismatch",
    "42501",
  );
  await remove(creator, retry);
  assert.equal(
    await save(creator, frozenName, frozenUrl, null, projectId, {
      request: action,
    }),
    retry,
  );
  assert.equal(await item(creator, retry), null);
  assert.equal((await receipt(creator, action)).item, null);

  const otherProject = await createProject(creator, false);
  for (const operation of [
    "save_project_workspace_link",
    "remove_project_workspace_link",
  ]) {
    const fields = operation.startsWith("save")
      ? {
          p_display_name: "Denied",
          p_workspace_url: "https://example.org",
          p_client_request_id: null,
        }
      : {};
    for (const [user, expectedActor, project, code, label] of [
      [creator, creator.id, otherProject, "P0002", "cross-Project item"],
      [member, member.id, projectId, "42501", "member item mutation"],
      [creator, member.id, projectId, "42501", "mutation identity mismatch"],
    ]) {
      await denied(
        user.client.rpc(operation, {
          p_expected_manager_profile_id: expectedActor,
          p_project_id: project,
          p_link_id: second,
          p_expected_version: (await item(creator, second)).version,
          ...fields,
        }),
        label,
        code,
      );
    }
  }
  await denied(
    creator.client.rpc("list_project_workspace_links", {
      p_expected_profile_id: member.id,
      p_project_id: projectId,
    }),
    "list identity mismatch",
    "42501",
  );
  await denied(
    creator.client.rpc("get_project_workspace_link", {
      p_expected_profile_id: member.id,
      p_project_id: projectId,
      p_link_id: second,
    }),
    "item identity mismatch",
    "42501",
  );
  assert.equal(await item(creator, second, otherProject), null);
  for (const name of ["", " ", "x".repeat(121), "bad\nname"]) {
    await denied(
      creator.client.rpc(
        "save_project_workspace_link",
        params(
          creator,
          name,
          url("invalid"),
          null,
          projectId,
          randomUUID(),
          null,
        ),
      ),
      "invalid name",
      "22023",
    );
  }
  for (const fields of [
    { p_limit: 0 },
    { p_limit: 51 },
    { p_limit: null },
    { p_before_id: second },
    { p_before_created_at: "2030-01-01T00:00:00Z" },
  ]) {
    await denied(
      creator.client.rpc("list_project_workspace_links", {
        p_expected_profile_id: creator.id,
        p_project_id: projectId,
        ...fields,
      }),
      "invalid page/cursor",
      "22023",
    );
  }

  // Legacy set preserves the editable name and every extra; clear removes only
  // the designated entry. An explicit new Add, not an existing extra, takes an
  // empty designation. Its receipt still prevents resurrection after clear.
  await save(
    creator,
    `Renamed legacy ${marker}`,
    legacy.workspace_url,
    legacy.id,
  );
  const beforeLegacySet = await item(creator, legacy.id);
  const beforeCount = (await all(member)).length;
  await rpc(creator, "set_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
    p_workspace_url: url("legacy-update"),
  });
  const afterLegacySet = await item(creator, legacy.id);
  assert.equal(afterLegacySet.display_name, beforeLegacySet.display_name);
  assert.equal(afterLegacySet.version, beforeLegacySet.version + 1);
  assert.equal((await all(member)).length, beforeCount);
  await denied(
    creator.client.rpc(
      "save_project_workspace_link",
      params(
        creator,
        beforeLegacySet.display_name,
        beforeLegacySet.workspace_url,
        legacy.id,
        projectId,
        null,
        beforeLegacySet.version,
      ),
    ),
    "stale edit after legacy set",
    "40001",
  );
  const legacyRows = await rpc(creator, "get_own_project_shared_workspace", {
    p_expected_profile_id: creator.id,
    p_project_id: projectId,
  });
  assert.deepEqual(Object.keys(legacyRows[0]).sort(), [
    "project_id",
    "updated_at",
    "workspace_url",
  ]);
  await rpc(creator, "clear_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
  });
  assert.equal((await all(member)).length, beforeCount - 1);
  assert.deepEqual(
    await rpc(creator, "get_own_project_shared_workspace", {
      p_expected_profile_id: creator.id,
      p_project_id: projectId,
    }),
    [],
  );
  const designatedAction = randomUUID();
  const designated = await save(
    manager,
    `New designated ${marker}`,
    url("designated"),
    null,
    projectId,
    { request: designatedAction },
  );
  assert.equal(
    (
      await rpc(member, "get_own_project_shared_workspace", {
        p_expected_profile_id: member.id,
        p_project_id: projectId,
      })
    )[0].workspace_url,
    url("designated"),
  );
  await rpc(creator, "clear_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
  });
  assert.equal(
    await save(
      manager,
      `New designated ${marker}`,
      url("designated"),
      null,
      projectId,
      { request: designatedAction },
    ),
    designated,
  );
  assert.equal(await item(creator, designated), null);
  await rpc(creator, "set_project_shared_workspace", {
    p_expected_manager_profile_id: creator.id,
    p_project_id: projectId,
    p_workspace_url: legacy.workspace_url,
  });

  const tiedProject = await createProject(creator, false);
  for (let index = 0; index < 21; index++)
    await save(
      creator,
      `Paged ${index} ${marker}`,
      url(`page-${index}`),
      null,
      tiedProject,
    );
  await sql`update public.project_shared_workspaces set created_at='2026-10-01T10:00:00Z',updated_at='2026-10-01T10:00:00Z' where project_id=${tiedProject}::uuid`;
  assert.equal((await all(creator, tiedProject, 7)).length, 21);
  assert.equal((await page(creator, tiedProject, 50)).items.length, 21);

  const [publication] =
    await sql`select count(*)::int as total from pg_publication_tables where pubname='supabase_realtime' and tablename in ('project_shared_workspaces','project_workspace_add_receipts')`;
  assert.equal(publication.total, 0);
  const [leaks] = await sql`select
    (select count(*) from private.audit_events where metadata::text like ${`%${marker}%`}) +
    (select count(*) from private.outbox_events where payload::text like ${`%${marker}%`}) as total`;
  assert.equal(Number(leaks.total), 0);
  if (anonymousClient) {
    const publicResult = await anonymousClient.rpc(
      projectKind === "proposal"
        ? "get_public_proposal_v2"
        : "get_public_recurring_activity",
      projectKind === "proposal"
        ? { p_proposal_id: projectId }
        : {
            p_recurring_activity_id: projectId,
            p_occurrence_limit: 3,
            p_reference_time: new Date().toISOString(),
          },
    );
    assert.equal(publicResult.error, null);
    assert.equal(publicResult.data.length, 1);
    assert.ok(JSON.stringify(publicResult.data).includes(projectId));
    assert.ok(!JSON.stringify(publicResult.data).includes(marker));
    assert.ok(
      !JSON.stringify(publicResult.data).includes(legacy.workspace_url),
    );
    await denied(
      anonymousClient.rpc("list_project_workspace_links", {
        p_expected_profile_id: creator.id,
        p_project_id: projectId,
      }),
      "anonymous collection",
      "42501",
    );
    await denied(
      anonymousClient.rpc("get_project_workspace_link", {
        p_expected_profile_id: creator.id,
        p_project_id: projectId,
        p_link_id: second,
      }),
      "anonymous item",
      "42501",
    );
  }
  if (projectKind === "proposal") {
    const [projection] =
      await sql`select private.proposal_template_reusable_content(${projectId}::uuid) as content`;
    assert.equal(typeof projection.content, "object");
    assert.ok(projection.content.title);
    assert.ok(!JSON.stringify(projection.content).includes(marker));
    assert.ok(
      !JSON.stringify(projection.content).includes(legacy.workspace_url),
    );
  }

  if (projectKind === "proposal")
    await sql`delete from public.proposals where id in (${otherProject}::uuid,${tiedProject}::uuid)`;
  else
    await sql`delete from public.recurring_activities where id in (${otherProject}::uuid,${tiedProject}::uuid)`;
  const [cleanup] = await sql`select
    (select count(*) from public.project_shared_workspaces where project_id in (${otherProject}::uuid,${tiedProject}::uuid)) +
    (select count(*) from private.project_workspace_add_receipts where project_id in (${otherProject}::uuid,${tiedProject}::uuid)) as total`;
  assert.equal(Number(cleanup.total), 0);
  // Restore the original single-link fixture for the caller's legacy lifecycle
  // tests. Keep command tombstones for removed accepted Adds on this Project.
  const [slot] =
    await sql`select id from public.project_shared_workspaces where project_id=${projectId}::uuid and legacy_slot`;
  for (const row of await all(creator))
    if (row.id !== slot.id) await remove(creator, row.id);
  assert.equal((await all(member)).length, 1);
  console.log(
    `Authenticated ${projectKind} workspace pages, tied cursors, idempotent/lost-response Adds, CAS/concurrent writes, legacy designation, scoped denial, public/template/event privacy and cascade cleanup passed.`,
  );
}
