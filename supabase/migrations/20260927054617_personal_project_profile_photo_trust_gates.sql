-- 08A4A keeps photo audience user-controlled. Presence of any current
-- canonical photo satisfies trust-sensitive publication and join gates.
create function private.has_current_profile_photo(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_profile_id is not null
    and exists (
      select 1
      from public.profile_photos as photo
      where photo.profile_id = p_profile_id
    )
$$;

comment on function private.has_current_profile_photo(uuid) is
  'Returns whether the exact profile currently has canonical photo metadata; audience is deliberately irrelevant to trust-gate eligibility.';

-- Public Project visibility matches the canonical public detail boundaries:
-- published Proposals, plus published/paused/ended Tavoli.
create function private.is_project_publicly_viewable(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and (
        (
          project.project_kind = 'one_time'
          and exists (
            select 1
            from public.proposals as proposal
            where proposal.id = project.id
              and proposal.lifecycle_state = 'published'
          )
        )
        or (
          project.project_kind = 'recurring'
          and exists (
            select 1
            from public.recurring_activities as activity
            where activity.id = project.id
              and activity.lifecycle_state in ('published', 'paused', 'ended')
          )
        )
      )
  )
$$;

comment on function private.is_project_publicly_viewable(uuid) is
  'Matches the current public Proposal/Tavolo exact-detail lifecycle boundary for Project-context photo authorization.';

create function private.has_public_project_creator_photo_context(
  p_creator_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_creator_profile_id is not null
    and exists (
      select 1
      from public.projects as project
      where project.creator_profile_id = p_creator_profile_id
        and private.is_project_publicly_viewable(project.id)
    )
$$;

comment on function private.has_public_project_creator_photo_context(uuid) is
  'Returns whether a creator currently owns any Project whose canonical public detail is viewable; used only for exact current-object Storage delivery.';

create function public.can_read_public_project_creator_photo_object(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.object_path = p_object_path
      and private.has_public_project_creator_photo_context(photo.profile_id)
  )
$$;

comment on function public.can_read_public_project_creator_photo_object(text) is
  'Authorizes only a current canonical opaque photo path whose owner currently has a publicly viewable Project context.';

create function public.get_project_creator_profile_photo_for_viewer(
  p_project_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.projects as project
  join public.profile_photos as photo
    on photo.profile_id = project.creator_profile_id
  where project.id = p_project_id
    and (
      project.creator_profile_id = (select auth.uid())
      or private.is_project_publicly_viewable(project.id)
    )
$$;

comment on function public.get_project_creator_profile_photo_for_viewer(uuid) is
  'Returns zero or one current organizer photo for an exact Project when the caller owns it or its canonical public detail is viewable; audience and authorization reason remain private.';

-- A Storage request carries the exact object path but not a Project ID. For a
-- publicly viewable Project every anon/authenticated caller already qualifies
-- to call the context RPC, so this separate operation-filtered policy permits
-- only that creator's current canonical opaque path. Draft-only organizers,
-- replaced paths, unrelated interaction photos, and bucket listings remain
-- denied. Owners continue through the existing owner/generic viewer policies.
create policy "Public Project context can read canonical organizer photos"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'profile-photos'
  and storage.allow_any_operation(
    array['object.get_authenticated_info', 'object.get_authenticated']
  )
  and name ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
  and public.can_read_public_project_creator_photo_object(
    storage.objects.name
  )
);

create or replace function public.publish_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_profile(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null or proposal.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.lifecycle_state = 'published' then
    return proposal.id;
  end if;

  if proposal.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft proposal can be published.';
  end if;

  perform private.assert_proposal_publishable(p_proposal_id, false);

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  update public.proposals
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_proposal_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'proposal.published',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.published',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$$;

create or replace function public.publish_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_recurring_activity_profile(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'published' then
    return activity.id;
  end if;

  if activity.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft recurring activity can be published.';
  end if;

  perform private.assert_recurring_activity_publishable(p_recurring_activity_id);

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  update public.recurring_activities
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_recurring_activity_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'recurring_activity.published',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.published',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create or replace function public.request_to_join_project(
  p_expected_requester_profile_id uuid,
  p_project_id uuid,
  p_request_message text default null,
  p_skill_ids uuid[] default '{}'::uuid[],
  p_resource_need_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  project_record record;
  normalized_message text := nullif(btrim(p_request_message), '');
  normalized_skill_ids uuid[] := coalesce(p_skill_ids, '{}'::uuid[]);
  normalized_resource_need_ids uuid[] := coalesce(
    p_resource_need_ids,
    '{}'::uuid[]
  );
  locked_resource_need record;
  locked_resource_need_count integer := 0;
  new_request_id uuid;
begin
  if normalized_message is not null and char_length(normalized_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'A participation request message must contain at most 500 characters.';
  end if;

  if cardinality(normalized_skill_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A participation request may select at most 50 Project skills.';
  end if;

  if cardinality(normalized_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A participation request may select at most 50 Project resource needs.';
  end if;

  if exists (
    select 1
    from unnest(normalized_skill_ids) as selected(skill_id)
    where selected.skill_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill selections cannot contain null identifiers.';
  end if;

  if exists (
    select 1
    from unnest(normalized_resource_need_ids) as selected(resource_need_id)
    where selected.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource selections cannot contain null identifiers.';
  end if;

  if cardinality(normalized_skill_ids) <> (
    select count(distinct selected.skill_id)
    from unnest(normalized_skill_ids) as selected(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill selections cannot contain duplicate identifiers.';
  end if;

  if cardinality(normalized_resource_need_ids) <> (
    select count(distinct selected.resource_need_id)
    from unnest(normalized_resource_need_ids) as selected(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource selections cannot contain duplicate identifiers.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(p_project_id, true);

  if project_record.creator_profile_id = current_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A project creator cannot request to join their own project.';
  end if;

  if exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.participant_profile_id = current_profile_id
      and membership.left_at is null
      and membership.removed_at is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester is already a current project participant.';
  end if;

  if exists (
    select 1
    from public.project_join_requests as request
    where request.project_id = p_project_id
      and request.requester_profile_id = current_profile_id
      and request.status = 'pending'
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester already has a pending request for this project.';
  end if;

  if project_record.project_kind = 'recurring'
    and cardinality(normalized_skill_ids) > 0 then
    raise exception using
      errcode = '22023',
      message = 'Recurring Projects do not currently define selectable skill requirements.';
  end if;

  if project_record.project_kind = 'one_time'
    and exists (
      select 1
      from unnest(normalized_skill_ids) as selected(skill_id)
      left join public.proposal_skills as requested_skill
        on requested_skill.proposal_id = p_project_id
        and requested_skill.skill_id = selected.skill_id
      where requested_skill.skill_id is null
    ) then
    raise exception using
      errcode = '22023',
      message = 'Every selected skill must be a current requirement of this Proposal.';
  end if;

  -- The participation helper already holds concrete Project then shared Project.
  -- Lock resource rows in UUID order after those anchors so 04C3A update/close
  -- operations serialize without reversing the established lock hierarchy.
  for locked_resource_need in
    select need.id, need.project_id, need.state
    from public.project_resource_needs as need
    where need.id = any(normalized_resource_need_ids)
    order by need.id
    for share
  loop
    locked_resource_need_count := locked_resource_need_count + 1;

    if locked_resource_need.project_id <> p_project_id
      or locked_resource_need.state <> 'open' then
      raise exception using
        errcode = '22023',
        message = 'Every selected resource need must be open and belong to this Project.';
    end if;
  end loop;

  if locked_resource_need_count <> cardinality(normalized_resource_need_ids) then
    raise exception using
      errcode = '22023',
      message = 'Every selected resource need must be open and belong to this Project.';
  end if;

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  insert into public.project_join_requests (
    project_id,
    requester_profile_id,
    request_message
  )
  values (p_project_id, current_profile_id, normalized_message)
  returning id into new_request_id;

  insert into public.project_join_request_skill_selections (
    request_id,
    skill_id
  )
  select new_request_id, selected.skill_id
  from unnest(normalized_skill_ids) as selected(skill_id);

  insert into public.project_join_request_resource_selections (
    request_id,
    resource_need_id
  )
  select new_request_id, selected.resource_need_id
  from unnest(normalized_resource_need_ids) as selected(resource_need_id);

  perform private.record_project_participation_event(
    'project.join_requested',
    current_profile_id,
    p_project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'request_id', new_request_id,
      'requester_profile_id', current_profile_id,
      'status', 'pending'
    )
  );

  return new_request_id;
end;
$$;

revoke all privileges on function private.has_current_profile_photo(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.is_project_publicly_viewable(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.has_public_project_creator_photo_context(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.can_read_public_project_creator_photo_object(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_project_creator_profile_photo_for_viewer(uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.publish_proposal(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.publish_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;

grant execute on function public.get_project_creator_profile_photo_for_viewer(uuid)
  to anon, authenticated;
grant execute on function public.can_read_public_project_creator_photo_object(text)
  to anon, authenticated;
grant execute on function public.publish_proposal(uuid, uuid)
  to authenticated;
grant execute on function public.publish_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) to authenticated;

comment on function public.publish_proposal(uuid, uuid) is
  'Validates and idempotently publishes an own draft; the actual draft-to-published transition requires a current canonical profile photo.';
comment on function public.publish_recurring_activity(uuid, uuid) is
  'Validates and idempotently publishes an own recurring draft; the actual draft-to-published transition requires a current canonical profile photo.';
comment on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) is
  'Atomically creates one private pending join request with optional canonical contribution selections; every new request requires a current canonical requester photo.';
