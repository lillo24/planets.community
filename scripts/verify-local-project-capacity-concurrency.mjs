import { randomUUID } from "node:crypto";

import postgres from "postgres";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl) {
  throw new Error("Local Supabase status did not include a database URL.");
}

const sql = postgres(databaseUrl, { max: 4 });
const ownerId = randomUUID();
const requesterIds = [randomUUID(), randomUUID()];
const projectId = randomUUID();
const requestIds = [randomUUID(), randomUUID()];

try {
  await seedRace();
  const attempts = await Promise.all(
    requestIds.map((requestId) => acceptAsOwner(requestId)),
  );
  const winners = attempts.filter((attempt) => attempt.ok);
  const fullConflicts = attempts.filter(
    (attempt) => !attempt.ok && attempt.code === "PT409",
  );

  if (winners.length !== 1 || fullConflicts.length !== 1) {
    throw new Error(
      `Expected one acceptance and one PT409 conflict; got ${winners.length} winners and ${fullConflicts.length} full conflicts.`,
    );
  }

  const [state] = await sql`
    select
      count(*) filter (
        where membership.id is not null
          and membership.left_at is null
          and membership.removed_at is null
      )::integer as current_memberships,
      count(*) filter (where request.status = 'pending')::integer as pending_requests,
      count(*) filter (where request.status = 'accepted')::integer as accepted_requests
    from public.project_join_requests as request
    left join public.project_memberships as membership
      on membership.originating_request_id = request.id
    where request.project_id = ${projectId}::uuid
  `;

  if (
    state.current_memberships !== 1 ||
    state.pending_requests !== 1 ||
    state.accepted_requests !== 1
  ) {
    throw new Error(
      `The raced final spot did not leave exactly one membership, one accepted request, and one pending request: ${JSON.stringify(state)}.`,
    );
  }

  await verifyCapacityDecreaseRace();
  await verifyCapacityIncreaseRace();
  await verifyOrganizerToggleRace();

  console.log(
    "Project capacity concurrency verification passed: participant, capacity-edit, delegate, and organizer-toggle races serialized without overbooking.",
  );
} finally {
  await sql.end();
}

async function seedRace() {
  await sql.begin(async (transaction) => {
    await transaction`
      insert into auth.users (id, email)
      values
        (${ownerId}::uuid, ${`capacity-owner-${ownerId}@planets.invalid`}),
        (${requesterIds[0]}::uuid, ${`capacity-a-${requesterIds[0]}@planets.invalid`}),
        (${requesterIds[1]}::uuid, ${`capacity-b-${requesterIds[1]}@planets.invalid`})
    `;
    await transaction`
      insert into public.profiles (id, display_name)
      values
        (${ownerId}::uuid, 'Capacity race owner'),
        (${requesterIds[0]}::uuid, 'Capacity race A'),
        (${requesterIds[1]}::uuid, 'Capacity race B')
    `;
    await transaction`
      insert into public.proposals (
        id, creator_profile_id, lifecycle_state, title, starts_at, ends_at,
        published_at
      ) values (
        ${projectId}::uuid,
        ${ownerId}::uuid,
        'published',
        'Capacity concurrency verifier',
        statement_timestamp() + interval '1 day',
        statement_timestamp() + interval '2 days',
        statement_timestamp()
      )
    `;
    await transaction`
      update public.projects
      set registration_capacity = 1
      where id = ${projectId}::uuid
    `;
    await transaction`
      insert into public.project_join_requests (
        id, project_id, requester_profile_id
      ) values
        (${requestIds[0]}::uuid, ${projectId}::uuid, ${requesterIds[0]}::uuid),
        (${requestIds[1]}::uuid, ${projectId}::uuid, ${requesterIds[1]}::uuid)
    `;
  });
}

async function acceptAsOwner(requestId) {
  try {
    const membershipId = await sql.begin(async (transaction) => {
      await transaction`
        select set_config('request.jwt.claim.sub', ${ownerId}, true)
      `;
      await transaction.unsafe("set local role authenticated");
      const [result] = await transaction`
        select public.accept_project_join_request_as_manager(
          ${ownerId}::uuid,
          ${requestId}::uuid
        ) as membership_id
      `;
      return result.membership_id;
    });
    return { ok: true, membershipId };
  } catch (error) {
    return {
      ok: false,
      code: typeof error?.code === "string" ? error.code : "unknown",
    };
  }
}

async function verifyCapacityDecreaseRace() {
  const state = await seedCapacityEditRace(2);
  const initialAcceptance = await acceptAsOwner(state.firstRequestId);
  if (!initialAcceptance.ok) {
    throw new Error("Could not prepare the capacity-decrease race membership.");
  }

  const [acceptance, capacityUpdate] = await Promise.all([
    acceptAsOwner(state.secondRequestId),
    updateCapacity(state.projectId, 1),
  ]);
  const validSerializedOutcome =
    (acceptance.ok && !capacityUpdate.ok && capacityUpdate.code === "22023") ||
    (!acceptance.ok && acceptance.code === "PT409" && capacityUpdate.ok);
  if (!validSerializedOutcome) {
    throw new Error(
      `Capacity-decrease race had an invalid outcome: ${JSON.stringify({ acceptance, capacityUpdate })}.`,
    );
  }

  await assertProjectWithinCapacity(state.projectId);
}

async function verifyCapacityIncreaseRace() {
  const state = await seedCapacityEditRace(2);
  const initialAcceptance = await acceptAsOwner(state.firstRequestId);
  if (!initialAcceptance.ok) {
    throw new Error("Could not prepare the capacity-increase race membership.");
  }
  const initialReduction = await updateCapacity(state.projectId, 1);
  if (!initialReduction.ok) {
    throw new Error("Could not prepare the full capacity-increase race state.");
  }

  const [acceptance, capacityUpdate] = await Promise.all([
    acceptAsOwner(state.secondRequestId),
    updateCapacity(state.projectId, 2),
  ]);
  if (!capacityUpdate.ok || (!acceptance.ok && acceptance.code !== "PT409")) {
    throw new Error(
      `Capacity-increase race had an invalid outcome: ${JSON.stringify({ acceptance, capacityUpdate })}.`,
    );
  }

  await assertProjectWithinCapacity(state.projectId);
}

async function seedCapacityEditRace(capacity) {
  const raceProjectId = randomUUID();
  const firstRequestId = randomUUID();
  const secondRequestId = randomUUID();

  await sql.begin(async (transaction) => {
    await transaction`
      insert into public.proposals (
        id, creator_profile_id, lifecycle_state, title, summary, description,
        starts_at, ends_at, event_timezone, country_code, locality,
        public_location_label, published_at
      ) values (
        ${raceProjectId}::uuid,
        ${ownerId}::uuid,
        'published',
        'Capacity edit concurrency verifier',
        'Capacity edit concurrency summary',
        'Capacity edit concurrency description',
        statement_timestamp() + interval '2 days',
        statement_timestamp() + interval '3 days',
        'Europe/Rome',
        'IT',
        'Rome',
        'Central Rome',
        statement_timestamp()
      )
    `;
    await transaction`
      insert into public.proposal_meeting_details (
        proposal_id, exact_meeting_text, exact_location_visibility
      ) values (
        ${raceProjectId}::uuid,
        'Capacity edit race meeting',
        'participants'
      )
    `;
    await transaction`
      update public.projects
      set registration_capacity = ${capacity}
      where id = ${raceProjectId}::uuid
    `;
    await transaction`
      insert into public.project_join_requests (
        id, project_id, requester_profile_id
      ) values
        (${firstRequestId}::uuid, ${raceProjectId}::uuid, ${requesterIds[0]}::uuid),
        (${secondRequestId}::uuid, ${raceProjectId}::uuid, ${requesterIds[1]}::uuid)
    `;
  });

  return { projectId: raceProjectId, firstRequestId, secondRequestId };
}

async function updateCapacity(targetProjectId, capacity) {
  try {
    await sql.begin(async (transaction) => {
      await transaction`
        select set_config('request.jwt.claim.sub', ${ownerId}, true)
      `;
      await transaction.unsafe("set local role authenticated");
      await transaction`
        select public.update_own_proposal(
          ${ownerId}::uuid,
          ${targetProjectId}::uuid,
          'Capacity edit concurrency verifier',
          'Capacity edit concurrency summary',
          'Capacity edit concurrency description',
          statement_timestamp() + interval '2 days',
          statement_timestamp() + interval '3 days',
          'Europe/Rome',
          'IT',
          'Rome',
          null,
          'Central Rome',
          'Capacity edit race meeting',
          'participants',
          '{}'::uuid[],
          '{}'::text[],
          ${capacity}
        )
      `;
    });
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      code: typeof error?.code === "string" ? error.code : "unknown",
    };
  }
}

async function assertProjectWithinCapacity(targetProjectId) {
  const [state] = await sql`
    select
      registration_capacity,
      capacity_used_count,
      organizer_count,
      ordinary_participant_count,
      social_people_count
    from private.project_registration_capacity_snapshot(${targetProjectId}::uuid)
  `;
  if (state.capacity_used_count > state.registration_capacity) {
    throw new Error(
      `Project ${targetProjectId} overbooked: ${JSON.stringify(state)}.`,
    );
  }
}

async function verifyOrganizerToggleRace() {
  const targetProjectId = randomUUID();
  await sql.begin(async (transaction) => {
    await transaction`
      insert into public.proposals (
        id, creator_profile_id, lifecycle_state, title, summary, description,
        starts_at, ends_at, event_timezone, country_code, locality,
        public_location_label, published_at
      ) values (
        ${targetProjectId}::uuid,
        ${ownerId}::uuid,
        'published',
        'Organizer toggle concurrency verifier',
        'Organizer toggle concurrency summary',
        'Organizer toggle concurrency description',
        statement_timestamp() + interval '2 days',
        statement_timestamp() + interval '3 days',
        'Europe/Rome',
        'IT',
        'Rome',
        'Central Rome',
        statement_timestamp()
      )
    `;
    await transaction`
      insert into public.proposal_meeting_details (
        proposal_id, exact_meeting_text, exact_location_visibility
      ) values (
        ${targetProjectId}::uuid,
        'Organizer toggle race meeting',
        'participants'
      )
    `;
    await transaction`
      update public.projects
      set registration_capacity = 1
      where id = ${targetProjectId}::uuid
    `;
  });

  const inviteToken = await sql.begin(async (transaction) => {
    await transaction`
      select set_config('request.jwt.claim.sub', ${ownerId}, true)
    `;
    await transaction.unsafe("set local role authenticated");
    const [result] = await transaction`
      select invite_token
      from public.create_project_delegate_invitation(
        ${ownerId}::uuid,
        ${targetProjectId}::uuid,
        'co_organizer'
      )
    `;
    return result.invite_token;
  });

  const [delegateAcceptance, toggleUpdate] = await Promise.all([
    acceptDelegateInvitation(inviteToken, requesterIds[0]),
    updateCapacitySettings(targetProjectId, 1, true),
  ]);
  const validSerializedOutcome =
    (delegateAcceptance.ok &&
      !toggleUpdate.ok &&
      toggleUpdate.code === "PT409") ||
    (!delegateAcceptance.ok &&
      delegateAcceptance.code === "PT409" &&
      toggleUpdate.ok);
  if (!validSerializedOutcome) {
    throw new Error(
      `Organizer-toggle race had an invalid outcome: ${JSON.stringify({ delegateAcceptance, toggleUpdate })}.`,
    );
  }

  await assertProjectWithinCapacity(targetProjectId);
}

async function acceptDelegateInvitation(inviteToken, delegateId) {
  try {
    await sql.begin(async (transaction) => {
      await transaction`
        select set_config('request.jwt.claim.sub', ${delegateId}, true)
      `;
      await transaction.unsafe("set local role authenticated");
      await transaction`
        select public.accept_project_delegate_invitation(
          ${delegateId}::uuid,
          ${inviteToken}
        )
      `;
    });
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      code: typeof error?.code === "string" ? error.code : "unknown",
    };
  }
}

async function updateCapacitySettings(
  targetProjectId,
  registrationCapacity,
  countOrganizersTowardCapacity,
) {
  try {
    await sql.begin(async (transaction) => {
      await transaction`
        select set_config('request.jwt.claim.sub', ${ownerId}, true)
      `;
      await transaction.unsafe("set local role authenticated");
      await transaction`
        select public.update_own_proposal(
          ${ownerId}::uuid,
          ${targetProjectId}::uuid,
          'Organizer toggle concurrency verifier',
          'Organizer toggle concurrency summary',
          'Organizer toggle concurrency description',
          statement_timestamp() + interval '2 days',
          statement_timestamp() + interval '3 days',
          'Europe/Rome',
          'IT',
          'Rome',
          null,
          'Central Rome',
          'Organizer toggle race meeting',
          'participants',
          '{}'::uuid[],
          '{}'::text[],
          ${registrationCapacity},
          ${countOrganizersTowardCapacity}
        )
      `;
    });
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      code: typeof error?.code === "string" ? error.code : "unknown",
    };
  }
}
