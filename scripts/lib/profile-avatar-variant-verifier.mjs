import assert from "node:assert/strict";

// Runs inside the existing local Auth + Storage viewer gate with its own
// immutable fixture objects. No service key, hosted deployment, or real data.
export async function verifyProfileAvatarVariants({
  owner,
  viewer,
  anonymous,
  projectId,
  tavoloId,
  listingId,
  fullPath,
  bytes,
}) {
  const bucket = "profile-photos";
  const paths = [1, 2, 3, 4].map(
    (n) =>
      `${owner.id}/a8300000-0000-4000-8000-${String(n).padStart(12, "0")}.webp`,
  );
  const [small, replacementSmall, legacyFull, oversized] = paths;
  const original = (
    await rpc(owner.client, "get_own_profile_photo", {
      p_expected_profile_id: owner.id,
    })
  )[0];
  const blockParams = {
    p_expected_blocker_profile_id: viewer.id,
    p_blocked_profile_id: owner.id,
  };
  const commit = (thumbnail) =>
    rpc(owner.client, "set_own_profile_photo_v2", {
      p_expected_profile_id: owner.id,
      p_object_path: fullPath,
      p_audience: "interactions",
      p_thumbnail_object_path: thumbnail,
    });
  const download = (client, path) => client.storage.from(bucket).download(path);
  await owner.client.storage.from(bucket).remove(paths);
  try {
    for (const path of paths) {
      const result = await owner.client.storage
        .from(bucket)
        .upload(path, path === oversized ? Buffer.alloc(32769) : bytes, {
          contentType: "image/webp",
          upsert: false,
        });
      assert.equal(result.error, null, `IMG01 upload ${path}`);
    }
    await rpc(viewer.client, "unblock_user", blockParams);
    const tooLarge = await owner.client.rpc("set_own_profile_photo_v2", {
      p_expected_profile_id: owner.id,
      p_object_path: fullPath,
      p_audience: "interactions",
      p_thumbnail_object_path: oversized,
    });
    assert.equal(
      tooLarge.error?.code,
      "22023",
      "IMG01 thumbnail ceiling is enforced by the RPC",
    );
    const foreign = await viewer.client.rpc("set_own_profile_photo_v2", {
      p_expected_profile_id: viewer.id,
      p_object_path: fullPath,
      p_audience: "public",
      p_thumbnail_object_path: small,
    });
    assert.equal(
      foreign.error?.code,
      "22023",
      "IMG01 rejects another owner's thumbnail",
    );
    await commit(small);
    const oldShape = (
      await rpc(owner.client, "get_own_profile_photo", {
        p_expected_profile_id: owner.id,
      })
    )[0];
    assert.deepEqual(
      Object.keys(oldShape).sort(),
      Object.keys(original).sort(),
      "IMG01 preserves old RPC shape",
    );
    const own = (
      await rpc(owner.client, "get_own_profile_photo_v2", {
        p_expected_profile_id: owner.id,
      })
    )[0];
    assert.equal(own.thumbnail_object_path, small);
    assert.equal(
      (
        await rpc(anonymous, "get_profile_photo_for_viewer_v2", {
          p_profile_id: owner.id,
        })
      ).length,
      0,
      "IMG01 contextual photo never becomes generic public metadata",
    );
    for (const id of [projectId, tavoloId]) {
      const visible = (
        await rpc(
          anonymous,
          "get_project_creator_profile_photo_for_viewer_v2",
          { p_project_id: id },
        )
      )[0];
      assert.equal(visible.object_path, fullPath);
      assert.equal(visible.thumbnail_object_path, small);
    }
    const resource = (
      await rpc(
        anonymous,
        "get_resource_listing_owner_profile_photo_for_viewer_v2",
        {
          p_listing_id: listingId,
        },
      )
    )[0];
    assert.equal(resource.object_path, fullPath);
    assert.equal(resource.thumbnail_object_path, small);
    assert.equal(
      (await download(anonymous, small)).error,
      null,
      "IMG01 context-authorized small bytes",
    );
    assert.equal(
      (await download(anonymous, fullPath)).error,
      null,
      "IMG01 context-authorized full bytes",
    );
    await rpc(viewer.client, "block_user", blockParams);
    assert.equal(
      (
        await rpc(
          viewer.client,
          "get_resource_listing_owner_profile_photo_for_viewer_v2",
          {
            p_listing_id: listingId,
          },
        )
      ).length,
      0,
      "IMG01 Block denies Resource-context metadata",
    );
    assert.equal(
      (
        await rpc(
          viewer.client,
          "get_project_creator_profile_photo_for_viewer_v2",
          { p_project_id: projectId },
        )
      ).length,
      0,
    );
    assert.ok(
      (await download(viewer.client, small)).error,
      "IMG01 Block denies interaction thumbnail bytes",
    );
    assert.ok(
      (await download(viewer.client, fullPath)).error,
      "IMG01 Block denies interaction full bytes",
    );
    await rpc(owner.client, "set_own_profile_photo_audience", {
      p_expected_profile_id: owner.id,
      p_audience: "public",
    });
    assert.equal(
      (await download(viewer.client, small)).error,
      null,
      "IMG01 public photos retain their deliberate audience after Block",
    );
    await rpc(viewer.client, "unblock_user", blockParams);
    const replaced = (await commit(replacementSmall))[0];
    assert.equal(replaced.previous_thumbnail_object_path, small);
    assert.ok(
      (await download(anonymous, small)).error,
      "IMG01 old small version is immediately noncanonical",
    );
    await rpc(owner.client, "set_own_profile_photo", {
      p_expected_profile_id: owner.id,
      p_object_path: legacyFull,
      p_audience: "interactions",
    });
    const legacy = (
      await rpc(anonymous, "get_project_creator_profile_photo_for_viewer_v2", {
        p_project_id: projectId,
      })
    )[0];
    assert.equal(
      legacy.thumbnail_object_path,
      null,
      "IMG01 old-client replacement drops the previous thumbnail",
    );
    assert.equal(legacy.object_path, legacyFull);
    assert.ok(
      (await download(anonymous, replacementSmall)).error,
      "IMG01 legacy replacement revokes old small bytes",
    );
    await commit(small);
    await rpc(owner.client, "clear_own_profile_photo", {
      p_expected_profile_id: owner.id,
    });
    assert.equal(
      (
        await rpc(
          anonymous,
          "get_project_creator_profile_photo_for_viewer_v2",
          { p_project_id: projectId },
        )
      ).length,
      0,
    );
    assert.ok(
      (await download(anonymous, small)).error,
      "IMG01 removal revokes small bytes",
    );
    console.log(
      "IMG01: real Auth/Storage variants, private/public audiences, Project/Tavolo/Resource contexts, Block, replacement, removal, ceiling and legacy contracts passed.",
    );
  } finally {
    await rpc(viewer.client, "unblock_user", blockParams);
    await rpc(owner.client, "set_own_profile_photo", {
      p_expected_profile_id: owner.id,
      p_object_path: original.object_path,
      p_audience: original.audience,
    });
    const cleanup = await owner.client.storage.from(bucket).remove(paths);
    assert.equal(cleanup.error, null, "IMG01 fixture cleanup");
  }
}

async function rpc(client, name, params) {
  const { data, error } = await client.rpc(name, params);
  if (error)
    throw new Error(`IMG01 ${name} failed (${error.code ?? "unknown"}).`);
  return data;
}
