import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const userAEmail = "recurring-integration-a@planets.invalid";
const userBEmail = "recurring-integration-b@planets.invalid";
const referenceTime = "2030-01-01T00:00:00.000Z";

await verifyRecurringActivities();

async function verifyRecurringActivities() {
  const [userA, userB] = await Promise.all([
    signInWithLocalOtp(userAEmail),
    signInWithLocalOtp(userBEmail),
  ]);
  await Promise.all([
    ensureCompleteProfile(userA, "Recurring Owner A"),
    ensureCompleteProfile(userB, "Recurring Owner B"),
  ]);
  await Promise.all(
    [userA, userB].map((user) => ensureLocalProfilePhoto(user)),
  );

  const userBDraftId = await createDraft(userB, {
    title: "User B recurring draft",
  });
  const restrictedExactText =
    "Private reading room for accepted participants only";
  const restrictedActivityId = await createDraft(userA, {
    title: "Weekly philosophy table",
    summary: "Discuss one philosophical question every Wednesday.",
    description:
      "An open-ended local discussion with a rotating reading prompt.",
    topic: "Philosophy",
    countryCode: "IT",
    locality: "Trento",
    administrativeArea: "Povo",
    publicLocationLabel: "Trento · Povo",
    exactMeetingText: restrictedExactText,
    exactLocationVisibility: "participants",
    recurrenceType: "weekly",
    weekday: 3,
    localStartTime: "19:00:00",
    durationMinutes: 90,
    eventTimezone: "Europe/Rome",
    effectiveFrom: "2030-01-01",
  });

  const { data: crossUserRows, error: crossUserReadError } = await userB.client
    .from("recurring_activities")
    .select("id")
    .eq("id", restrictedActivityId);
  if (crossUserReadError || crossUserRows?.length !== 0) {
    throw new Error(
      "User B could directly read user A's recurring activity row.",
    );
  }

  const { error: crossUserMutationError } = await userB.client.rpc(
    "update_own_recurring_activity",
    recurringActivityParams(userB.id, restrictedActivityId, {
      title: "Cross-account overwrite",
    }),
  );
  if (crossUserMutationError?.code !== "42501") {
    throw new Error(
      "Cross-account recurring activity mutation did not fail closed.",
    );
  }

  const { error: staleIdentityError } = await userB.client.rpc(
    "update_own_recurring_activity",
    recurringActivityParams(userA.id, userBDraftId, {
      title: "Stale user A recurring content",
    }),
  );
  if (staleIdentityError?.code !== "42501") {
    throw new Error(
      "A stale expected recurring creator was not rejected before mutation.",
    );
  }
  const { data: userBActivity, error: userBActivityError } =
    await userB.client.rpc("get_own_recurring_activity", {
      p_expected_creator_profile_id: userB.id,
      p_recurring_activity_id: userBDraftId,
    });
  if (
    userBActivityError ||
    userBActivity?.length !== 1 ||
    userBActivity[0].title !== "User B recurring draft"
  ) {
    throw new Error(
      "Stale-form rejection changed the newly authenticated user's recurring draft.",
    );
  }

  await transition(userA, "publish_recurring_activity", restrictedActivityId);

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const { data: directRows, error: directReadError } = await anonymous
    .from("recurring_activities")
    .select("id");
  if (!directReadError || directRows !== null) {
    throw new Error(
      "Anonymous direct recurring-activity access did not fail closed.",
    );
  }
  const { error: missingSnapshotError } = await anonymous.rpc(
    "list_public_recurring_activities",
    {
      p_limit: 20,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: null,
    },
  );
  if (!missingSnapshotError) {
    throw new Error(
      "Recurring discovery accepted a request without a reference-time snapshot.",
    );
  }

  const { data: restrictedList, error: restrictedListError } =
    await anonymous.rpc("list_public_recurring_activities", {
      p_limit: 20,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
      p_reference_time: referenceTime,
    });
  const restrictedCard = restrictedList?.find(
    (activity) => activity.recurring_activity_id === restrictedActivityId,
  );
  if (
    restrictedListError ||
    !restrictedCard ||
    restrictedCard.public_location_label !== "Trento · Povo" ||
    restrictedCard.event_timezone !== "Europe/Rome" ||
    !restrictedCard.next_starts_at ||
    JSON.stringify(restrictedCard).includes(restrictedExactText)
  ) {
    throw new Error(
      "Anonymous recurring discovery was not correctly derived and sanitized.",
    );
  }

  const { data: restrictedDetails, error: restrictedDetailError } =
    await anonymous.rpc("get_public_recurring_activity", {
      p_recurring_activity_id: restrictedActivityId,
      p_occurrence_limit: 5,
      p_reference_time: referenceTime,
    });
  if (
    restrictedDetailError ||
    restrictedDetails?.length !== 1 ||
    restrictedDetails[0].exact_meeting_text !== null ||
    restrictedDetails[0].exact_location_restricted !== true ||
    !Array.isArray(restrictedDetails[0].next_occurrences) ||
    restrictedDetails[0].next_occurrences.length !== 5 ||
    JSON.stringify(restrictedDetails[0]).includes(restrictedExactText)
  ) {
    throw new Error(
      "Participant-restricted recurring meeting information leaked publicly.",
    );
  }

  const publicExactText = "Piazza Duomo, beside the fountain";
  const publicActivityId = await createDraft(userA, {
    title: "Monthly culture table",
    summary: "Discuss local cultural initiatives every month.",
    description:
      "An open-ended monthly exchange about events and community projects.",
    topic: "Culture",
    countryCode: "IT",
    locality: "Trento",
    administrativeArea: "Centro storico",
    publicLocationLabel: "Trento · Centro storico",
    exactMeetingText: publicExactText,
    exactLocationVisibility: "public",
    recurrenceType: "monthly",
    dayOfMonth: 12,
    localStartTime: "18:30:00",
    durationMinutes: 120,
    eventTimezone: "Europe/Rome",
    effectiveFrom: "2030-01-01",
  });
  await transition(userA, "publish_recurring_activity", publicActivityId);

  const [
    { data: publicList, error: publicListError },
    { data: publicDetails, error: publicDetailError },
  ] = await Promise.all([
    anonymous.rpc("list_public_recurring_activities", {
      p_limit: 20,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: null,
      p_reference_time: referenceTime,
    }),
    anonymous.rpc("get_public_recurring_activity", {
      p_recurring_activity_id: publicActivityId,
      p_occurrence_limit: 3,
      p_reference_time: referenceTime,
    }),
  ]);
  const publicCard = publicList?.find(
    (activity) => activity.recurring_activity_id === publicActivityId,
  );
  if (
    publicListError ||
    publicDetailError ||
    !publicCard ||
    JSON.stringify(publicCard).includes(publicExactText) ||
    publicDetails?.length !== 1 ||
    publicDetails[0].exact_meeting_text !== publicExactText ||
    publicDetails[0].exact_location_restricted !== false
  ) {
    throw new Error(
      "Public recurring exact meeting information did not remain detail-only.",
    );
  }

  const { data: firstPage, error: firstPageError } = await anonymous.rpc(
    "list_public_recurring_activities",
    {
      p_reference_time: referenceTime,
      p_limit: 1,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: null,
    },
  );
  const firstCursor = firstPage?.[0];
  const { data: secondPage, error: secondPageError } = firstCursor
    ? await anonymous.rpc("list_public_recurring_activities", {
        p_reference_time: referenceTime,
        p_limit: 1,
        p_cursor_next_starts_at: firstCursor.next_starts_at,
        p_cursor_id: firstCursor.recurring_activity_id,
        p_locality: null,
      })
    : { data: null, error: firstPageError };
  if (
    firstPageError ||
    secondPageError ||
    firstPage?.length !== 1 ||
    secondPage?.length !== 1 ||
    firstPage[0].recurring_activity_id ===
      secondPage[0].recurring_activity_id ||
    new Set([
      firstPage[0].recurring_activity_id,
      secondPage[0].recurring_activity_id,
    ]).size !== 2
  ) {
    throw new Error(
      "Recurring discovery did not preserve one reference-time snapshot across cursor pages.",
    );
  }

  await transition(userA, "pause_recurring_activity", restrictedActivityId);
  await assertListPresence(anonymous, restrictedActivityId, false);
  const { data: pausedDetail, error: pausedDetailError } = await anonymous.rpc(
    "get_public_recurring_activity",
    {
      p_recurring_activity_id: restrictedActivityId,
      p_occurrence_limit: 5,
      p_reference_time: referenceTime,
    },
  );
  if (
    pausedDetailError ||
    pausedDetail?.length !== 1 ||
    pausedDetail[0].lifecycle_state !== "paused" ||
    pausedDetail[0].exact_meeting_text !== null ||
    pausedDetail[0].exact_location_restricted !== true ||
    !Array.isArray(pausedDetail[0].next_occurrences) ||
    pausedDetail[0].next_occurrences.length !== 0
  ) {
    throw new Error("Paused recurring detail was not retained and sanitized.");
  }

  await transition(userA, "resume_recurring_activity", restrictedActivityId);
  await assertListPresence(anonymous, restrictedActivityId, true);

  const { error: scheduleChangeError } = await userA.client.rpc(
    "update_own_recurring_activity",
    recurringActivityParams(userA.id, restrictedActivityId, {
      title: "Weekly philosophy table",
      summary: "Discuss one philosophical question every Thursday.",
      description:
        "An open-ended local discussion with a rotating reading prompt.",
      topic: "Philosophy",
      countryCode: "IT",
      locality: "Trento",
      administrativeArea: "Povo",
      publicLocationLabel: "Trento · Povo",
      exactMeetingText: restrictedExactText,
      exactLocationVisibility: "participants",
      recurrenceType: "weekly",
      weekday: 4,
      localStartTime: "20:00:00",
      durationMinutes: 90,
      eventTimezone: "Europe/Rome",
      effectiveFrom: "2031-01-01",
    }),
  );
  if (scheduleChangeError) {
    throw safeDatabaseFailure(
      "create a future recurring schedule version",
      scheduleChangeError,
    );
  }
  const { error: scheduleCorrectionError } = await userA.client.rpc(
    "update_own_recurring_activity",
    recurringActivityParams(userA.id, restrictedActivityId, {
      title: "Weekly philosophy table",
      summary: "Discuss one philosophical question every Thursday.",
      description:
        "An open-ended local discussion with a rotating reading prompt.",
      topic: "Philosophy",
      countryCode: "IT",
      locality: "Trento",
      administrativeArea: "Povo",
      publicLocationLabel: "Trento · Povo",
      exactMeetingText: restrictedExactText,
      exactLocationVisibility: "participants",
      recurrenceType: "weekly",
      weekday: 4,
      localStartTime: "21:00:00",
      durationMinutes: 90,
      eventTimezone: "Europe/Rome",
      effectiveFrom: "2031-01-01",
    }),
  );
  if (scheduleCorrectionError) {
    throw safeDatabaseFailure(
      "correct the pending recurring schedule version",
      scheduleCorrectionError,
    );
  }
  const { data: ownerDetails, error: ownerDetailError } =
    await userA.client.rpc("get_own_recurring_activity", {
      p_expected_creator_profile_id: userA.id,
      p_recurring_activity_id: restrictedActivityId,
    });
  if (
    ownerDetailError ||
    ownerDetails?.length !== 1 ||
    ownerDetails[0].exact_meeting_text !== restrictedExactText ||
    !Array.isArray(ownerDetails[0].schedule_history) ||
    ownerDetails[0].schedule_history.length !== 2 ||
    ownerDetails[0].schedule_history[0].local_start_time !== "19:00:00" ||
    ownerDetails[0].schedule_history[1].local_start_time !== "21:00:00"
  ) {
    throw new Error(
      "A pending schedule correction did not preserve already-effective owner history.",
    );
  }

  await transition(userA, "end_recurring_activity", restrictedActivityId);
  await assertListPresence(anonymous, restrictedActivityId, false);
  const { data: endedDetail, error: endedDetailError } = await anonymous.rpc(
    "get_public_recurring_activity",
    {
      p_recurring_activity_id: restrictedActivityId,
      p_occurrence_limit: 5,
      p_reference_time: referenceTime,
    },
  );
  if (
    endedDetailError ||
    endedDetail?.length !== 1 ||
    endedDetail[0].lifecycle_state !== "ended" ||
    endedDetail[0].exact_meeting_text !== null ||
    !Array.isArray(endedDetail[0].next_occurrences) ||
    endedDetail[0].next_occurrences.length !== 0
  ) {
    throw new Error("Ended recurring detail was not retained and sanitized.");
  }

  console.log(
    "Confirmed two-user recurring ownership, stale-identity rejection, snapshot pagination, weekly/monthly discovery, exact-location privacy, pause/resume/end lifecycle, and correctable pending schedule history.",
  );
}

async function assertListPresence(client, recurringActivityId, expected) {
  const { data, error } = await client.rpc("list_public_recurring_activities", {
    p_limit: 20,
    p_cursor_next_starts_at: null,
    p_cursor_id: null,
    p_locality: null,
    p_reference_time: referenceTime,
  });
  if (
    error ||
    data?.some(
      (activity) => activity.recurring_activity_id === recurringActivityId,
    ) !== expected
  ) {
    throw new Error(`Recurring discovery presence did not become ${expected}.`);
  }
}

async function createDraft(user, input) {
  const { data, error } = await user.client.rpc(
    "create_recurring_activity_draft",
    recurringActivityParams(user.id, null, input),
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a recurring activity draft", error ?? {});
  }
  return data;
}

async function transition(user, operation, recurringActivityId) {
  const { error } = await user.client.rpc(operation, {
    p_expected_creator_profile_id: user.id,
    p_recurring_activity_id: recurringActivityId,
  });
  if (error) {
    throw safeDatabaseFailure(
      `${operation.replaceAll("_", " ")} for a recurring activity`,
      error,
    );
  }
}

function recurringActivityParams(
  expectedCreatorId,
  recurringActivityId,
  input,
) {
  return {
    p_expected_creator_profile_id: expectedCreatorId,
    ...(recurringActivityId
      ? { p_recurring_activity_id: recurringActivityId }
      : {}),
    p_title: input.title ?? null,
    p_summary: input.summary ?? null,
    p_description: input.description ?? null,
    p_topic: input.topic ?? null,
    p_country_code: input.countryCode ?? null,
    p_locality: input.locality ?? null,
    p_administrative_area: input.administrativeArea ?? null,
    p_public_location_label: input.publicLocationLabel ?? null,
    p_exact_meeting_text: input.exactMeetingText ?? null,
    p_exact_location_visibility:
      input.exactLocationVisibility ?? "participants",
    p_recurrence_type: input.recurrenceType ?? null,
    p_weekday: input.weekday ?? null,
    p_day_of_month: input.dayOfMonth ?? null,
    p_local_start_time: input.localStartTime ?? null,
    p_duration_minutes: input.durationMinutes ?? null,
    p_event_timezone: input.eventTimezone ?? null,
    p_effective_from: input.effectiveFrom ?? null,
    p_people_capacity: 20,
  };
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a recurring activity profile anchor",
        anchorError,
      );
    }
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "public",
  });
  if (updateError) {
    throw safeDatabaseFailure(
      "complete a recurring activity test profile",
      updateError,
    );
  }
}

async function signInWithLocalOtp(email) {
  const client = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const existingMessageIds = await findMessageIds(email);
  const requestStartedAt = Date.now();
  const { error: requestError } = await client.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (requestError) {
    throw safeDatabaseFailure(
      "request a local recurring activity OTP",
      requestError,
    );
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local recurring activity OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local recurring activity sign-in email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local recurring activity OTP",
      verificationError ?? {},
    );
  }
  return { client, id: verification.user.id };
}

async function findMessageIds(email) {
  const result = await fetchJson(
    `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=50`,
    {},
    "search the local mailbox",
  );
  return new Set(
    Array.isArray(result.messages)
      ? result.messages
          .map((message) => message.ID)
          .filter((id) => typeof id === "string")
      : [],
  );
}

async function waitForNewMessage(email, existingIds, requestStartedAt) {
  const deadline = requestStartedAt + 15_000;
  while (Date.now() < deadline) {
    const result = await fetchJson(
      `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=10`,
      {},
      "search the local mailbox",
    );
    const messages = Array.isArray(result.messages) ? result.messages : [];
    const message = messages.find(
      (candidate) =>
        typeof candidate.ID === "string" && !existingIds.has(candidate.ID),
    );
    if (message) {
      return message.ID;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(
    "Mailpit did not receive a recurring activity OTP email within 15 seconds.",
  );
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

async function fetchJson(url, options, action) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  try {
    return await response.json();
  } catch {
    throw new Error(`Failed to ${action}: the response was not valid JSON.`);
  }
}
