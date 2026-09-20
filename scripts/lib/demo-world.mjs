import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./local-authenticated-user.mjs";

const DEMO_LOCK_ID = 684026240991817n;
const DEMO_PREFIX = "DEMO · ";

export const DEMO_PERSONAS = deepFreeze({
  alice: {
    email: "demo-alice@planets.invalid",
    displayName: "Demo Alice",
    bio: "Community organizer who turns local ideas into welcoming projects.",
    skillSlugs: ["event-organization", "facilitation", "mural-painting"],
  },
  bob: {
    email: "demo-bob@planets.invalid",
    displayName: "Demo Bob",
    bio: "Practical participant interested in repairs, making, and technology.",
    skillSlugs: ["basic-repairs", "programming", "woodworking"],
  },
  carla: {
    email: "demo-carla@planets.invalid",
    displayName: "Demo Carla",
    bio: "Creative neighbor who enjoys music, photography, and facilitation.",
    skillSlugs: ["facilitation", "musician", "photography"],
  },
});

export const DEMO_SCENARIO_KEYS = deepFreeze({
  proposals: {
    mural: `${DEMO_PREFIX}Riverside mural`,
    repairCafe: `${DEMO_PREFIX}Repair café`,
    concert: `${DEMO_PREFIX}Courtyard concert`,
  },
  tavoli: {
    weekly: `${DEMO_PREFIX}Weekly community table`,
    monthly: `${DEMO_PREFIX}Monthly makers table`,
    paused: `${DEMO_PREFIX}Paused reading table`,
  },
  listings: {
    donate: `${DEMO_PREFIX}Community garden tools`,
    exchange: `${DEMO_PREFIX}Folding tables for a skill swap`,
    closed: `${DEMO_PREFIX}Seedling trays (claimed)`,
  },
  chatBodies: [
    "Welcome! I will bring the sketch and washable markers.",
    "Great — I can photograph the wall and help with the color plan.",
    "Perfect. We will confirm materials here before the meetup.",
  ],
});

const RESTRICTED_MURAL_MEETING =
  "Synthetic restricted meeting point beside the demo riverside gate";
const RESTRICTED_WEEKLY_MEETING =
  "Synthetic restricted room inside the demo community center";

export function assertSafeLocalDemoTarget({
  environment = "local",
  apiUrl,
  databaseUrl,
  mailpitUrl,
}) {
  if (environment !== "local") {
    throw new Error(
      "Demo world tooling supports only the explicit local target; staging and production are refused.",
    );
  }

  const api = parseRequiredUrl(apiUrl, "Supabase API URL");
  const database = parseRequiredUrl(databaseUrl, "database URL");
  const mailpit = parseRequiredUrl(mailpitUrl, "Mailpit URL");

  if (
    api.protocol !== "http:" ||
    !isLoopbackHost(api.hostname) ||
    !["postgres:", "postgresql:"].includes(database.protocol) ||
    !isLoopbackHost(database.hostname) ||
    mailpit.protocol !== "http:" ||
    !isLoopbackHost(mailpit.hostname)
  ) {
    throw new Error(
      "Demo world tooling refused a non-loopback target. Use the project-scoped local Supabase stack and local Mailpit only.",
    );
  }

  return Object.freeze({
    apiUrl: api.toString().replace(/\/$/u, ""),
    databaseUrl: databaseUrl,
    mailpitUrl: mailpit.toString().replace(/\/$/u, ""),
  });
}

export function buildDemoTimes(now = new Date()) {
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
    throw new Error("A valid clock value is required to build demo times.");
  }

  const anchor = new Date(now);
  anchor.setUTCSeconds(0, 0);
  const at = (hours) =>
    new Date(anchor.getTime() + hours * 60 * 60 * 1000).toISOString();
  const effectiveFrom = formatLocalDate(
    new Date(anchor.getTime() - 14 * 24 * 60 * 60 * 1000),
    "Europe/Rome",
  );

  return Object.freeze({
    anchor: anchor.toISOString(),
    muralStartsAt: at(36),
    muralEndsAt: at(40),
    repairStartsAt: at(7 * 24),
    repairEndsAt: at(7 * 24 + 5),
    concertStartsAt: at(-8),
    concertEndsAt: at(-2),
    safeInitialHistoricalStartsAt: at(48),
    safeInitialHistoricalEndsAt: at(51),
    recurringEffectiveFrom: effectiveFrom,
  });
}

export function classifyDemoScenarioCounts(counts) {
  const values = Object.values(counts);
  if (values.some((count) => !Number.isInteger(count) || count < 0)) {
    throw new Error("Demo scenario counts must be non-negative integers.");
  }
  if (values.some((count) => count > 1)) return "duplicate";
  if (values.every((count) => count === 0)) return "empty";
  if (values.every((count) => count === 1)) return "complete";
  return "partial";
}

export function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

export function demoReadyMessage() {
  return `Demo world ready for ${Object.values(DEMO_PERSONAS)
    .map((persona) => persona.email)
    .join(", ")}. Use Mailpit to request a fresh local sign-in code.`;
}

export async function seedLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl = "http://127.0.0.1:54324",
  now = new Date(),
}) {
  const target = requireTrustedLocalStatus(status, mailpitUrl);
  const sql = postgres(target.databaseUrl, { max: 1, onnotice: () => {} });
  const serviceClient = createClient(target.apiUrl, status.serviceRoleKey, {
    auth: { persistSession: false },
  });
  let lockAcquired = false;

  try {
    const [lock] = await sql`
      select pg_try_advisory_lock(${DEMO_LOCK_ID}) as acquired
    `;
    lockAcquired = lock?.acquired === true;
    if (!lockAcquired) {
      throw new Error(
        "Another demo-world seed is already running for this local database.",
      );
    }

    const context = await createAuthenticatedContext({
      repositoryRoot,
      status,
      mailpitUrl: target.mailpitUrl,
      sql,
      serviceClient,
    });
    const times = buildDemoTimes(now);
    const scenario = await bringDemoWorldToDesiredState(context, times);
    await projectNotificationOutbox(serviceClient);
    await verifyDemoWorldState(context, scenario, times);

    return Object.freeze({
      personas: Object.values(DEMO_PERSONAS).map((persona) => persona.email),
      proposals: Object.values(DEMO_SCENARIO_KEYS.proposals),
      tavoli: Object.values(DEMO_SCENARIO_KEYS.tavoli),
      listings: Object.values(DEMO_SCENARIO_KEYS.listings),
    });
  } finally {
    if (lockAcquired) {
      await sql`select pg_advisory_unlock(${DEMO_LOCK_ID})`;
    }
    await sql.end({ timeout: 5 });
  }
}

export async function verifyLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl = "http://127.0.0.1:54324",
  now = new Date(),
}) {
  const target = requireTrustedLocalStatus(status, mailpitUrl);
  const sql = postgres(target.databaseUrl, { max: 1, onnotice: () => {} });
  const serviceClient = createClient(target.apiUrl, status.serviceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    const context = await createAuthenticatedContext({
      repositoryRoot,
      status,
      mailpitUrl: target.mailpitUrl,
      sql,
      serviceClient,
      updateProfiles: false,
    });
    const scenario = await resolveExistingScenario(context);
    await verifyDemoWorldState(context, scenario, buildDemoTimes(now));
    return scenario;
  } finally {
    await sql.end({ timeout: 5 });
  }
}

function requireTrustedLocalStatus(status, mailpitUrl) {
  if (!status?.serviceRoleKey || !status?.databaseUrl) {
    throw new Error(
      "Local Supabase status must provide its database URL and service-role key for trusted demo tooling.",
    );
  }
  return assertSafeLocalDemoTarget({
    environment: "local",
    apiUrl: status.apiUrl,
    databaseUrl: status.databaseUrl,
    mailpitUrl,
  });
}

async function createAuthenticatedContext({
  repositoryRoot,
  status,
  mailpitUrl,
  sql,
  serviceClient,
  updateProfiles = true,
}) {
  const personaEntries = await Promise.all(
    Object.entries(DEMO_PERSONAS).map(async ([key, definition]) => [
      key,
      await signInLocalOtpUser({
        apiUrl: status.apiUrl,
        publishableKey: status.publishableKey,
        mailpitUrl,
        email: definition.email,
        verifierName: `demo ${key}`,
      }),
    ]),
  );
  const personas = Object.fromEntries(personaEntries);

  if (updateProfiles) {
    const skillSlugs = [
      ...new Set(
        Object.values(DEMO_PERSONAS).flatMap((persona) => persona.skillSlugs),
      ),
    ];
    const { data: skills, error: skillError } = await personas.alice.client
      .from("skills")
      .select("id, slug")
      .in("slug", skillSlugs);
    if (skillError || skills?.length !== skillSlugs.length) {
      throw safeDatabaseFailure(
        "load the controlled demo skill catalog",
        skillError ?? {},
      );
    }
    const skillsBySlug = new Map(skills.map((skill) => [skill.slug, skill.id]));
    await Promise.all(
      Object.entries(personas).map(([key, user]) =>
        ensureCompleteProfile(user, DEMO_PERSONAS[key], skillsBySlug),
      ),
    );
    await Promise.all(
      Object.values(personas).map((user) =>
        ensureDemoNotificationPreferences(user),
      ),
    );
  }

  return {
    repositoryRoot,
    status,
    mailpitUrl,
    sql,
    serviceClient,
    personas,
    anonymous: createClient(status.apiUrl, status.publishableKey, {
      auth: { persistSession: false },
    }),
  };
}

async function ensureCompleteProfile(user, definition, skillsBySlug) {
  const { data: anchors, error: readError } = await user.client
    .from("profiles")
    .select("id")
    .eq("id", user.id);
  if (readError) {
    throw safeDatabaseFailure("read a demo profile anchor", readError);
  }
  if (anchors.length === 0) {
    const { error: insertError } = await user.client
      .from("profiles")
      .insert({ id: user.id });
    if (insertError) {
      throw safeDatabaseFailure("create a demo profile anchor", insertError);
    }
  }

  const skillIds = definition.skillSlugs.map((slug) => skillsBySlug.get(slug));
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: definition.displayName,
    p_bio: definition.bio,
    p_skill_ids: skillIds,
    p_display_name_audience: "public",
    p_bio_audience: "public",
    p_skills_audience: "public",
  });
  if (error) {
    throw safeDatabaseFailure("complete a demo profile", error);
  }
}

async function ensureDemoNotificationPreferences(user) {
  await Promise.all(
    ["participation", "chat"].map(async (categorySlug) => {
      const { error } = await user.client.rpc(
        "set_own_notification_preference",
        {
          p_expected_profile_id: user.id,
          p_category_slug: categorySlug,
          p_in_app_enabled: true,
          p_push_enabled: true,
        },
      );
      if (error) {
        throw safeDatabaseFailure(
          "restore a demo notification preference",
          error,
        );
      }
    }),
  );
}

async function bringDemoWorldToDesiredState(context, times) {
  const { personas } = context;
  const mural = await ensureProposal(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.proposals.mural,
    summary: "Paint a bright riverside mural with neighbors.",
    description:
      "Plan the composition, prepare the wall, and paint a shared local story.",
    startsAt: times.muralStartsAt,
    endsAt: times.muralEndsAt,
    initialStartsAt: times.muralStartsAt,
    initialEndsAt: times.muralEndsAt,
    exactMeetingText: RESTRICTED_MURAL_MEETING,
    exactLocationVisibility: "participants",
    skillSlugs: ["mural-painting", "event-organization"],
    skillImportances: ["required", "useful"],
  });
  const repairCafe = await ensureProposal(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.proposals.repairCafe,
    summary: "Repair household items together instead of throwing them away.",
    description:
      "Bring a small repairable object and share practical skills around a workbench.",
    startsAt: times.repairStartsAt,
    endsAt: times.repairEndsAt,
    initialStartsAt: times.repairStartsAt,
    initialEndsAt: times.repairEndsAt,
    exactMeetingText: "Demo workshop, Via della Cooperazione 12",
    exactLocationVisibility: "public",
    skillSlugs: ["basic-repairs", "woodworking"],
    skillImportances: ["required", "useful"],
  });
  const concert = await ensureProposal(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.proposals.concert,
    summary: "A recently finished neighborhood courtyard concert.",
    description:
      "A small acoustic set organized with local performers and neighbors.",
    startsAt: times.concertStartsAt,
    endsAt: times.concertEndsAt,
    initialStartsAt: times.safeInitialHistoricalStartsAt,
    initialEndsAt: times.safeInitialHistoricalEndsAt,
    exactMeetingText: "Demo civic courtyard, Piazza Aperta 4",
    exactLocationVisibility: "public",
    skillSlugs: ["musician", "audio-sound-setup"],
    skillImportances: ["required", "useful"],
  });

  const weekly = await ensureTavolo(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.tavoli.weekly,
    summary: "A weekly table for turning neighborhood ideas into action.",
    description:
      "Bring one practical idea, find collaborators, and agree on a small next step.",
    topic: "Community projects",
    exactMeetingText: RESTRICTED_WEEKLY_MEETING,
    exactLocationVisibility: "participants",
    recurrenceType: "weekly",
    weekday: 3,
    dayOfMonth: null,
    localStartTime: "18:30:00",
    durationMinutes: 90,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "published",
  });
  const monthly = await ensureTavolo(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.tavoli.monthly,
    summary: "A monthly practical-making exchange.",
    description:
      "Share tools, explain a technique, and help someone finish a small project.",
    topic: "Making and repair",
    exactMeetingText: "Demo makers room, Via del Laboratorio 8",
    exactLocationVisibility: "public",
    recurrenceType: "monthly",
    weekday: null,
    dayOfMonth: 15,
    localStartTime: "10:00:00",
    durationMinutes: 120,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "published",
  });
  const paused = await ensureTavolo(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.tavoli.paused,
    summary: "A reading table retained as a paused owner-history example.",
    description:
      "A calm discussion series that is paused until a new facilitator volunteers.",
    topic: "Reading and discussion",
    exactMeetingText: "Demo library room, Piazza dei Libri 2",
    exactLocationVisibility: "public",
    recurrenceType: "weekly",
    weekday: 6,
    dayOfMonth: null,
    localStartTime: "16:00:00",
    durationMinutes: 75,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "paused",
  });

  const muralPendingRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    mural.id,
    "pending",
    "I can help prepare the wall and organize the materials.",
  );
  const muralMembershipId = await ensureCurrentMembership(
    context,
    personas.carla,
    personas.alice,
    mural.id,
    "I can help with photos, colors, and painting.",
  );
  const repairRejectedRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    repairCafe.id,
    "rejected",
    "I would like to lead the electrical repair station.",
  );
  const weeklyWithdrawnRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    weekly.id,
    "withdrawn",
    "I may be able to join the weekly table.",
  );
  const chat = await ensureChatHistory(
    context,
    personas.alice,
    personas.carla,
    mural.id,
  );

  const donate = await ensureListing(context, personas.alice, {
    title: DEMO_SCENARIO_KEYS.listings.donate,
    listingMode: "donate",
    description:
      "A rake, hand trowels, and two watering cans ready for another community garden.",
    lifecycle: "published",
  });
  const exchange = await ensureListing(context, personas.bob, {
    title: DEMO_SCENARIO_KEYS.listings.exchange,
    listingMode: "exchange",
    description:
      "Two folding tables offered in exchange for help repairing a wooden shelf.",
    lifecycle: "published",
  });
  const closed = await ensureListing(context, personas.carla, {
    title: DEMO_SCENARIO_KEYS.listings.closed,
    listingMode: "donate",
    description:
      "Reusable seedling trays retained as a closed owner-history example.",
    lifecycle: "closed",
  });

  return {
    proposals: { mural, repairCafe, concert },
    tavoli: { weekly, monthly, paused },
    participation: {
      muralPendingRequestId,
      muralMembershipId,
      repairRejectedRequestId,
      weeklyWithdrawnRequestId,
    },
    chat,
    listings: { donate, exchange, closed },
  };
}

async function ensureProposal(context, creator, definition) {
  const { sql } = context;
  const rows = await sql`
    select id, lifecycle_state
    from public.proposals
    where creator_profile_id = ${creator.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let proposalId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  if (!proposalId) {
    const skillIds = await resolveSkillIds(
      creator.client,
      definition.skillSlugs,
    );
    const { data, error } = await creator.client.rpc("create_proposal_draft", {
      p_expected_creator_profile_id: creator.id,
      p_title: definition.title,
      p_summary: definition.summary,
      p_description: definition.description,
      p_starts_at: definition.initialStartsAt,
      p_ends_at: definition.initialEndsAt,
      p_event_timezone: "Europe/Rome",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: definition.exactMeetingText,
      p_exact_location_visibility: definition.exactLocationVisibility,
      p_skill_ids: skillIds,
      p_skill_importances: definition.skillImportances,
    });
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo Proposal", error ?? {});
    }
    proposalId = data;
    lifecycleState = "draft";
  }

  if (lifecycleState === "cancelled") {
    throw new Error(
      `Demo-owned Proposal "${definition.title}" is cancelled; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  if (lifecycleState === "draft") {
    const { error } = await creator.client.rpc("publish_proposal", {
      p_expected_creator_profile_id: creator.id,
      p_proposal_id: proposalId,
    });
    if (error) throw safeDatabaseFailure("publish a demo Proposal", error);
  }

  await sql`
    update public.proposals
    set starts_at = ${definition.startsAt},
        ends_at = ${definition.endsAt}
    where id = ${proposalId}
  `;
  return { id: proposalId, title: definition.title };
}

async function ensureTavolo(context, creator, definition) {
  const { sql } = context;
  const rows = await sql`
    select id, lifecycle_state
    from public.recurring_activities
    where creator_profile_id = ${creator.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let tavoloId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  if (!tavoloId) {
    const { data, error } = await creator.client.rpc(
      "create_recurring_activity_draft",
      {
        p_expected_creator_profile_id: creator.id,
        p_title: definition.title,
        p_summary: definition.summary,
        p_description: definition.description,
        p_topic: definition.topic,
        p_country_code: "IT",
        p_locality: "Trento",
        p_administrative_area: "Povo",
        p_public_location_label: "Trento · Povo",
        p_exact_meeting_text: definition.exactMeetingText,
        p_exact_location_visibility: definition.exactLocationVisibility,
        p_recurrence_type: definition.recurrenceType,
        p_weekday: definition.weekday,
        p_day_of_month: definition.dayOfMonth,
        p_local_start_time: definition.localStartTime,
        p_duration_minutes: definition.durationMinutes,
        p_event_timezone: "Europe/Rome",
        p_effective_from: definition.effectiveFrom,
      },
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo Tavolo", error ?? {});
    }
    tavoloId = data;
    lifecycleState = "draft";
  }

  if (lifecycleState === "ended") {
    throw new Error(
      `Demo-owned Tavolo "${definition.title}" is ended; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  if (lifecycleState === "draft") {
    await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
    lifecycleState = "published";
  }
  if (definition.lifecycle === "paused" && lifecycleState === "published") {
    await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  } else if (
    definition.lifecycle === "published" &&
    lifecycleState === "paused"
  ) {
    await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  }
  return { id: tavoloId, title: definition.title };
}

async function transitionTavolo(user, operation, tavoloId) {
  const { error } = await user.client.rpc(operation, {
    p_expected_creator_profile_id: user.id,
    p_recurring_activity_id: tavoloId,
  });
  if (error) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error);
  }
}

async function ensureRequestState(
  context,
  requester,
  creator,
  projectId,
  desiredStatus,
  message,
) {
  const rows = await context.sql`
    select id, status
    from public.project_join_requests
    where project_id = ${projectId}
      and requester_profile_id = ${requester.id}
      and status = ${desiredStatus}
    order by created_at desc
  `;
  if (rows.length > 0) return rows[0].id;

  const pendingRows = await context.sql`
    select id
    from public.project_join_requests
    where project_id = ${projectId}
      and requester_profile_id = ${requester.id}
      and status = 'pending'
  `;
  assertAtMostOne(pendingRows, `pending request for ${projectId}`);
  let requestId = pendingRows[0]?.id;
  if (!requestId) {
    const { data, error } = await requester.client.rpc(
      "request_to_join_project",
      {
        p_expected_requester_profile_id: requester.id,
        p_project_id: projectId,
        p_request_message: message,
      },
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure(
        "create a demo participation request",
        error ?? {},
      );
    }
    requestId = data;
  }

  if (desiredStatus === "rejected") {
    const { error } = await creator.client.rpc("reject_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    });
    if (error) throw safeDatabaseFailure("reject a demo request", error);
  } else if (desiredStatus === "withdrawn") {
    const { error } = await requester.client.rpc(
      "withdraw_project_join_request",
      {
        p_expected_requester_profile_id: requester.id,
        p_request_id: requestId,
      },
    );
    if (error) throw safeDatabaseFailure("withdraw a demo request", error);
  } else if (desiredStatus !== "pending") {
    throw new Error(`Unsupported demo request state: ${desiredStatus}.`);
  }
  return requestId;
}

async function ensureCurrentMembership(
  context,
  participant,
  creator,
  projectId,
  message,
) {
  const memberships = await context.sql`
    select id
    from public.project_memberships
    where project_id = ${projectId}
      and participant_profile_id = ${participant.id}
      and left_at is null
      and removed_at is null
  `;
  assertAtMostOne(memberships, `current membership for ${projectId}`);
  if (memberships.length === 1) return memberships[0].id;

  const requestId = await ensureRequestState(
    context,
    participant,
    creator,
    projectId,
    "pending",
    message,
  );
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept a demo participation request",
      error ?? {},
    );
  }
  return data;
}

async function ensureChatHistory(context, creator, participant, projectId) {
  const { data, error } = await creator.client.rpc(
    "get_own_project_group_chat",
    {
      p_expected_profile_id: creator.id,
      p_project_id: projectId,
    },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("resolve the demo Project chat", error ?? {});
  }
  const chatId = data[0].chat_id;
  const senders = [creator, participant, creator];
  for (const [index, body] of DEMO_SCENARIO_KEYS.chatBodies.entries()) {
    const existing = await context.sql`
      select id
      from public.project_chat_messages
      where chat_id = ${chatId}
        and body = ${body}
    `;
    assertAtMostOne(existing, `demo chat message ${index + 1}`);
    if (existing.length === 0) {
      const { data: sent, error: sendError } = await senders[index].client.rpc(
        "send_project_chat_message",
        {
          p_expected_profile_id: senders[index].id,
          p_chat_id: chatId,
          p_body: body,
        },
      );
      if (sendError || sent?.length !== 1) {
        throw safeDatabaseFailure(
          "send a demo Project chat message",
          sendError ?? {},
        );
      }
    }
  }
  return { id: chatId, projectId };
}

async function ensureListing(context, owner, definition) {
  const rows = await context.sql`
    select id, lifecycle_state, listing_mode
    from public.resource_listings
    where owner_profile_id = ${owner.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let listingId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  const params = {
    p_expected_owner_profile_id: owner.id,
    p_listing_mode: definition.listingMode,
    p_title: definition.title,
    p_description: definition.description,
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
  };
  if (!listingId) {
    const { data, error } = await owner.client.rpc(
      "create_resource_listing_draft",
      params,
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo resource listing", error ?? {});
    }
    listingId = data;
    lifecycleState = "draft";
  } else if (lifecycleState === "draft") {
    const { error } = await owner.client.rpc("update_own_resource_listing", {
      ...params,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("update a demo listing", error);
  }

  if (lifecycleState === "draft") {
    const { error } = await owner.client.rpc("publish_resource_listing", {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("publish a demo listing", error);
    lifecycleState = "published";
  }
  if (definition.lifecycle === "closed" && lifecycleState === "published") {
    const { error } = await owner.client.rpc("close_resource_listing", {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("close a demo listing", error);
  } else if (
    definition.lifecycle === "published" &&
    lifecycleState === "closed"
  ) {
    throw new Error(
      `Demo-owned listing "${definition.title}" is closed; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  return { id: listingId, title: definition.title };
}

async function projectNotificationOutbox(serviceClient) {
  for (let batch = 0; batch < 20; batch += 1) {
    const { data, error } = await serviceClient.rpc(
      "process_notification_outbox_batch",
      { p_limit: 100 },
    );
    const result = data?.[0];
    if (error || !Number.isInteger(result?.processed_count)) {
      throw safeDatabaseFailure("project demo notifications", error ?? {});
    }
    if (result.processed_count === 0) return;
  }
  throw new Error(
    "The local notification backlog did not drain within 20 projector batches.",
  );
}

async function resolveExistingScenario(context) {
  const findProposal = (owner, title) =>
    findOneByTitle(context.sql, "proposal", owner.id, title);
  const findTavolo = (owner, title) =>
    findOneByTitle(context.sql, "tavolo", owner.id, title);
  const findListing = (owner, title) =>
    findOneByTitle(context.sql, "listing", owner.id, title);
  const { alice, bob, carla } = context.personas;
  const mural = await findProposal(alice, DEMO_SCENARIO_KEYS.proposals.mural);
  const repairCafe = await findProposal(
    alice,
    DEMO_SCENARIO_KEYS.proposals.repairCafe,
  );
  const concert = await findProposal(
    alice,
    DEMO_SCENARIO_KEYS.proposals.concert,
  );
  const weekly = await findTavolo(alice, DEMO_SCENARIO_KEYS.tavoli.weekly);
  const monthly = await findTavolo(alice, DEMO_SCENARIO_KEYS.tavoli.monthly);
  const paused = await findTavolo(alice, DEMO_SCENARIO_KEYS.tavoli.paused);
  const donate = await findListing(alice, DEMO_SCENARIO_KEYS.listings.donate);
  const exchange = await findListing(bob, DEMO_SCENARIO_KEYS.listings.exchange);
  const closed = await findListing(carla, DEMO_SCENARIO_KEYS.listings.closed);
  const [chat] = await context.sql`
    select chat.id
    from public.project_group_chats as chat
    where chat.project_id = ${mural.id}
  `;
  if (!chat) throw new Error("The demo mural chat is missing.");
  return {
    proposals: { mural, repairCafe, concert },
    tavoli: { weekly, monthly, paused },
    chat: { id: chat.id, projectId: mural.id },
    listings: { donate, exchange, closed },
  };
}

async function verifyDemoWorldState(context, scenario, times) {
  const { personas, anonymous, sql } = context;
  const profileIds = [personas.alice.id, personas.bob.id, personas.carla.id];
  const profileRows = await sql`
    select id, display_name, bio
    from public.profiles
    where id = any(${profileIds}::uuid[])
  `;
  if (
    profileRows.length !== 3 ||
    profileRows.some((row) => !row.display_name || !row.bio)
  ) {
    throw new Error("Demo personas do not have three complete profiles.");
  }

  const [
    proposalList,
    tavoloList,
    bobMessages,
    bobNotifications,
    chatHistory,
    listings,
  ] = await Promise.all([
    anonymous.rpc("list_public_proposals", {
      p_limit: 20,
      p_cursor_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
      p_skill_ids: null,
    }),
    anonymous.rpc("list_public_recurring_activities", {
      p_reference_time: times.anchor,
      p_limit: 20,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
    }),
    personas.bob.client.rpc("list_own_participation_request_message_items", {
      p_expected_profile_id: personas.bob.id,
      p_limit: 20,
      p_cursor_activity_at: null,
      p_cursor_request_id: null,
    }),
    personas.bob.client.rpc("list_own_notifications", {
      p_expected_profile_id: personas.bob.id,
      p_limit: 100,
      p_cursor_created_at: null,
      p_cursor_id: null,
    }),
    personas.carla.client.rpc("list_own_project_chat_messages", {
      p_expected_profile_id: personas.carla.id,
      p_chat_id: scenario.chat.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    }),
    anonymous.rpc("list_public_resource_listings", {
      p_limit: 20,
      p_cursor_published_at: null,
      p_cursor_id: null,
      p_listing_mode: null,
      p_locality: "Trento",
      p_query: null,
    }),
  ]);
  const results = [
    proposalList,
    tavoloList,
    bobMessages,
    bobNotifications,
    chatHistory,
    listings,
  ];
  if (results.some((result) => result.error || !Array.isArray(result.data))) {
    const failed = results.find((result) => result.error);
    throw safeDatabaseFailure(
      "verify the demo-world read model",
      failed?.error ?? {},
    );
  }

  const proposalIds = new Set(proposalList.data.map((row) => row.proposal_id));
  if (
    !proposalIds.has(scenario.proposals.mural.id) ||
    !proposalIds.has(scenario.proposals.repairCafe.id) ||
    !proposalIds.has(scenario.proposals.concert.id)
  ) {
    throw new Error("Expected demo Proposals were missing from discovery.");
  }
  const tavoloIds = new Set(
    tavoloList.data.map((row) => row.recurring_activity_id),
  );
  if (
    !tavoloIds.has(scenario.tavoli.weekly.id) ||
    !tavoloIds.has(scenario.tavoli.monthly.id)
  ) {
    throw new Error("Expected active demo Tavoli were missing from discovery.");
  }
  const messageStatuses = new Set(bobMessages.data.map((row) => row.status));
  if (
    !messageStatuses.has("pending") ||
    !messageStatuses.has("rejected") ||
    !messageStatuses.has("withdrawn")
  ) {
    throw new Error(
      "Bob's demo Messages do not cover the expected request states.",
    );
  }
  if (bobNotifications.data.length === 0) {
    throw new Error("Projected demo notifications were missing for Bob.");
  }
  const chatBodies = new Set(chatHistory.data.map((row) => row.body));
  if (DEMO_SCENARIO_KEYS.chatBodies.some((body) => !chatBodies.has(body))) {
    throw new Error("The demo Project chat history was incomplete.");
  }
  const listingIds = new Set(listings.data.map((row) => row.listing_id));
  if (
    !listingIds.has(scenario.listings.donate.id) ||
    !listingIds.has(scenario.listings.exchange.id) ||
    listingIds.has(scenario.listings.closed.id)
  ) {
    throw new Error("Demo resource listing discovery was inconsistent.");
  }

  const publicMural = await anonymous.rpc("get_public_proposal", {
    p_proposal_id: scenario.proposals.mural.id,
  });
  if (
    publicMural.error ||
    publicMural.data?.length !== 1 ||
    publicMural.data[0].exact_meeting_text !== null ||
    JSON.stringify(publicMural.data).includes(RESTRICTED_MURAL_MEETING)
  ) {
    throw new Error("The restricted demo Proposal exposed its exact location.");
  }

  const unauthorizedMeeting = await personas.bob.client.rpc(
    "get_project_participant_meeting_details",
    {
      p_expected_profile_id: personas.bob.id,
      p_project_id: scenario.proposals.mural.id,
    },
  );
  const unrelatedChat = await personas.bob.client.rpc(
    "list_own_project_chat_messages",
    {
      p_expected_profile_id: personas.bob.id,
      p_chat_id: scenario.chat.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    },
  );
  if (
    unauthorizedMeeting.error?.code !== "42501" ||
    unrelatedChat.error?.code !== "42501"
  ) {
    throw new Error(
      "An unrelated demo persona could access private Project data.",
    );
  }

  const authorizedMeeting = await personas.carla.client.rpc(
    "get_project_participant_meeting_details",
    {
      p_expected_profile_id: personas.carla.id,
      p_project_id: scenario.proposals.mural.id,
    },
  );
  if (
    authorizedMeeting.error ||
    authorizedMeeting.data?.[0]?.exact_meeting_text !== RESTRICTED_MURAL_MEETING
  ) {
    throw new Error(
      "The accepted demo participant lacks authorized meeting access.",
    );
  }
}

async function findOneByTitle(sql, kind, ownerId, title) {
  let rows;
  if (kind === "proposal") {
    rows = await sql`
      select id, title
      from public.proposals
      where creator_profile_id = ${ownerId} and title = ${title}
    `;
  } else if (kind === "tavolo") {
    rows = await sql`
      select id, title
      from public.recurring_activities
      where creator_profile_id = ${ownerId} and title = ${title}
    `;
  } else {
    rows = await sql`
      select id, title
      from public.resource_listings
      where owner_profile_id = ${ownerId} and title = ${title}
    `;
  }
  if (rows.length !== 1) {
    throw new Error(
      `Expected exactly one demo-owned ${kind} named "${title}"; found ${rows.length}.`,
    );
  }
  return rows[0];
}

async function resolveSkillIds(client, slugs) {
  const { data, error } = await client
    .from("skills")
    .select("id, slug")
    .in("slug", slugs);
  if (error || data?.length !== slugs.length) {
    throw safeDatabaseFailure("resolve demo Proposal skills", error ?? {});
  }
  const bySlug = new Map(data.map((skill) => [skill.slug, skill.id]));
  return slugs.map((slug) => bySlug.get(slug));
}

function assertAtMostOne(rows, label) {
  if (rows.length > 1) {
    throw new Error(
      `Found duplicate demo-owned records for "${label}"; run \`npm run demo:reset:local\` to rebuild the local database.`,
    );
  }
}

function parseRequiredUrl(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} is required for demo tooling.`);
  }
  try {
    return new URL(value);
  } catch {
    throw new Error(`${label} is not a valid URL.`);
  }
}

function isLoopbackHost(hostname) {
  return ["127.0.0.1", "localhost", "::1", "[::1]"].includes(
    hostname.toLowerCase(),
  );
}

function formatLocalDate(value, timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(value);
  const read = (type) => parts.find((part) => part.type === type)?.value;
  return `${read("year")}-${read("month")}-${read("day")}`;
}

function deepFreeze(value) {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const nested of Object.values(value)) deepFreeze(nested);
  }
  return value;
}
