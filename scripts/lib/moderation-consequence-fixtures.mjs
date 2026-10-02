import { randomUUID } from "node:crypto";

/** Local-only synthetic fixtures shared by the authenticated and race verifiers. */
export async function createConsequenceFixture(sql, suppliedActors) {
  const actors =
    suppliedActors ??
    Object.fromEntries(
      [
        "moderator",
        "admin",
        "owner",
        "cocreator",
        "coorganizer",
        "requester",
        "unrelated",
      ].map((role) => [role, randomUUID()]),
    );
  if (!suppliedActors) {
    for (const [role, id] of Object.entries(actors)) {
      await sql`insert into auth.users(id, email) values(${id}::uuid, ${`consequence-${role}-${id}@planets.invalid`})`;
      await sql`insert into public.profiles(id, display_name) values(${id}::uuid, ${`Consequence ${role}`})`;
    }
  }
  for (const id of Object.values(actors)) {
    await sql`insert into public.profile_photos(profile_id, object_path, audience)
      values(${id}::uuid, ${`${id}/${randomUUID()}.webp`}, 'interactions') on conflict(profile_id) do nothing`;
  }
  for (const role of ["moderator", "admin"]) {
    await sql`insert into private.moderation_staff_roles(profile_id, staff_role)
      values(${actors[role]}::uuid, ${role}) on conflict(profile_id) do update
      set is_active = true, deactivated_at = null, staff_role = excluded.staff_role`;
  }
  const projectId = randomUUID();
  const listingId = randomUUID();
  await sql`insert into public.proposals(id, creator_profile_id, lifecycle_state, title, summary,
    description, starts_at, ends_at, event_timezone, country_code, locality, public_location_label, published_at)
    values(${projectId}::uuid, ${actors.owner}::uuid, 'published', 'Consequence fixture Project',
      'Synthetic local moderation verification', 'Synthetic local moderation verification',
      statement_timestamp() + interval '1 day', statement_timestamp() + interval '2 days',
      'Europe/Rome', 'IT', 'Trento', 'Trento', statement_timestamp())`;
  await sql`insert into public.proposal_meeting_details(proposal_id, exact_meeting_text, exact_location_visibility)
    values(${projectId}::uuid, 'Synthetic private meeting', 'participants')`;
  await sql`update public.projects set registration_capacity = 10 where id = ${projectId}::uuid`;
  for (const [role, authority] of [
    ["cocreator", "co_creator"],
    ["coorganizer", "co_organizer"],
  ]) {
    const invitationId = randomUUID();
    await sql`insert into public.project_delegate_invitations(id, project_id, owner_profile_id,
      token_digest, status, expires_at, accepted_at, accepted_by_profile_id, issuer_profile_id, requested_authority_role)
      values(${invitationId}::uuid, ${projectId}::uuid, ${actors.owner}::uuid,
        extensions.digest(${randomUUID()}, 'sha256'), 'accepted', statement_timestamp() + interval '7 days',
        statement_timestamp(), ${actors[role]}::uuid, ${actors.owner}::uuid, ${authority})`;
    await sql`insert into public.project_delegates(project_id, owner_profile_id, delegate_profile_id,
      invitation_id, granted_by_profile_id, initial_authority_role, authority_role)
      values(${projectId}::uuid, ${actors.owner}::uuid, ${actors[role]}::uuid,
        ${invitationId}::uuid, ${actors.owner}::uuid, ${authority}, ${authority})`;
  }
  const resourceOwner = actors.resourceOwner ?? actors.owner;
  await sql`insert into public.resource_listings(id, owner_profile_id, listing_mode, lifecycle_state,
    title, description, country_code, locality, public_location_label, published_at)
    values(${listingId}::uuid, ${resourceOwner}::uuid, 'exchange', 'published', 'Consequence fixture Resource',
      'Synthetic local moderation verification', 'IT', 'Trento', 'Trento', statement_timestamp())`;
  const cases = {};
  for (const kind of ["profile", "project", "resource_listing"]) {
    const id = randomUUID();
    await sql`insert into private.moderation_cases(id, state, subject_profile_id, target_kind,
      target_profile_id, target_project_id, project_context_id, target_resource_listing_id, resource_listing_context_id)
      values(${id}::uuid, 'under_review', ${kind === "profile" ? actors.requester : kind === "project" ? actors.owner : resourceOwner}::uuid, ${kind},
        ${kind === "profile" ? actors.requester : null}::uuid,
        ${kind === "project" ? projectId : null}::uuid, ${kind === "project" ? projectId : null}::uuid,
        ${kind === "resource_listing" ? listingId : null}::uuid, ${kind === "resource_listing" ? listingId : null}::uuid)`;
    cases[kind] = id;
  }
  return { ...actors, projectId, listingId, cases };
}

export async function asConsequenceActor(sql, actorId, operation) {
  return sql.begin(async (transaction) => {
    await transaction`set local role authenticated`;
    await transaction`select set_config('request.jwt.claim.sub', ${actorId}, true)`;
    return operation(transaction);
  });
}

export function applyConsequence(sql, fixture, type, resource = false) {
  const caseId =
    type === "interaction_restriction" || type === "safety_notice"
      ? fixture.cases.profile
      : fixture.cases[resource ? "resource_listing" : "project"];
  return sql`select public.apply_moderation_consequence(${fixture.moderator}::uuid, ${caseId}::uuid,
    ${type}, 'Synthetic affected-user reason', 'Synthetic private staff note') as id`;
}
