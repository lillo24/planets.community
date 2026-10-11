-- GRP01 reporting delta: genuine typed targets in the existing manual-review queue.
alter table private.moderation_cases
  add column target_group_id uuid references private.community_groups(id) on delete restrict,
  add column group_report_version bigint,
  add constraint moderation_cases_group_version_valid check (
    (target_kind = 'group' and group_report_version is not null and group_report_version > 0)
    or (target_kind <> 'group' and group_report_version is null));
create index moderation_cases_group_idx on private.moderation_cases(target_group_id) where target_group_id is not null;
alter table private.moderation_cases drop constraint moderation_cases_target_kind_valid, add constraint moderation_cases_target_kind_valid check (
      target_kind in (
        'group',
        'proposal_template',
        'profile',
        'project',
        'project_chat_message',
        'resource_listing',
        'resource_request',
        'resource_chat_message'
      )
    );
alter table private.moderation_cases drop constraint moderation_cases_one_typed_target, add constraint moderation_cases_one_typed_target check (
    num_nonnulls(
      target_group_id,
      target_proposal_template_id,
      target_profile_id,
      target_project_id,
      target_project_chat_message_id,
      target_resource_listing_id,
      target_resource_request_id,
      target_resource_chat_message_id
    ) = 1
  );
alter table private.moderation_cases drop constraint moderation_cases_target_shape_valid, add constraint moderation_cases_target_shape_valid check (
    case target_kind
      when 'group' then target_group_id is not null
      when 'proposal_template' then target_proposal_template_id is not null
      when 'profile' then target_profile_id is not null
      when 'project' then target_project_id is not null
      when 'project_chat_message' then
        target_project_chat_message_id is not null
      when 'resource_listing' then target_resource_listing_id is not null
      when 'resource_request' then target_resource_request_id is not null
      when 'resource_chat_message' then
        target_resource_chat_message_id is not null
      else false
    end
  );
alter table private.moderation_cases drop constraint moderation_cases_context_shape_valid, add constraint moderation_cases_context_shape_valid check (
    case target_kind
      when 'group' then num_nonnulls(project_context_id, resource_listing_context_id, resource_request_context_id, resource_chat_context_id) = 0
      when 'proposal_template' then num_nonnulls(project_context_id, resource_listing_context_id, resource_request_context_id, resource_chat_context_id) = 0
      when 'profile' then
        (
          num_nonnulls(
            project_context_id,
            resource_listing_context_id,
            resource_request_context_id,
            resource_chat_context_id
          ) = 0
        )
        or (
          project_context_id is not null
          and num_nonnulls(
            resource_listing_context_id,
            resource_request_context_id,
            resource_chat_context_id
          ) = 0
        )
        or (
          project_context_id is null
          and resource_listing_context_id is not null
          and resource_request_context_id is not null
        )
      when 'project' then
        project_context_id = target_project_id
        and num_nonnulls(
          resource_listing_context_id,
          resource_request_context_id,
          resource_chat_context_id
        ) = 0
      when 'project_chat_message' then
        project_context_id is not null
        and num_nonnulls(
          resource_listing_context_id,
          resource_request_context_id,
          resource_chat_context_id
        ) = 0
      when 'resource_listing' then
        resource_listing_context_id = target_resource_listing_id
        and project_context_id is null
        and resource_request_context_id is null
        and resource_chat_context_id is null
      when 'resource_request' then
        resource_request_context_id = target_resource_request_id
        and resource_listing_context_id is not null
        and project_context_id is null
        and resource_chat_context_id is null
      when 'resource_chat_message' then
        resource_listing_context_id is not null
        and resource_request_context_id is not null
        and resource_chat_context_id is not null
        and project_context_id is null
      else false
    end
  );

create or replace function private.protect_moderation_case_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id <> old.id
    or new.subject_profile_id is distinct from old.subject_profile_id
    or new.target_kind <> old.target_kind
    or new.target_profile_id is distinct from old.target_profile_id
    or new.target_project_id is distinct from old.target_project_id
    or new.target_project_chat_message_id
      is distinct from old.target_project_chat_message_id
    or new.target_resource_listing_id
      is distinct from old.target_resource_listing_id
    or new.target_resource_request_id
      is distinct from old.target_resource_request_id
    or new.target_resource_chat_message_id
      is distinct from old.target_resource_chat_message_id
    or new.project_context_id is distinct from old.project_context_id
    or new.resource_listing_context_id
      is distinct from old.resource_listing_context_id
    or new.resource_request_context_id
      is distinct from old.resource_request_context_id
    or new.resource_chat_context_id
      is distinct from old.resource_chat_context_id
    or new.target_proposal_template_id is distinct from old.target_proposal_template_id
    or new.template_source_proposal_id is distinct from old.template_source_proposal_id
    or new.template_report_content_version is distinct from old.template_report_content_version
    or new.target_group_id is distinct from old.target_group_id
    or new.group_report_version is distinct from old.group_report_version
    or new.created_at <> old.created_at then
    raise exception using
      errcode = '55000',
      message = 'Moderation case target identity is immutable.';
  end if;

  return new;
end;
$$;

create or replace function private.moderation_target_summary(
  p_case private.moderation_cases
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case p_case.target_kind
    when 'group' then 'Group'
    when 'proposal_template' then 'Proposal template'
    when 'profile' then coalesce(
      (select profile.display_name
       from public.profiles as profile
       where profile.id = p_case.target_profile_id),
      'Profile'
    )
    when 'project' then coalesce(
      (select proposal.title
       from public.proposals as proposal
       where proposal.id = p_case.target_project_id),
      (select activity.title
       from public.recurring_activities as activity
       where activity.id = p_case.target_project_id),
      'Project'
    )
    when 'project_chat_message' then 'Project chat message'
    when 'resource_listing' then coalesce(
      (select listing.title
       from public.resource_listings as listing
       where listing.id = p_case.target_resource_listing_id),
      'Resource listing'
    )
    when 'resource_request' then 'Resource request'
    when 'resource_chat_message' then 'Resource conversation message'
  end;
$$;

create or replace function public.submit_moderation_report(
  p_expected_reporter_profile_id uuid,
  p_client_submission_id uuid,
  p_category text,
  p_explanation text,
  p_target_kind text,
  p_target_id uuid,
  p_context_kind text default null,
  p_context_id uuid default null
)
returns table (
  report_id uuid,
  case_id uuid,
  state text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter_id uuid := private.require_moderation_identity(
    p_expected_reporter_profile_id,
    true
  );
  normalized_explanation text := regexp_replace(
    coalesce(p_explanation, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  existing_report record;
  template_record private.proposal_templates%rowtype;
  group_record private.community_groups%rowtype;
  template_content jsonb;
  target_subject_id uuid;
  target_profile_id uuid;
  target_project_id uuid;
  target_project_message_id uuid;
  target_listing_id uuid;
  target_request_id uuid;
  target_resource_message_id uuid;
  project_context_id uuid;
  listing_context_id uuid;
  request_context_id uuid;
  chat_context_id uuid;
  project_record public.projects%rowtype;
  project_message_record public.project_chat_messages%rowtype;
  resource_message_record public.resource_request_chat_messages%rowtype;
  request_record public.resource_listing_requests%rowtype;
  listing_record public.resource_listings%rowtype;
  resource_chat_record public.resource_request_chats%rowtype;
  new_case private.moderation_cases%rowtype;
  new_report private.moderation_reports%rowtype;
begin
  if p_client_submission_id is null
    or p_target_id is null
    or p_target_kind is null
    or p_category not in (
      'safety_concern',
      'harassment_abuse',
      'fraud_scam',
      'inappropriate_content_conduct',
      'spam',
      'other'
    ) then
    raise exception using
      errcode = '22023',
      message = 'The report request is invalid.';
  end if;

  if (p_context_kind is null) <> (p_context_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Report context kind and identifier must be provided together.';
  end if;

  if char_length(normalized_explanation) not between 10 and 4000 then
    raise exception using
      errcode = '22023',
      message = 'The report explanation must contain between 10 and 4,000 characters.';
  end if;

  -- Serialize identity-bound deliveries before target resolution, including retry
  -- after removal. The namespace is separate from Project/profile locks.
  perform pg_advisory_xact_lock(hashtextextended(
    'moderation.report:' || reporter_id::text || ':' || p_client_submission_id::text, 0));

  select
    report.id,
    report.case_id,
    moderation_case.state,
    report.created_at, report.category, report.explanation,
    moderation_case.target_kind,
    moderation_case.target_proposal_template_id,
    moderation_case.target_group_id
  into existing_report
  from private.moderation_reports as report
  join private.moderation_cases as moderation_case
    on moderation_case.id = report.case_id
  where report.reporter_profile_id = reporter_id
    and report.client_submission_id = p_client_submission_id;

  if found then
    -- Legacy report kinds retain their existing retry contract. Template/group keys
    -- cannot be reused for changed text/category/target or incident context.
    if (p_target_kind in ('proposal_template','group') or existing_report.target_kind in ('proposal_template','group'))
      and (existing_report.target_kind is distinct from p_target_kind
        or (case existing_report.target_kind when 'group' then existing_report.target_group_id else existing_report.target_proposal_template_id end) is distinct from p_target_id
        or existing_report.category is distinct from p_category
        or existing_report.explanation is distinct from normalized_explanation
        or p_context_kind is not null or p_context_id is not null) then
      raise exception using errcode = '22023', message = case when p_target_kind = 'group' or existing_report.target_kind = 'group'
        then 'The group report retry key has incompatible inputs.' else 'The template report retry key has incompatible inputs.' end;
    end if;
    return query select
      existing_report.id,
      existing_report.case_id,
      existing_report.state,
      existing_report.created_at;
    return;
  end if;

  case p_target_kind
    when 'group' then
      if p_context_kind is not null then
        raise exception using errcode = '22023', message = 'Group reports have no Project or Resource incident context.';
      end if;
      select * into group_record from private.community_groups where id = p_target_id for update;
      if group_record.id is null or not private.group_is_public(p_target_id) then
        raise exception using errcode = '42501', message = 'The report target is unavailable.';
      end if;
      select profile_id into target_subject_id from private.community_group_managers where group_id = p_target_id;
    when 'proposal_template' then
      if p_context_kind is not null then
        raise exception using errcode = '22023', message = 'Template provenance is not incident context.';
      end if;
      select * into template_record from private.proposal_templates where id = p_target_id;
      if not found then
        raise exception using errcode = '42501', message = 'The report target is unavailable.';
      end if;
      -- Source mutations already take the Proposal lock. Use the same order as
      -- removal/future copy, so eligibility and report token come from one state.
      perform 1 from public.proposals where id = template_record.source_proposal_id for update;
      select * into template_record from private.proposal_templates where id = p_target_id for update;
      if private.is_proposal_template_publicly_usable(p_target_id, clock_timestamp()) is not true then
        raise exception using errcode = '42501', message = 'The report target is unavailable.';
      end if;
      template_content := private.workshop_template_content(template_record.id);
      target_subject_id := template_record.original_creator_profile_id;
    when 'profile'  then
      select profile.id into target_subject_id
      from public.profiles as profile
      where profile.id = p_target_id
        and profile.display_name is not null;

      if not found then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_profile_id := p_target_id;

      if p_context_kind = 'project' then
        select * into project_record
        from public.projects as project
        where project.id = p_context_id;

        if not found
          or not private.profile_has_project_association(
            project_record.id,
            reporter_id
          )
          or not private.profile_has_project_association(
            project_record.id,
            target_subject_id
          ) then
          raise exception using
            errcode = '42501',
            message = 'The report target is unavailable.';
        end if;
        project_context_id := project_record.id;
      elsif p_context_kind = 'resource_request' then
        select * into request_record
        from public.resource_listing_requests as request
        where request.id = p_context_id;
        select * into listing_record
        from public.resource_listings as listing
        where listing.id = request_record.listing_id;

        if request_record.id is null
          or listing_record.id is null
          or reporter_id not in (
            listing_record.owner_profile_id,
            request_record.requester_profile_id
          )
          or target_subject_id not in (
            listing_record.owner_profile_id,
            request_record.requester_profile_id
          )
          or target_subject_id = reporter_id then
          raise exception using
            errcode = '42501',
            message = 'The report target is unavailable.';
        end if;

        listing_context_id := listing_record.id;
        request_context_id := request_record.id;
        select chat.id into chat_context_id
        from public.resource_request_chats as chat
        where chat.request_id = request_record.id;
      elsif p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'The report context is invalid for this target.';
      elsif not exists (
        select 1
        from public.profile_field_visibility as visibility
        where visibility.profile_id = target_subject_id
          and visibility.field_key = 'display_name'
          and visibility.audience = 'public'
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

    when 'project' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Project reports derive their canonical context.';
      end if;

      select * into project_record
      from public.projects as project
      where project.id = p_target_id;

      if not found or (
        not private.profile_has_project_association(p_target_id, reporter_id)
        and not exists (
          select 1 from public.proposals as proposal
          where proposal.id = p_target_id
            and proposal.lifecycle_state = 'published'
          union all
          select 1 from public.recurring_activities as activity
          where activity.id = p_target_id
            and activity.lifecycle_state = 'published'
        )
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := project_record.creator_profile_id;
      target_project_id := project_record.id;
      project_context_id := project_record.id;

    when 'project_chat_message' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Project message reports derive their canonical context.';
      end if;

      select message.* into project_message_record
      from public.project_chat_messages as message
      where message.id = p_target_id;

      select project.* into project_record
      from public.project_group_chats as chat
      join public.projects as project on project.id = chat.project_id
      where chat.id = project_message_record.chat_id;

      if project_message_record.id is null
        or project_record.id is null
        or private.profile_can_read_project_chat_message(
          project_record.id,
          reporter_id,
          project_message_record.created_at
        ) is not true then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := project_message_record.sender_profile_id;
      target_project_message_id := project_message_record.id;
      project_context_id := project_record.id;

    when 'resource_listing' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource listing reports derive their canonical context.';
      end if;

      select * into listing_record
      from public.resource_listings as listing
      where listing.id = p_target_id;

      if not found or (
        listing_record.lifecycle_state <> 'published'
        and not exists (
          select 1
          from public.resource_listing_requests as request
          where request.listing_id = listing_record.id
            and request.requester_profile_id = reporter_id
        )
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := listing_record.owner_profile_id;
      target_listing_id := listing_record.id;
      listing_context_id := listing_record.id;

    when 'resource_request' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource request reports derive their canonical context.';
      end if;

      select * into request_record
      from public.resource_listing_requests as request
      where request.id = p_target_id;
      select * into listing_record
      from public.resource_listings as listing
      where listing.id = request_record.listing_id;

      if request_record.id is null
        or listing_record.id is null
        or reporter_id not in (
          listing_record.owner_profile_id,
          request_record.requester_profile_id
        ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := case
        when reporter_id = listing_record.owner_profile_id
          then request_record.requester_profile_id
        else listing_record.owner_profile_id
      end;
      target_request_id := request_record.id;
      listing_context_id := listing_record.id;
      request_context_id := request_record.id;

    when 'resource_chat_message' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource message reports derive their canonical context.';
      end if;

      select message.* into resource_message_record
      from public.resource_request_chat_messages as message
      where message.id = p_target_id;
      select * into resource_chat_record
      from public.resource_request_chats as chat
      where chat.id = resource_message_record.chat_id;
      select * into request_record
      from public.resource_listing_requests as request
      where request.id = resource_chat_record.request_id;
      select * into listing_record
      from public.resource_listings as listing
      where listing.id = request_record.listing_id;

      if resource_message_record.id is null
        or resource_chat_record.id is null
        or request_record.id is null
        or listing_record.id is null
        or reporter_id not in (
          listing_record.owner_profile_id,
          request_record.requester_profile_id
        ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := resource_message_record.sender_profile_id;
      target_resource_message_id := resource_message_record.id;
      listing_context_id := listing_record.id;
      request_context_id := request_record.id;
      chat_context_id := resource_chat_record.id;

    else
      raise exception using
        errcode = '22023',
        message = 'The report target kind is unsupported.';
  end case;

  if target_subject_id = reporter_id and p_target_kind <> 'proposal_template' then
    raise exception using
      errcode = '22023',
      message = 'A profile cannot report itself.';
  end if;

  insert into private.moderation_cases (
    target_group_id,
    group_report_version,
    target_proposal_template_id,
    template_source_proposal_id,
    template_report_content_version,
    subject_profile_id,
    target_kind,
    target_profile_id,
    target_project_id,
    target_project_chat_message_id,
    target_resource_listing_id,
    target_resource_request_id,
    target_resource_chat_message_id,
    project_context_id,
    resource_listing_context_id,
    resource_request_context_id,
    resource_chat_context_id
  )
  values (
    group_record.id,
    group_record.version,
    template_record.id,
    template_record.source_proposal_id,
    case when template_record.id is not null then private.proposal_template_content_version(template_content) end,
    target_subject_id,
    p_target_kind,
    target_profile_id,
    target_project_id,
    target_project_message_id,
    target_listing_id,
    target_request_id,
    target_resource_message_id,
    project_context_id,
    listing_context_id,
    request_context_id,
    chat_context_id
  )
  returning * into new_case;

  insert into private.moderation_reports (
    case_id,
    reporter_profile_id,
    client_submission_id,
    category,
    explanation,
    created_at
  )
  values (
    new_case.id,
    reporter_id,
    p_client_submission_id,
    p_category,
    normalized_explanation,
    new_case.created_at
  )
  returning * into new_report;

  insert into private.moderation_case_events (
    case_id,
    actor_profile_id,
    event_kind,
    to_state,
    state_version,
    created_at
  )
  values (
    new_case.id,
    reporter_id,
    'report_received',
    'received',
    0,
    new_case.created_at
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.report_submitted',
    reporter_id,
    'moderation_case',
    new_case.id,
    jsonb_build_object(
      'case_id', new_case.id,
      'report_id', new_report.id,
      'target_kind', new_case.target_kind
    ),
    new_case.created_at
  );

  return query select
    new_report.id,
    new_case.id,
    new_case.state,
    new_report.created_at;
end;
$$;

-- The report-time version is immutable evidence of which page revision was seen;
-- ordinary manual review and directory suppression remain independent actions.
create function public.get_moderation_case_group(p_expected_staff_profile_id uuid,p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target uuid; report_version bigint; context jsonb;
begin
  perform private.require_group_actor(p_expected_staff_profile_id);
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select target_group_id,group_report_version into target,report_version from private.moderation_cases where id=p_case_id and target_kind='group';
  if target is null then raise exception using errcode='42501',message='The group case is unavailable.'; end if;
  context := public.get_group_staff_context(p_expected_staff_profile_id,target);
  return context || jsonb_build_object('report_version',report_version,'content_changed',(context->>'version')::bigint<>report_version);
end;
$$;
revoke all on function public.get_moderation_case_group(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_moderation_case_group(uuid,uuid) to authenticated;
-- CREATE OR REPLACE preserves the existing explicit RPC/helper grants.
comment on column private.moderation_cases.target_group_id is
  'Canonical registered group target, distinct from a personal Profile or Project group chat.';
comment on function public.get_moderation_case_group(uuid,uuid) is
  'Active staff inspection of current group content and private suppression context, with immutable report-time version comparison.';
