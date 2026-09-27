import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const bucket = "profile-photos";
const tinyWebp = Buffer.from(
  "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
  "base64",
);

await verifyProfilePhotoViewers();

async function verifyProfilePhotoViewers() {
  const [organizer, applicant, unrelated, peer] = await Promise.all([
    signIn("profile-photo-viewer-organizer@planets.invalid", "organizer"),
    signIn("profile-photo-viewer-applicant@planets.invalid", "applicant"),
    signIn("profile-photo-viewer-unrelated@planets.invalid", "unrelated"),
    signIn("profile-photo-viewer-peer@planets.invalid", "peer"),
  ]);
  await Promise.all([
    ensureCompleteProfile(organizer, "Photo Organizer"),
    ensureCompleteProfile(applicant, "Photo Applicant"),
    ensureCompleteProfile(unrelated, "Photo Unrelated"),
    ensureCompleteProfile(peer, "Photo Peer"),
  ]);
  const [organizerPhoto] = await Promise.all(
    [organizer, applicant, unrelated, peer].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );
  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const firstPath = `${applicant.id}/a8100000-0000-4000-8000-000000000001.webp`;
  const replacementPath = `${applicant.id}/a8100000-0000-4000-8000-000000000002.webp`;

  await cleanup(applicant, [firstPath, replacementPath]);
  await applicant.client.rpc("clear_own_profile_photo", {
    p_expected_profile_id: applicant.id,
  });

  try {
    const proposalId = await createProposal(organizer);
    const tavoloId = await createTavolo(organizer);
    const draftProposalId = await createProposal(organizer, {
      publish: false,
      title: "Private photo verifier draft",
    });
    await expectProjectCreatorVisible(
      anonymous,
      proposalId,
      organizer.id,
      organizerPhoto.object_path,
      "public Proposal organizer",
    );
    await expectProjectCreatorVisible(
      anonymous,
      tavoloId,
      organizer.id,
      organizerPhoto.object_path,
      "public Tavolo organizer",
    );
    await expectProjectCreatorHidden(
      anonymous,
      draftProposalId,
      "private draft organizer",
    );
    await expectGenericMetadataHidden(
      anonymous,
      organizer.id,
      "context-visible interactions organizer",
    );
    await expectRpcCode(
      applicant.client.rpc("request_to_join_project", {
        p_expected_requester_profile_id: applicant.id,
        p_project_id: proposalId,
        p_request_message: null,
        p_skill_ids: [],
        p_resource_need_ids: [],
      }),
      "PT422",
      "reject a no-photo participation request",
    );

    await upload(applicant, firstPath);
    await setPhoto(applicant, firstPath, "interactions");
    await expectHidden(anonymous, applicant.id, firstPath, "anonymous viewer");
    await expectHidden(
      unrelated.client,
      applicant.id,
      firstPath,
      "unrelated viewer",
    );
    await expectHidden(
      organizer.client,
      applicant.id,
      firstPath,
      "pre-request organizer",
    );

    const proposalRequest = await requestToJoin(applicant, proposalId);
    await expectVisible(
      organizer.client,
      applicant.id,
      firstPath,
      "pending Proposal organizer",
    );
    await assertBatchVisible(organizer, applicant.id, unrelated.id, firstPath);

    await rejectRequest(organizer, proposalRequest);
    await expectHidden(
      organizer.client,
      applicant.id,
      firstPath,
      "organizer after rejection",
    );

    const acceptedProposalRequest = await requestToJoin(applicant, proposalId);
    const applicantMembership = await acceptRequest(
      organizer,
      acceptedProposalRequest,
    );
    await expectVisible(
      organizer.client,
      applicant.id,
      firstPath,
      "current-participant organizer",
    );

    const peerRequest = await requestToJoin(peer, proposalId);
    await acceptRequest(organizer, peerRequest);
    await expectHidden(peer.client, applicant.id, firstPath, "co-participant");
    await leaveMembership(applicant, applicantMembership);
    await expectHidden(
      organizer.client,
      applicant.id,
      firstPath,
      "organizer after participant leave",
    );

    const withdrawnTavoloRequest = await requestToJoin(applicant, tavoloId);
    await expectVisible(
      organizer.client,
      applicant.id,
      firstPath,
      "pending Tavolo organizer",
    );
    await withdrawRequest(applicant, withdrawnTavoloRequest);
    await expectHidden(
      organizer.client,
      applicant.id,
      firstPath,
      "organizer after withdrawal",
    );

    const acceptedTavoloRequest = await requestToJoin(applicant, tavoloId);
    const tavoloMembership = await acceptRequest(
      organizer,
      acceptedTavoloRequest,
    );
    await expectVisible(
      organizer.client,
      applicant.id,
      firstPath,
      "current Tavolo organizer",
    );
    await removeMembership(organizer, tavoloMembership);
    await expectHidden(
      organizer.client,
      applicant.id,
      firstPath,
      "organizer after participant removal",
    );

    await setAudience(applicant, "public");
    await Promise.all([
      expectVisible(
        anonymous,
        applicant.id,
        firstPath,
        "anonymous public viewer",
      ),
      expectVisible(
        unrelated.client,
        applicant.id,
        firstPath,
        "unrelated public viewer",
      ),
      expectVisible(
        organizer.client,
        applicant.id,
        firstPath,
        "organizer public viewer",
      ),
    ]);

    await upload(applicant, replacementPath);
    const replacement = await setPhoto(applicant, replacementPath, "public");
    if (replacement.previous_object_path !== firstPath) {
      throw new Error(
        "Viewer verification replacement did not retain the old path.",
      );
    }
    await expectStorageFailure(
      unrelated.client.storage.from(bucket).download(firstPath),
      "download the old noncanonical profile photo",
    );
    await expectVisible(
      unrelated.client,
      applicant.id,
      replacementPath,
      "replacement public viewer",
    );

    const { data: clearedPath, error: clearError } = await applicant.client.rpc(
      "clear_own_profile_photo",
      { p_expected_profile_id: applicant.id },
    );
    if (clearError || clearedPath !== replacementPath) {
      throw safeDatabaseFailure(
        "clear the viewer verification photo",
        clearError ?? {},
      );
    }
    await expectHidden(
      unrelated.client,
      applicant.id,
      replacementPath,
      "viewer after canonical removal",
    );

    console.log(
      "Confirmed publication-ready organizer photos, no-photo join rejection, context-only anonymous Proposal/Tavolo organizer reads, draft denial, exact/batch non-enumerating viewer metadata, directional organizer authorization, relationship revocation, canonical-only replacement reads, and removal through real Auth and Storage clients.",
    );
  } finally {
    await applicant.client.rpc("clear_own_profile_photo", {
      p_expected_profile_id: applicant.id,
    });
    await cleanup(applicant, [firstPath, replacementPath]);
  }
}

async function signIn(email, label) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: `profile photo viewer ${label}`,
  });
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a profile-photo viewer profile",
        anchorError,
      );
    }
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error) {
    throw safeDatabaseFailure("complete a profile-photo viewer profile", error);
  }
}

async function createProposal(
  creator,
  { publish = true, title = "Profile photo viewer Proposal" } = {},
) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: title,
    p_summary: "A deterministic Proposal for photo viewer authorization.",
    p_description:
      "This Proposal verifies pending and current participation photo access.",
    p_starts_at: "2099-01-02T10:00:00.000Z",
    p_ends_at: "2099-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private photo verifier Proposal location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create the photo viewer Proposal", error ?? {});
  }
  if (!publish) return data;
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish the photo viewer Proposal",
      publishError,
    );
  }
  return data;
}

async function expectProjectCreatorVisible(
  client,
  projectId,
  organizerId,
  objectPath,
  label,
) {
  const { data, error } = await client.rpc(
    "get_project_creator_profile_photo_for_viewer",
    { p_project_id: projectId },
  );
  if (
    error ||
    data?.length !== 1 ||
    data[0].profile_id !== organizerId ||
    data[0].object_path !== objectPath ||
    Object.keys(data[0]).sort().join(",") !==
      "object_path,profile_id,updated_at"
  ) {
    throw safeDatabaseFailure(`read ${label} context metadata`, error ?? {});
  }
  const { data: bytes, error: downloadError } = await client.storage
    .from(bucket)
    .download(objectPath);
  if (downloadError || !bytes || bytes.size === 0) {
    throw safeStorageFailure(`download ${label}`, downloadError ?? {});
  }
}

async function expectProjectCreatorHidden(client, projectId, label) {
  const { data, error } = await client.rpc(
    "get_project_creator_profile_photo_for_viewer",
    { p_project_id: projectId },
  );
  if (error || data?.length !== 0) {
    throw safeDatabaseFailure(`confirm hidden ${label}`, error ?? {});
  }
}

async function expectGenericMetadataHidden(client, profileId, label) {
  const { data, error } = await client.rpc("get_profile_photo_for_viewer", {
    p_profile_id: profileId,
  });
  if (error || data?.length !== 0) {
    throw safeDatabaseFailure(
      `confirm generic metadata hidden for ${label}`,
      error ?? {},
    );
  }
}

async function expectRpcCode(operation, expectedCode, label) {
  const { error } = await operation;
  if (error?.code !== expectedCode) {
    throw safeDatabaseFailure(label, error ?? {});
  }
}

async function createTavolo(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Profile photo viewer Tavolo",
      p_summary: "A deterministic Tavolo for photo viewer authorization.",
      p_description:
        "This Tavolo verifies pending and current participation photo access.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private photo verifier Tavolo location",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 4,
      p_day_of_month: null,
      p_local_start_time: "19:00:00",
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2099-01-01",
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create the photo viewer Tavolo", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc(
    "publish_recurring_activity",
    {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: data,
    },
  );
  if (publishError) {
    throw safeDatabaseFailure("publish the photo viewer Tavolo", publishError);
  }
  return data;
}

async function requestToJoin(user, projectId) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: null,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "request photo verifier participation",
      error ?? {},
    );
  }
  return data;
}

async function acceptRequest(organizer, requestId) {
  const { data, error } = await organizer.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: organizer.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept photo verifier participation",
      error ?? {},
    );
  }
  return data;
}

async function rejectRequest(organizer, requestId) {
  const { error } = await organizer.client.rpc("reject_project_join_request", {
    p_expected_creator_profile_id: organizer.id,
    p_request_id: requestId,
  });
  if (error) throw safeDatabaseFailure("reject photo verifier request", error);
}

async function withdrawRequest(applicant, requestId) {
  const { error } = await applicant.client.rpc(
    "withdraw_project_join_request",
    {
      p_expected_requester_profile_id: applicant.id,
      p_request_id: requestId,
    },
  );
  if (error)
    throw safeDatabaseFailure("withdraw photo verifier request", error);
}

async function leaveMembership(applicant, membershipId) {
  const { error } = await applicant.client.rpc("leave_project", {
    p_expected_participant_profile_id: applicant.id,
    p_membership_id: membershipId,
  });
  if (error) throw safeDatabaseFailure("leave photo verifier Project", error);
}

async function removeMembership(organizer, membershipId) {
  const { error } = await organizer.client.rpc("remove_project_member", {
    p_expected_creator_profile_id: organizer.id,
    p_membership_id: membershipId,
  });
  if (error) throw safeDatabaseFailure("remove photo verifier member", error);
}

async function upload(user, objectPath) {
  const { error } = await user.client.storage
    .from(bucket)
    .upload(objectPath, tinyWebp, {
      contentType: "image/webp",
      upsert: false,
    });
  if (error) throw safeStorageFailure("upload a viewer profile photo", error);
}

async function setPhoto(user, objectPath, audience) {
  const { data, error } = await user.client.rpc("set_own_profile_photo", {
    p_expected_profile_id: user.id,
    p_object_path: objectPath,
    p_audience: audience,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("commit a viewer profile photo", error ?? {});
  }
  return data[0];
}

async function setAudience(user, audience) {
  const { data, error } = await user.client.rpc(
    "set_own_profile_photo_audience",
    { p_expected_profile_id: user.id, p_audience: audience },
  );
  if (error || data?.length !== 1 || data[0].audience !== audience) {
    throw safeDatabaseFailure("change the viewer photo audience", error ?? {});
  }
}

async function expectVisible(client, profileId, objectPath, label) {
  const { data, error } = await client.rpc("get_profile_photo_for_viewer", {
    p_profile_id: profileId,
  });
  if (
    error ||
    data?.length !== 1 ||
    data[0].profile_id !== profileId ||
    data[0].object_path !== objectPath ||
    Object.keys(data[0]).sort().join(",") !==
      "object_path,profile_id,updated_at"
  ) {
    throw safeDatabaseFailure(`read ${label} metadata`, error ?? {});
  }
  const { data: bytes, error: downloadError } = await client.storage
    .from(bucket)
    .download(objectPath);
  if (downloadError || !bytes || bytes.size === 0) {
    throw safeStorageFailure(`download for ${label}`, downloadError ?? {});
  }
}

async function expectHidden(client, profileId, objectPath, label) {
  const { data, error } = await client.rpc("get_profile_photo_for_viewer", {
    p_profile_id: profileId,
  });
  if (error || data?.length !== 0) {
    throw safeDatabaseFailure(`confirm hidden ${label} metadata`, error ?? {});
  }
  await expectStorageFailure(
    client.storage.from(bucket).download(objectPath),
    `download a hidden object as ${label}`,
  );
}

async function assertBatchVisible(organizer, visibleId, omittedId, objectPath) {
  const { data, error } = await organizer.client.rpc(
    "list_profile_photos_for_viewer",
    { p_profile_ids: [visibleId, omittedId, visibleId] },
  );
  if (
    error ||
    data?.length !== 1 ||
    data[0].profile_id !== visibleId ||
    data[0].object_path !== objectPath
  ) {
    throw safeDatabaseFailure("batch viewer profile photos", error ?? {});
  }
}

async function expectStorageFailure(operation, action) {
  const { error } = await operation;
  if (!error) throw new Error(`Unexpectedly succeeded to ${action}.`);
}

async function cleanup(user, objectPaths) {
  try {
    await user.client.storage.from(bucket).remove(objectPaths);
  } catch {
    // Best-effort cleanup must not conceal the verifier's original failure.
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
