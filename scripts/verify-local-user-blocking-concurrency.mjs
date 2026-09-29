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

  await verifyBlockWinsProjectRequest(projectRequestRace);
  await verifyProjectAcceptWinsBlock(projectAcceptRace);
  await verifyBlockWinsResourceRequest(resourceRequestRace);
  await verifyResourceAcceptWinsBlock(resourceAcceptRace);

  console.log(
    "Confirmed user-block serialization: block-first Project/Resource request creation fails with PT409 and creates no pending row; Project/Resource acceptance-first races preserve the accepted membership/agreement/chat while the subsequent block remains active.",
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
    throw new Error(`The ${action} operation did not wait for the pair lock.`);
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
