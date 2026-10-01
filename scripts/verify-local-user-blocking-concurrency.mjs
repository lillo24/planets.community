import { randomUUID } from "node:crypto";

import postgres from "postgres";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const { databaseUrl } = readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing the database URL required for user-block race verification.",
  );
}

const sql = postgres(databaseUrl, { max: 8, onnotice: () => {} });

try {
  await verifyUserBlockingConcurrency();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyUserBlockingConcurrency() {
  const projectRequestRace = await createProjectRaceFixture(
    "Project request block winner",
    false,
  );
  const projectAcceptRace = await createProjectRaceFixture(
    "Project acceptance interaction winner",
    true,
  );
  const resourceRequestRace = await createResourceRaceFixture(
    "Resource request block winner",
    false,
  );
  const resourceAcceptRace = await createResourceRaceFixture(
    "Resource acceptance interaction winner",
    true,
  );
  const delegatedBlockRequestRace = await createDelegatedProjectRaceFixture(
    "Delegated manager block winner",
    false,
  );
  const delegatedRequestBlockRace = await createDelegatedProjectRaceFixture(
    "Delegated Project request winner",
    false,
  );
  const delegatedBlockAcceptRace = await createDelegatedProjectRaceFixture(
    "Delegated manager block before acceptance",
    true,
  );
  const delegatedAcceptBlockRace = await createDelegatedProjectRaceFixture(
    "Delegated manager acceptance winner",
    true,
  );
  const delegatedCapacityRace = await createDelegatedProjectRaceFixture(
    "Delegated final spot",
    true,
    { includeSecondPendingRequest: true, peopleCapacity: 2 },
  );

  await verifyBlockWinsProjectRequest(projectRequestRace);
  await verifyProjectAcceptWinsBlock(projectAcceptRace);
  await verifyBlockWinsResourceRequest(resourceRequestRace);
  await verifyResourceAcceptWinsBlock(resourceAcceptRace);
  await verifyDelegatedBlockWinsProjectRequest(delegatedBlockRequestRace);
  await verifyDelegatedProjectRequestWinsBlock(delegatedRequestBlockRace);
  await verifyDelegatedBlockWinsAcceptance(delegatedBlockAcceptRace);
  await verifyDelegatedAcceptanceWinsBlock(delegatedAcceptBlockRace);
  await verifyDelegatedFinalSpotSerialization(delegatedCapacityRace);

  console.log(
    "Confirmed user-block serialization: block-first Project/Resource request creation fails with PT409; delegated-manager request/block races leave no stale pending state; delegated acceptance/block races preserve the winning terminal state; and concurrent delegated final-spot acceptance cannot overbook capacity.",
  );
}

async function createProjectRaceFixture(title, includePendingRequest) {
  const ownerId = randomUUID();
  const requesterId = randomUUID();
  const projectId = randomUUID();
  const requestId = includePendingRequest ? randomUUID() : null;

  await insertCompleteProfile(ownerId, `${title} owner`);
  await insertCompleteProfile(requesterId, `${title} requester`);
  await sql`
    insert into public.proposals (
      id,
      creator_profile_id,
      lifecycle_state,
      title,
      starts_at,
      ends_at,
      published_at
    )
    values (
      ${projectId}::uuid,
      ${ownerId}::uuid,
      'published',
      ${title},
      statement_timestamp() + interval '1 day',
      statement_timestamp() + interval '2 days',
      statement_timestamp()
    )
  `;

  if (requestId) {
    await sql`
      insert into public.project_join_requests (
        id,
        project_id,
        requester_profile_id,
        status
      )
      values (
        ${requestId}::uuid,
        ${projectId}::uuid,
        ${requesterId}::uuid,
        'pending'
      )
    `;
  }

  return { ownerId, requesterId, projectId, requestId };
}

async function createResourceRaceFixture(title, includePendingRequest) {
  const ownerId = randomUUID();
  const requesterId = randomUUID();
  const listingId = randomUUID();
  const requestId = includePendingRequest ? randomUUID() : null;

  await insertCompleteProfile(ownerId, `${title} owner`);
  await insertCompleteProfile(requesterId, `${title} requester`);
  await sql`
    insert into public.resource_listings (
      id,
      owner_profile_id,
      listing_mode,
      lifecycle_state,
      title,
      description,
      country_code,
      locality,
      public_location_label,
      published_at
    )
    values (
      ${listingId}::uuid,
      ${ownerId}::uuid,
      'exchange',
      'published',
      ${title},
      'Deterministic local fixture for the user-block race verifier.',
      'IT',
      'Trento',
      'Trento',
      statement_timestamp()
    )
  `;

  if (requestId) {
    await sql`
      insert into public.resource_listing_requests (
        id,
        listing_id,
        requester_profile_id,
        status
      )
      values (
        ${requestId}::uuid,
        ${listingId}::uuid,
        ${requesterId}::uuid,
        'pending'
      )
    `;
  }

  return { ownerId, requesterId, listingId, requestId };
}

async function createDelegatedProjectRaceFixture(
  title,
  includePendingRequest,
  { includeSecondPendingRequest = false, peopleCapacity = 10 } = {},
) {
  const ownerId = randomUUID();
  const managerId = randomUUID();
  const requesterId = randomUUID();
  const secondRequesterId = includeSecondPendingRequest ? randomUUID() : null;
  const projectId = randomUUID();
  const invitationId = randomUUID();
  const delegateId = randomUUID();
  const requestId = includePendingRequest ? randomUUID() : null;
  const secondRequestId = includeSecondPendingRequest ? randomUUID() : null;

  await insertCompleteProfile(ownerId, `${title} owner`);
  await insertCompleteProfile(managerId, `${title} Co-creator`);
  await insertCompleteProfile(requesterId, `${title} requester`);
  if (secondRequesterId) {
    await insertCompleteProfile(secondRequesterId, `${title} second requester`);
  }

  await sql`
    insert into public.proposals (
      id,
      creator_profile_id,
      lifecycle_state,
      title,
      starts_at,
      ends_at,
      published_at
    )
    values (
      ${projectId}::uuid,
      ${ownerId}::uuid,
      'published',
      ${title},
      statement_timestamp() + interval '1 day',
      statement_timestamp() + interval '2 days',
      statement_timestamp()
    )
  `;
  await sql`
    update public.projects
    set people_capacity = ${peopleCapacity}
    where id = ${projectId}::uuid
  `;
  await sql`
    insert into public.project_delegate_invitations (
      id,
      project_id,
      owner_profile_id,
      token_digest,
      status,
      created_at,
      expires_at,
      accepted_at,
      accepted_by_profile_id,
      issuer_profile_id,
      requested_authority_role
    )
    values (
      ${invitationId}::uuid,
      ${projectId}::uuid,
      ${ownerId}::uuid,
      extensions.digest(${`blocking-race-${invitationId}`}, 'sha256'),
      'accepted',
      '2026-09-27 10:00:00+00'::timestamptz,
      '2026-10-04 10:00:00+00'::timestamptz,
      '2026-09-28 10:00:00+00'::timestamptz,
      ${managerId}::uuid,
      ${ownerId}::uuid,
      'co_creator'
    )
  `;
  await sql`
    insert into public.project_delegates (
      id,
      project_id,
      owner_profile_id,
      delegate_profile_id,
      invitation_id,
      delegated_at,
      granted_by_profile_id,
      initial_authority_role,
      authority_role
    )
    values (
      ${delegateId}::uuid,
      ${projectId}::uuid,
      ${ownerId}::uuid,
      ${managerId}::uuid,
      ${invitationId}::uuid,
      '2026-09-28 10:00:00+00'::timestamptz,
      ${ownerId}::uuid,
      'co_creator',
      'co_creator'
    )
  `;

  if (requestId) {
    await sql`
      insert into public.project_join_requests (
        id,
        project_id,
        requester_profile_id,
        status
      )
      values (
        ${requestId}::uuid,
        ${projectId}::uuid,
        ${requesterId}::uuid,
        'pending'
      )
    `;
  }
  if (secondRequestId) {
    await sql`
      insert into public.project_join_requests (
        id,
        project_id,
        requester_profile_id,
        status
      )
      values (
        ${secondRequestId}::uuid,
        ${projectId}::uuid,
        ${secondRequesterId}::uuid,
        'pending'
      )
    `;
  }

  return {
    managerId,
    ownerId,
    projectId,
    requesterId,
    requestId,
    secondRequesterId,
    secondRequestId,
  };
}

async function insertCompleteProfile(profileId, displayName) {
  const photoId = randomUUID();
  await sql`
    insert into auth.users (id, email)
    values (
      ${profileId}::uuid,
      ${`${profileId}@blocking-race.planets.invalid`}
    )
  `;
  await sql`
    insert into public.profiles (id, display_name)
    values (${profileId}::uuid, ${displayName})
  `;
  await sql`
    insert into public.profile_photos (profile_id, object_path, audience)
    values (
      ${profileId}::uuid,
      ${`${profileId}/${photoId}.webp`},
      'interactions'
    )
  `;
}

async function verifyBlockWinsProjectRequest(fixture) {
  let blockedRequest;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.ownerId);
    await transaction`
      select public.block_user(
        ${fixture.ownerId}::uuid,
        ${fixture.requesterId}::uuid
      )
    `;

    blockedRequest = track(
      sql.begin(async (requestTransaction) => {
        await setAuthenticatedTransaction(
          requestTransaction,
          fixture.requesterId,
        );
        return requestTransaction`
          select public.request_to_join_project(
            ${fixture.requesterId}::uuid,
            ${fixture.projectId}::uuid,
            null,
            '{}'::uuid[],
            '{}'::uuid[]
          )
        `;
      }),
    );
    await assertBlocked(blockedRequest, "Project request behind block");
  });

  await assertTrackedDatabaseCode(
    blockedRequest,
    "PT409",
    "reject the Project request after the block commits",
  );
  await assertActiveBlock(fixture.ownerId, fixture.requesterId);
  const [{ request_count: requestCount }] = await sql`
    select count(*)::integer as request_count
    from public.project_join_requests
    where project_id = ${fixture.projectId}::uuid
      and requester_profile_id = ${fixture.requesterId}::uuid
  `;
  if (requestCount !== 0) {
    throw new Error(
      "A Project request survived even though the block won serialization.",
    );
  }
}

async function verifyProjectAcceptWinsBlock(fixture) {
  let blockedBlock;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.ownerId);
    await transaction`
      select public.accept_project_join_request(
        ${fixture.ownerId}::uuid,
        ${fixture.requestId}::uuid
      )
    `;

    blockedBlock = track(
      sql.begin(async (blockTransaction) => {
        await setAuthenticatedTransaction(blockTransaction, fixture.ownerId);
        return blockTransaction`
          select public.block_user(
            ${fixture.ownerId}::uuid,
            ${fixture.requesterId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(blockedBlock, "block behind Project acceptance");
  });

  await assertTrackedSuccess(
    blockedBlock,
    "complete the block after Project acceptance",
  );
  await assertActiveBlock(fixture.ownerId, fixture.requesterId);
  const [{ membership_count: membershipCount }] = await sql`
    select count(*)::integer as membership_count
    from public.project_join_requests as request
    join public.project_memberships as membership
      on membership.originating_request_id = request.id
    where request.id = ${fixture.requestId}::uuid
      and request.status = 'accepted'
      and membership.left_at is null
      and membership.removed_at is null
  `;
  if (membershipCount !== 1) {
    throw new Error(
      "The accepted Project membership was not preserved after the block.",
    );
  }
}

async function verifyBlockWinsResourceRequest(fixture) {
  let blockedRequest;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.ownerId);
    await transaction`
      select public.block_user(
        ${fixture.ownerId}::uuid,
        ${fixture.requesterId}::uuid
      )
    `;

    blockedRequest = track(
      sql.begin(async (requestTransaction) => {
        await setAuthenticatedTransaction(
          requestTransaction,
          fixture.requesterId,
        );
        return requestTransaction`
          select public.request_resource_listing(
            ${fixture.requesterId}::uuid,
            ${fixture.listingId}::uuid,
            null
          )
        `;
      }),
    );
    await assertBlocked(blockedRequest, "Resource request behind block");
  });

  await assertTrackedDatabaseCode(
    blockedRequest,
    "PT409",
    "reject the Resource request after the block commits",
  );
  await assertActiveBlock(fixture.ownerId, fixture.requesterId);
  const [{ request_count: requestCount }] = await sql`
    select count(*)::integer as request_count
    from public.resource_listing_requests
    where listing_id = ${fixture.listingId}::uuid
      and requester_profile_id = ${fixture.requesterId}::uuid
  `;
  if (requestCount !== 0) {
    throw new Error(
      "A Resource request survived even though the block won serialization.",
    );
  }
}

async function verifyResourceAcceptWinsBlock(fixture) {
  let blockedBlock;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.ownerId);
    await transaction`
      select public.accept_resource_listing_request(
        ${fixture.ownerId}::uuid,
        ${fixture.requestId}::uuid
      )
    `;

    blockedBlock = track(
      sql.begin(async (blockTransaction) => {
        await setAuthenticatedTransaction(blockTransaction, fixture.ownerId);
        return blockTransaction`
          select public.block_user(
            ${fixture.ownerId}::uuid,
            ${fixture.requesterId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(blockedBlock, "block behind Resource acceptance");
  });

  await assertTrackedSuccess(
    blockedBlock,
    "complete the block after Resource acceptance",
  );
  await assertActiveBlock(fixture.ownerId, fixture.requesterId);
  const [{ coordination_count: coordinationCount }] = await sql`
    select count(*)::integer as coordination_count
    from public.resource_listing_requests as request
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = request.id
    join public.resource_request_chats as chat
      on chat.request_id = request.id
    where request.id = ${fixture.requestId}::uuid
      and request.status = 'accepted'
      and request.coordination_closed_at is null
      and agreement.lifecycle_state = 'negotiating'
  `;
  if (coordinationCount !== 1) {
    throw new Error(
      "The accepted Resource agreement/chat was not preserved after the block.",
    );
  }
}

async function verifyDelegatedBlockWinsProjectRequest(fixture) {
  let blockedRequest;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.managerId);
    await transaction`
      select public.block_user(
        ${fixture.managerId}::uuid,
        ${fixture.requesterId}::uuid
      )
    `;

    blockedRequest = track(
      sql.begin(async (requestTransaction) => {
        await setAuthenticatedTransaction(
          requestTransaction,
          fixture.requesterId,
        );
        return requestTransaction`
          select public.request_to_join_project(
            ${fixture.requesterId}::uuid,
            ${fixture.projectId}::uuid,
            null,
            '{}'::uuid[],
            '{}'::uuid[]
          )
        `;
      }),
    );
    await assertBlocked(
      blockedRequest,
      "Project request behind a delegated-manager block",
    );
  });

  await assertTrackedDatabaseCode(
    blockedRequest,
    "PT409",
    "reject the Project request after the delegated-manager block commits",
  );
  await assertActiveBlock(fixture.managerId, fixture.requesterId);
  const [{ request_count: requestCount }] = await sql`
    select count(*)::integer as request_count
    from public.project_join_requests
    where project_id = ${fixture.projectId}::uuid
      and requester_profile_id = ${fixture.requesterId}::uuid
  `;
  if (requestCount !== 0) {
    throw new Error(
      "A Project request survived even though a delegated-manager block won serialization.",
    );
  }
}

async function verifyDelegatedProjectRequestWinsBlock(fixture) {
  let blockedBlock;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.requesterId);
    await transaction`
      select public.request_to_join_project(
        ${fixture.requesterId}::uuid,
        ${fixture.projectId}::uuid,
        null,
        '{}'::uuid[],
        '{}'::uuid[]
      )
    `;

    blockedBlock = track(
      sql.begin(async (blockTransaction) => {
        await setAuthenticatedTransaction(blockTransaction, fixture.managerId);
        return blockTransaction`
          select public.block_user(
            ${fixture.managerId}::uuid,
            ${fixture.requesterId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(
      blockedBlock,
      "delegated-manager block behind a Project request",
    );
  });

  await assertTrackedSuccess(
    blockedBlock,
    "complete the delegated-manager block after Project request creation",
  );
  await assertActiveBlock(fixture.managerId, fixture.requesterId);
  const [request] = await sql`
    select status, resolved_by_profile_id
    from public.project_join_requests
    where project_id = ${fixture.projectId}::uuid
      and requester_profile_id = ${fixture.requesterId}::uuid
  `;
  if (
    request?.status !== "rejected" ||
    request.resolved_by_profile_id !== fixture.managerId
  ) {
    throw new Error(
      "A delegated-manager block did not canonically reject the request that won serialization.",
    );
  }
}

async function verifyDelegatedBlockWinsAcceptance(fixture) {
  let blockedAcceptance;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.managerId);
    await transaction`
      select public.block_user(
        ${fixture.managerId}::uuid,
        ${fixture.requesterId}::uuid
      )
    `;

    blockedAcceptance = track(
      sql.begin(async (acceptTransaction) => {
        await setAuthenticatedTransaction(acceptTransaction, fixture.managerId);
        return acceptTransaction`
          select public.accept_project_join_request_as_manager(
            ${fixture.managerId}::uuid,
            ${fixture.requestId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(
      blockedAcceptance,
      "delegated-manager acceptance behind its block",
    );
  });

  await assertTrackedDatabaseCode(
    blockedAcceptance,
    "PT409",
    "reject delegated-manager acceptance after the block commits",
  );
  const [request] = await sql`
    select
      request.status,
      request.resolved_by_profile_id,
      count(membership.id)::integer as membership_count
    from public.project_join_requests as request
    left join public.project_memberships as membership
      on membership.originating_request_id = request.id
    where request.id = ${fixture.requestId}::uuid
    group by request.id
  `;
  if (
    request?.status !== "rejected" ||
    request.resolved_by_profile_id !== fixture.managerId ||
    request.membership_count !== 0
  ) {
    throw new Error(
      "Block-first delegated acceptance produced an invalid terminal state.",
    );
  }
}

async function verifyDelegatedAcceptanceWinsBlock(fixture) {
  let blockedBlock;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.managerId);
    await transaction`
      select public.accept_project_join_request_as_manager(
        ${fixture.managerId}::uuid,
        ${fixture.requestId}::uuid
      )
    `;

    blockedBlock = track(
      sql.begin(async (blockTransaction) => {
        await setAuthenticatedTransaction(blockTransaction, fixture.managerId);
        return blockTransaction`
          select public.block_user(
            ${fixture.managerId}::uuid,
            ${fixture.requesterId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(
      blockedBlock,
      "delegated-manager block behind its acceptance",
    );
  });

  await assertTrackedSuccess(
    blockedBlock,
    "complete the delegated-manager block after acceptance",
  );
  await assertActiveBlock(fixture.managerId, fixture.requesterId);
  const [{ membership_count: membershipCount }] = await sql`
    select count(*)::integer as membership_count
    from public.project_join_requests as request
    join public.project_memberships as membership
      on membership.originating_request_id = request.id
    where request.id = ${fixture.requestId}::uuid
      and request.status = 'accepted'
      and membership.left_at is null
      and membership.removed_at is null
  `;
  if (membershipCount !== 1) {
    throw new Error(
      "Delegated acceptance-first serialization did not preserve membership.",
    );
  }
}

async function verifyDelegatedFinalSpotSerialization(fixture) {
  let blockedAcceptance;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, fixture.managerId);
    await transaction`
      select public.accept_project_join_request_as_manager(
        ${fixture.managerId}::uuid,
        ${fixture.requestId}::uuid
      )
    `;

    blockedAcceptance = track(
      sql.begin(async (acceptTransaction) => {
        await setAuthenticatedTransaction(acceptTransaction, fixture.ownerId);
        return acceptTransaction`
          select public.accept_project_join_request(
            ${fixture.ownerId}::uuid,
            ${fixture.secondRequestId}::uuid
          )
        `;
      }),
    );
    await assertBlocked(
      blockedAcceptance,
      "second final-spot acceptance behind delegated acceptance",
    );
  });

  await assertTrackedDatabaseCode(
    blockedAcceptance,
    "PT409",
    "reject the second final-spot acceptance after capacity is consumed",
  );
  const [state] = await sql`
    select
      capacity.current_people_count,
      capacity.is_full,
      count(distinct membership.id)::integer as membership_count,
      max(request.status) filter (
        where request.id = ${fixture.secondRequestId}::uuid
      ) as losing_request_status
    from private.project_capacity_snapshot(${fixture.projectId}::uuid)
      as capacity
    left join public.project_memberships as membership
      on membership.project_id = ${fixture.projectId}::uuid
      and membership.left_at is null
      and membership.removed_at is null
    left join public.project_join_requests as request
      on request.project_id = ${fixture.projectId}::uuid
    group by capacity.current_people_count, capacity.is_full
  `;
  if (
    state?.current_people_count !== 2 ||
    !state.is_full ||
    state.membership_count !== 1 ||
    state.losing_request_status !== "pending"
  ) {
    throw new Error(
      "Delegated final-spot serialization did not preserve capacity and pending-state invariants.",
    );
  }
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function assertActiveBlock(firstProfileId, secondProfileId) {
  const [{ is_active: isActive }] = await sql`
    select private.has_active_user_block_between(
      ${firstProfileId}::uuid,
      ${secondProfileId}::uuid
    ) as is_active
  `;
  if (!isActive) {
    throw new Error("The expected user-block barrier is not active.");
  }
}

function track(pendingResult) {
  const tracked = { settled: false, promise: undefined };
  tracked.promise = Promise.resolve(pendingResult).then(
    (value) => {
      tracked.settled = true;
      return { ok: true, value };
    },
    (error) => {
      tracked.settled = true;
      return { error, ok: false };
    },
  );
  return tracked;
}

async function assertBlocked(tracked, action) {
  await delay(250);
  if (tracked.settled) {
    throw new Error(
      `The ${action} operation did not wait for the required serialization lock.`,
    );
  }
}

async function assertTrackedDatabaseCode(tracked, expectedCode, action) {
  const result = await tracked.promise;
  if (result.ok || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with database code ${expectedCode}.`);
  }
}

async function assertTrackedSuccess(tracked, action) {
  const result = await tracked.promise;
  if (!result.ok) {
    const code =
      typeof result.error?.code === "string" ? result.error.code : "unknown";
    throw new Error(`Failed to ${action} (code ${code}).`);
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
