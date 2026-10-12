import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
assertLoopbackUrl(apiUrl, "Supabase API");
assertLoopbackUrl(mailpitUrl, "Mailpit");

const bucket = "cover-images";
const tinyWebp = Buffer.from(
  "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
  "base64",
);

await verifyCoverMedia();

async function verifyCoverMedia() {
  const [userA, userB] = await Promise.all([
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "cover-media-a@planets.invalid",
      verifierName: "cover media A",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "cover-media-b@planets.invalid",
      verifierName: "cover media B",
    }),
  ]);
  await Promise.all([
    ensureCompleteProfile(userA, "Cover Media A"),
    ensureCompleteProfile(userB, "Cover Media B"),
  ]);
  await Promise.all([
    ensureLocalProfilePhoto(userA),
    ensureLocalProfilePhoto(userB),
  ]);

  const [proposalId, otherProposalId, resourceId] = await Promise.all([
    createProposal(userA, "Cover verification proposal"),
    createProposal(userA, "Wrong-parent verification proposal"),
    createResource(userA),
  ]);
  const proposalPaths = [
    `${userA.id}/projects/${proposalId}/81000000-0000-4000-8000-000000000001.webp`,
    `${userA.id}/projects/${proposalId}/81000000-0000-4000-8000-000000000002.webp`,
  ];
  const wrongParentPath = `${userA.id}/projects/${otherProposalId}/81000000-0000-4000-8000-000000000003.webp`;
  const resourcePath = `${userA.id}/resources/${resourceId}/81000000-0000-4000-8000-000000000004.webp`;
  const nonexistentPath = `${userA.id}/projects/81000000-0000-4000-8000-000000000099/81000000-0000-4000-8000-000000000005.webp`;
  const wrongMimePath = `${userA.id}/projects/${proposalId}/81000000-0000-4000-8000-000000000006.webp`;
  const oversizedPath = `${userA.id}/projects/${proposalId}/81000000-0000-4000-8000-000000000007.webp`;
  const cleanupPaths = [
    ...proposalPaths,
    wrongParentPath,
    resourcePath,
    nonexistentPath,
    wrongMimePath,
    oversizedPath,
  ];
  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });

  await cleanup(userA, cleanupPaths);
  try {
    await expectStorageFailure(
      userB.client.storage.from(bucket).upload(proposalPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "upload another owner's cover path",
    );
    await expectStorageFailure(
      userA.client.storage.from(bucket).upload(nonexistentPath, tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "upload a cover for a nonexistent Project",
    );
    await expectStorageFailure(
      userA.client.storage.from(bucket).upload(wrongMimePath, tinyWebp, {
        contentType: "image/png",
        upsert: false,
      }),
      "upload a non-WebP cover",
    );
    await expectStorageFailure(
      userA.client.storage
        .from(bucket)
        .upload(oversizedPath, Buffer.alloc(524289), {
          contentType: "image/webp",
          upsert: false,
        }),
      "upload a cover larger than 512 KiB",
    );

    await Promise.all([
      upload(userA, proposalPaths[0]),
      upload(userA, wrongParentPath),
      upload(userA, resourcePath),
    ]);
    await expectStorageFailure(
      userA.client.storage.from(bucket).upload(proposalPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "overwrite an immutable cover path",
    );
    await expectStorageFailure(
      userA.client.storage.from(bucket).update(proposalPaths[0], tinyWebp, {
        contentType: "image/webp",
        upsert: false,
      }),
      "update an immutable cover object",
    );

    await expectRpcCode(
      userA.client.rpc("set_own_project_cover", {
        p_expected_creator_profile_id: userA.id,
        p_project_id: proposalId,
        p_object_path: wrongParentPath,
      }),
      "22023",
      "attach a same-owner object bound to another Project",
    );
    await expectRpcCode(
      userB.client.rpc("set_own_project_cover", {
        p_expected_creator_profile_id: userA.id,
        p_project_id: proposalId,
        p_object_path: proposalPaths[0],
      }),
      "42501",
      "commit another owner's cover",
    );

    const firstCommit = await setProjectCover(
      userA,
      proposalId,
      proposalPaths[0],
    );
    if (firstCommit.previous_object_path !== null) {
      throw new Error(
        "The first canonical Project cover unexpectedly replaced a path.",
      );
    }
    await setResourceCover(userA, resourceId, resourcePath);
    await assertOwnerCover(
      userA,
      "get_own_project_cover",
      {
        p_expected_creator_profile_id: userA.id,
        p_project_id: proposalId,
      },
      proposalPaths[0],
    );
    await assertOwnerCover(
      userA,
      "get_own_resource_listing_cover",
      {
        p_expected_owner_profile_id: userA.id,
        p_listing_id: resourceId,
      },
      resourcePath,
    );

    await Promise.all([
      expectStorageFailure(
        anonymous.storage.from(bucket).download(proposalPaths[0]),
        "download a draft Proposal cover anonymously",
      ),
      expectStorageFailure(
        anonymous.storage.from(bucket).download(resourcePath),
        "download a draft Resource cover anonymously",
      ),
    ]);

    await Promise.all([
      publishProposal(userA, proposalId),
      publishResource(userA, resourceId),
    ]);
    await Promise.all([
      assertPublicPath(
        anonymous,
        "get_public_proposal",
        { p_proposal_id: proposalId },
        proposalPaths[0],
      ),
      assertPublicPath(
        anonymous,
        "get_public_resource_listing",
        { p_listing_id: resourceId },
        resourcePath,
      ),
      download(
        anonymous,
        proposalPaths[0],
        "download a public Proposal cover anonymously",
      ),
      download(
        anonymous,
        resourcePath,
        "download a public Resource cover anonymously",
      ),
    ]);

    await verifyChatCoverProjection(
      userA,
      userB,
      anonymous,
      proposalId,
      proposalPaths[0],
    );

    await upload(userA, proposalPaths[1]);
    const replacement = await setProjectCover(
      userA,
      proposalId,
      proposalPaths[1],
    );
    await assertChatCover(userB, proposalId, proposalPaths[1]);
    if (replacement.previous_object_path !== proposalPaths[0]) {
      throw new Error(
        "Project cover replacement did not return the prior path.",
      );
    }
    await download(
      anonymous,
      proposalPaths[1],
      "download the replacement cover anonymously",
    );
    await expectStorageFailure(
      anonymous.storage.from(bucket).download(proposalPaths[0]),
      "download a stale replaced cover anonymously",
    );

    const { data: foreignDelete, error: foreignDeleteError } =
      await userB.client.storage.from(bucket).remove([proposalPaths[0]]);
    if (!foreignDeleteError && foreignDelete?.length !== 0) {
      throw new Error("Another owner deleted a foreign cover object.");
    }
    await download(
      userA.client,
      proposalPaths[0],
      "confirm a foreign delete left the owner object intact",
    );

    const { data: clearedPath, error: clearError } = await userA.client.rpc(
      "clear_own_project_cover",
      {
        p_expected_creator_profile_id: userA.id,
        p_project_id: proposalId,
      },
    );
    if (clearError || clearedPath !== proposalPaths[1]) {
      throw safeDatabaseFailure(
        "clear the canonical Project cover",
        clearError ?? {},
      );
    }
    await expectStorageFailure(
      anonymous.storage.from(bucket).download(proposalPaths[1]),
      "download a cleared cover anonymously",
    );

    await assertChatCover(userB, proposalId, null);
    // A terminal chat may remain readable; this never grants its protected
    // source a public Storage image. Reattach only while still editable.
    await setProjectCover(userA, proposalId, proposalPaths[1]);
    const cancelled = await userA.client.rpc("cancel_proposal", {
      p_expected_creator_profile_id: userA.id,
      p_proposal_id: proposalId,
    });
    if (cancelled.error)
      throw safeDatabaseFailure("cancel cover source", cancelled.error);
    await assertChatCover(userB, proposalId, null);
    await expectStorageFailure(
      anonymous.storage.from(bucket).download(proposalPaths[1]),
      "download protected cancelled chat cover",
    );

    const { error: closeError } = await userA.client.rpc(
      "close_resource_listing",
      {
        p_expected_owner_profile_id: userA.id,
        p_listing_id: resourceId,
      },
    );
    if (closeError)
      throw safeDatabaseFailure(
        "close the covered Resource listing",
        closeError,
      );
    await expectStorageFailure(
      anonymous.storage.from(bucket).download(resourcePath),
      "download a terminal-hidden Resource cover anonymously",
    );

    await remove(userA, cleanupPaths);
    console.log(
      "Confirmed local cover WebP/size limits, immutable owner paths, canonical attach/replace/clear, public lifecycle reads, stale denial, tenant isolation, Storage cleanup, and v4/v5 chat cover authorization, replacement, removal and pagination.",
    );
  } finally {
    await userA.client.rpc("clear_own_project_cover", {
      p_expected_creator_profile_id: userA.id,
      p_project_id: proposalId,
    });
    await cleanup(userA, cleanupPaths);
  }
}

async function chatList(user, scope, version = 5, extra = {}) {
  const { data, error } = await user.client.rpc(
    `list_own_scoped_conversation_items_v${version}`,
    {
      p_expected_profile_id: user.id,
      p_scope: scope,
      p_limit: 50,
      ...extra,
    },
  );
  if (error) throw safeDatabaseFailure("read chat cover list", error);
  if (!Array.isArray(data))
    throw new Error("Chat cover list was not an array.");
  return data;
}
async function assertChatCover(user, projectId, expected) {
  const rows = await chatList(user, "groups");
  const row = rows.find((item) => item.project_id === projectId);
  // Existing source/entitlement rules may omit a terminal chat entirely.
  if (
    (!row && expected !== null) ||
    (row && row.group_cover_object_path !== expected)
  ) {
    throw new Error("Chat did not project the current authorized cover.");
  }
}
async function verifyChatCoverProjection(
  owner,
  member,
  anonymous,
  projectId,
  expectedPath,
) {
  const request = await member.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: member.id,
    p_project_id: projectId,
    p_request_message: "Synthetic cover-list membership",
    p_skill_ids: [],
    p_resource_need_ids: [],
  });
  if (request.error)
    throw safeDatabaseFailure("request cover-list membership", request.error);
  const accepted = await owner.client.rpc("accept_project_join_request", {
    p_expected_creator_profile_id: owner.id,
    p_request_id: request.data,
  });
  if (accepted.error)
    throw safeDatabaseFailure("accept cover-list membership", accepted.error);
  await assertChatCover(owner, projectId, expectedPath);
  await assertChatCover(member, projectId, expectedPath);
  const old = await chatList(member, "groups", 4),
    current = await chatList(member, "groups");
  const stripped = current.map(({ group_cover_object_path, ...row }) => row);
  if (JSON.stringify(old) !== JSON.stringify(stripped))
    throw new Error("v5 changed v4 ordering, unread or metadata.");
  if (
    (await chatList(member, "private")).some(
      (row) => row.group_cover_object_path !== null,
    )
  )
    throw new Error("Private row exposed a group cover.");
  const first = (await chatList(member, "groups", 5, { p_limit: 1 }))[0];
  const tail = await chatList(member, "groups", 5, {
    p_cursor_activity_at: first.activity_at,
    p_cursor_item_kind: first.item_kind,
    p_cursor_chat_id: first.chat_id,
  });
  if (
    tail.some((row) => row.chat_id === first.chat_id) ||
    tail.length !== current.length - 1
  )
    throw new Error("Cover projection broke pagination.");
  const foreign = await member.client.rpc(
    "list_own_scoped_conversation_items_v5",
    { p_expected_profile_id: owner.id, p_scope: "groups", p_limit: 50 },
  );
  if (foreign.error?.code !== "42501")
    throw new Error("Foreign owner chat-cover read was accepted.");
  const anon = await anonymous.rpc("list_own_scoped_conversation_items_v5", {
    p_expected_profile_id: owner.id,
    p_scope: "groups",
    p_limit: 50,
  });
  if (!anon.error)
    throw new Error("Anonymous chat-cover metadata read was accepted.");
}

async function ensureCompleteProfile(user, displayName) {
  const { error: insertError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (insertError) {
    const diagnostic = `${insertError.message ?? ""} ${insertError.details ?? ""}`;
    if (insertError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a cover verifier profile", insertError);
    }
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error)
    throw safeDatabaseFailure("complete a cover verifier profile", error);
}

async function createProposal(user, title) {
  const startsAt = new Date(Date.now() + 48 * 60 * 60 * 1000);
  const endsAt = new Date(startsAt.getTime() + 2 * 60 * 60 * 1000);
  const { data, error } = await user.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: user.id,
    p_title: title,
    p_summary: "A complete local proposal for cover-media verification.",
    p_description:
      "This deterministic draft exercises cover authorization without adding UI behavior.",
    p_starts_at: startsAt.toISOString(),
    p_ends_at: endsAt.toISOString(),
    p_event_timezone: "Europe/London",
    p_country_code: "GB",
    p_locality: "London",
    p_administrative_area: null,
    p_public_location_label: "London",
    p_exact_meeting_text: "Private verifier meeting point",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a cover verifier Proposal", error ?? {});
  }
  return data;
}

async function createResource(user) {
  const { data, error } = await user.client.rpc(
    "create_resource_listing_draft",
    {
      p_expected_owner_profile_id: user.id,
      p_listing_mode: "donate",
      p_title: "Cover verification tool",
      p_description:
        "A complete local Resource listing for cover-media verification.",
      p_country_code: "GB",
      p_locality: "London",
      p_administrative_area: null,
      p_public_location_label: "London",
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a cover verifier Resource", error ?? {});
  }
  return data;
}

async function upload(user, objectPath) {
  const { error } = await user.client.storage
    .from(bucket)
    .upload(objectPath, tinyWebp, {
      contentType: "image/webp",
      upsert: false,
    });
  if (error) throw safeStorageFailure("upload an owner cover", error);
}

async function setProjectCover(user, projectId, objectPath) {
  return singleRpcRow(user, "set_own_project_cover", {
    p_expected_creator_profile_id: user.id,
    p_project_id: projectId,
    p_object_path: objectPath,
  });
}

async function setResourceCover(user, listingId, objectPath) {
  return singleRpcRow(user, "set_own_resource_listing_cover", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
    p_object_path: objectPath,
  });
}

async function singleRpcRow(user, functionName, params) {
  const { data, error } = await user.client.rpc(functionName, params);
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure(`call ${functionName}`, error ?? {});
  }
  return data[0];
}

async function assertOwnerCover(user, functionName, params, expectedPath) {
  const row = await singleRpcRow(user, functionName, params);
  if (row.object_path !== expectedPath) {
    throw new Error(`${functionName} did not return the canonical cover path.`);
  }
}

async function publishProposal(user, proposalId) {
  const { error } = await user.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: user.id,
    p_proposal_id: proposalId,
  });
  if (error) throw safeDatabaseFailure("publish a covered Proposal", error);
}

async function publishResource(user, listingId) {
  const { error } = await user.client.rpc("publish_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
  });
  if (error)
    throw safeDatabaseFailure("publish a covered Resource listing", error);
}

async function assertPublicPath(client, functionName, params, expectedPath) {
  const { data, error } = await client.rpc(functionName, params);
  if (
    error ||
    data?.length !== 1 ||
    data[0].cover_object_path !== expectedPath
  ) {
    throw safeDatabaseFailure(`read ${functionName} cover path`, error ?? {});
  }
}

async function download(client, objectPath, action) {
  const { data, error } = await client.storage
    .from(bucket)
    .download(objectPath);
  if (error || !data || data.size === 0) {
    throw safeStorageFailure(action, error ?? {});
  }
}

async function remove(user, objectPaths) {
  const { error } = await user.client.storage.from(bucket).remove(objectPaths);
  if (error) throw safeStorageFailure("delete owner cover objects", error);
}

async function cleanup(user, objectPaths) {
  try {
    await user.client.storage.from(bucket).remove(objectPaths);
  } catch {
    // Cleanup must not conceal the verifier's original failure.
  }
}

async function expectStorageFailure(operation, action) {
  const { error } = await operation;
  if (!error) throw new Error(`Unexpectedly succeeded to ${action}.`);
}

async function expectRpcCode(operation, code, action) {
  const { error } = await operation;
  if (error?.code !== code) {
    throw new Error(
      `Unexpectedly failed to ${action} with code ${error?.code ?? "none"}.`,
    );
  }
}

function assertLoopbackUrl(value, label) {
  const hostname = new URL(value).hostname;
  if (!["127.0.0.1", "localhost", "::1", "[::1]"].includes(hostname)) {
    throw new Error(
      `${label} must resolve to a loopback host for this destructive local verifier.`,
    );
  }
}

function safeStorageFailure(action, error) {
  const statusCode = Number.isInteger(error?.statusCode)
    ? error.statusCode
    : "unknown";
  return new Error(`Failed to ${action} (HTTP ${statusCode}).`);
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
