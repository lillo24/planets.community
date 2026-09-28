create table private.moderation_staff_roles (
  profile_id uuid primary key
    constraint moderation_staff_roles_profile_id_fkey
      references public.profiles (id) on delete restrict,
  staff_role text not null
    constraint moderation_staff_roles_role_valid check (
      staff_role in ('moderator', 'admin')
    ),
  is_active boolean not null default true,
  granted_at timestamptz not null default statement_timestamp(),
  deactivated_at timestamptz,
  constraint moderation_staff_roles_activation_valid check (
    (is_active and deactivated_at is null)
    or (not is_active and deactivated_at is not null
      and deactivated_at >= granted_at)
  )
);

comment on table private.moderation_staff_roles is
  'Operator-managed moderation authorization. It is outside the Data API and has no client role-assignment path.';

create index moderation_staff_roles_active_role_idx
  on private.moderation_staff_roles (staff_role, profile_id)
  where is_active;

create table private.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  state text not null default 'received'
    constraint moderation_cases_state_valid check (
      state in ('received', 'under_review', 'completed')
    ),
  state_version bigint not null default 0
    constraint moderation_cases_state_version_valid check (
      state_version >= 0
    ),
  subject_profile_id uuid not null
    constraint moderation_cases_subject_profile_id_fkey
      references public.profiles (id) on delete restrict,
  target_kind text not null
    constraint moderation_cases_target_kind_valid check (
      target_kind in (
        'profile',
        'project',
        'project_chat_message',
        'resource_listing',
        'resource_request',
        'resource_chat_message'
      )
    ),
  target_profile_id uuid
    constraint moderation_cases_target_profile_id_fkey
      references public.profiles (id) on delete restrict,
  target_project_id uuid
    constraint moderation_cases_target_project_id_fkey
      references public.projects (id) on delete restrict,
  target_project_chat_message_id uuid
    constraint moderation_cases_target_project_chat_message_id_fkey
      references public.project_chat_messages (id) on delete restrict,
  target_resource_listing_id uuid
    constraint moderation_cases_target_resource_listing_id_fkey
      references public.resource_listings (id) on delete restrict,
  target_resource_request_id uuid
    constraint moderation_cases_target_resource_request_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  target_resource_chat_message_id uuid
    constraint moderation_cases_target_resource_chat_message_id_fkey
      references public.resource_request_chat_messages (id) on delete restrict,
  project_context_id uuid
    constraint moderation_cases_project_context_id_fkey
      references public.projects (id) on delete restrict,
  resource_listing_context_id uuid
    constraint moderation_cases_resource_listing_context_id_fkey
      references public.resource_listings (id) on delete restrict,
  resource_request_context_id uuid
    constraint moderation_cases_resource_request_context_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  resource_chat_context_id uuid
    constraint moderation_cases_resource_chat_context_id_fkey
      references public.resource_request_chats (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  constraint moderation_cases_one_typed_target check (
    num_nonnulls(
      target_profile_id,
      target_project_id,
      target_project_chat_message_id,
      target_resource_listing_id,
      target_resource_request_id,
      target_resource_chat_message_id
    ) = 1
  ),
  constraint moderation_cases_target_shape_valid check (
    case target_kind
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
  ),
  constraint moderation_cases_context_shape_valid check (
    case target_kind
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
  ),
  constraint moderation_cases_completion_valid check (
    (state = 'completed' and completed_at is not null)
    or (state <> 'completed' and completed_at is null)
  )
);

comment on table private.moderation_cases is
  'Private manual-review cases with typed canonical targets and contexts. A case has no automatic product consequence.';
comment on column private.moderation_cases.project_context_id is
  'Canonical Project association for later corroboration eligibility; membership history is not proof of physical attendance.';

create index moderation_cases_created_at_id_idx
  on private.moderation_cases (created_at desc, id desc);
create index moderation_cases_state_created_at_id_idx
  on private.moderation_cases (state, created_at desc, id desc);
create index moderation_cases_subject_created_at_id_idx
  on private.moderation_cases (subject_profile_id, created_at desc, id desc);
create index moderation_cases_target_profile_id_idx
  on private.moderation_cases (target_profile_id)
  where target_profile_id is not null;
create index moderation_cases_target_project_id_idx
  on private.moderation_cases (target_project_id)
  where target_project_id is not null;
create index moderation_cases_target_project_message_id_idx
  on private.moderation_cases (target_project_chat_message_id)
  where target_project_chat_message_id is not null;
create index moderation_cases_target_resource_listing_id_idx
  on private.moderation_cases (target_resource_listing_id)
  where target_resource_listing_id is not null;
create index moderation_cases_target_resource_request_id_idx
  on private.moderation_cases (target_resource_request_id)
  where target_resource_request_id is not null;
create index moderation_cases_target_resource_message_id_idx
  on private.moderation_cases (target_resource_chat_message_id)
  where target_resource_chat_message_id is not null;
create index moderation_cases_project_context_id_idx
  on private.moderation_cases (project_context_id)
  where project_context_id is not null;
create index moderation_cases_resource_listing_context_id_idx
  on private.moderation_cases (resource_listing_context_id)
  where resource_listing_context_id is not null;
create index moderation_cases_resource_request_context_id_idx
  on private.moderation_cases (resource_request_context_id)
  where resource_request_context_id is not null;
create index moderation_cases_resource_chat_context_id_idx
  on private.moderation_cases (resource_chat_context_id)
  where resource_chat_context_id is not null;

create table private.moderation_reports (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null unique
    constraint moderation_reports_case_id_fkey
      references private.moderation_cases (id) on delete restrict,
  reporter_profile_id uuid not null
    constraint moderation_reports_reporter_profile_id_fkey
      references public.profiles (id) on delete restrict,
  client_submission_id uuid not null,
  category text not null
    constraint moderation_reports_category_valid check (
      category in (
        'safety_concern',
        'harassment_abuse',
        'fraud_scam',
        'inappropriate_content_conduct',
        'spam',
        'other'
      )
    ),
  explanation text not null
    constraint moderation_reports_explanation_valid check (
      explanation = regexp_replace(
        explanation,
        '^[[:space:]]+|[[:space:]]+$',
        '',
        'g'
      )
      and char_length(explanation) between 10 and 4000
    ),
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_reports_reporter_submission_key
    unique (reporter_profile_id, client_submission_id)
);

comment on table private.moderation_reports is
  'Immutable initial reporter evidence. Explanation text stays here and is never copied into generic audit/outbox metadata.';
comment on column private.moderation_reports.client_submission_id is
  'Opaque client-generated retry key scoped to one reporter; a new incident uses a new key.';

create index moderation_reports_reporter_created_at_id_idx
  on private.moderation_reports (
    reporter_profile_id,
    created_at desc,
    id desc
  );

create table private.moderation_case_notes (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    constraint moderation_case_notes_case_id_fkey
      references private.moderation_cases (id) on delete restrict,
  author_profile_id uuid not null
    constraint moderation_case_notes_author_profile_id_fkey
      references public.profiles (id) on delete restrict,
  body text not null
    constraint moderation_case_notes_body_valid check (
      body = regexp_replace(
        body,
        '^[[:space:]]+|[[:space:]]+$',
        '',
        'g'
      )
      and char_length(body) between 1 and 4000
    ),
  created_at timestamptz not null default statement_timestamp()
);

comment on table private.moderation_case_notes is
  'Append-only staff evidence. Note bodies are visible only through staff-authorized case detail.';

create index moderation_case_notes_case_created_at_id_idx
  on private.moderation_case_notes (case_id, created_at, id);
create index moderation_case_notes_author_created_at_id_idx
  on private.moderation_case_notes (
    author_profile_id,
    created_at desc,
    id desc
  );

create table private.moderation_case_events (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    constraint moderation_case_events_case_id_fkey
      references private.moderation_cases (id) on delete restrict,
  actor_profile_id uuid not null
    constraint moderation_case_events_actor_profile_id_fkey
      references public.profiles (id) on delete restrict,
  event_kind text not null
    constraint moderation_case_events_kind_valid check (
      event_kind in ('report_received', 'state_changed', 'note_added')
    ),
  from_state text
    constraint moderation_case_events_from_state_valid check (
      from_state is null
      or from_state in ('received', 'under_review', 'completed')
    ),
  to_state text
    constraint moderation_case_events_to_state_valid check (
      to_state is null
      or to_state in ('received', 'under_review', 'completed')
    ),
  state_version bigint not null
    constraint moderation_case_events_state_version_valid check (
      state_version >= 0
    ),
  note_id uuid
    constraint moderation_case_events_note_id_fkey
      references private.moderation_case_notes (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_case_events_shape_valid check (
    (event_kind = 'report_received'
      and from_state is null and to_state = 'received' and note_id is null)
    or (event_kind = 'state_changed'
      and from_state is not null and to_state is not null
      and from_state <> to_state and note_id is null)
    or (event_kind = 'note_added'
      and from_state is null and to_state is null and note_id is not null)
  )
);

comment on table private.moderation_case_events is
  'Identifier-only domain chronology for review state and note creation. Sensitive bodies remain in report/note records.';

create index moderation_case_events_case_created_at_id_idx
  on private.moderation_case_events (case_id, created_at, id);
create index moderation_case_events_actor_created_at_id_idx
  on private.moderation_case_events (
    actor_profile_id,
    created_at desc,
    id desc
  );

alter table private.moderation_staff_roles enable row level security;
alter table private.moderation_cases enable row level security;
alter table private.moderation_reports enable row level security;
alter table private.moderation_case_notes enable row level security;
alter table private.moderation_case_events enable row level security;

revoke all privileges on table private.moderation_staff_roles
  from public, anon, authenticated, service_role;
revoke all privileges on table private.moderation_cases
  from public, anon, authenticated, service_role;
revoke all privileges on table private.moderation_reports
  from public, anon, authenticated, service_role;
revoke all privileges on table private.moderation_case_notes
  from public, anon, authenticated, service_role;
revoke all privileges on table private.moderation_case_events
  from public, anon, authenticated, service_role;

create function private.protect_moderation_append_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Moderation evidence and chronology are append-only.';
end;
$$;

create trigger moderation_reports_append_only
before update or delete on private.moderation_reports
for each row execute function private.protect_moderation_append_only();

create trigger moderation_case_notes_append_only
before update or delete on private.moderation_case_notes
for each row execute function private.protect_moderation_append_only();

create trigger moderation_case_events_append_only
before update or delete on private.moderation_case_events
for each row execute function private.protect_moderation_append_only();

create function private.protect_moderation_case_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id <> old.id
    or new.subject_profile_id <> old.subject_profile_id
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
    or new.created_at <> old.created_at then
    raise exception using
      errcode = '55000',
      message = 'Moderation case target identity is immutable.';
  end if;

  return new;
end;
$$;

create trigger moderation_cases_protect_identity
before update on private.moderation_cases
for each row execute function private.protect_moderation_case_identity();

create function private.require_moderation_identity(
  p_expected_profile_id uuid,
  p_require_complete boolean default true
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  current_display_name text;
begin
  if current_profile_id is null
    or p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The moderation identity is unavailable.';
  end if;

  select profile.display_name into current_display_name
  from public.profiles as profile
  where profile.id = current_profile_id;

  if not found or (p_require_complete and current_display_name is null) then
    raise exception using
      errcode = '42501',
      message = 'The moderation identity is unavailable.';
  end if;

  return current_profile_id;
end;
$$;

create function private.require_moderation_staff(
  p_expected_profile_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_moderation_identity(
    p_expected_profile_id,
    true
  );
  staff_role_value text;
begin
  select staff.staff_role into staff_role_value
  from private.moderation_staff_roles as staff
  where staff.profile_id = current_profile_id
    and staff.is_active;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'Moderation staff access is required.';
  end if;

  return staff_role_value;
end;
$$;

create function private.profile_has_project_association(
  p_project_id uuid,
  p_profile_id uuid
)
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
        project.creator_profile_id = p_profile_id
        or exists (
          select 1
          from public.project_memberships as membership
          where membership.project_id = project.id
            and membership.participant_profile_id = p_profile_id
        )
      )
  );
$$;

create function private.moderation_target_summary(
  p_case private.moderation_cases
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case p_case.target_kind
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

create function private.moderation_context_summary(
  p_case private.moderation_cases
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_case.project_context_id is not null then coalesce(
      (select proposal.title
       from public.proposals as proposal
       where proposal.id = p_case.project_context_id),
      (select activity.title
       from public.recurring_activities as activity
       where activity.id = p_case.project_context_id),
      'Project activity'
    )
    when p_case.resource_listing_context_id is not null then coalesce(
      (select listing.title
       from public.resource_listings as listing
       where listing.id = p_case.resource_listing_context_id),
      'Scambio-Dona interaction'
    )
    else null
  end;
$$;

create function public.submit_moderation_report(
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

  select
    report.id,
    report.case_id,
    moderation_case.state,
    report.created_at
  into existing_report
  from private.moderation_reports as report
  join private.moderation_cases as moderation_case
    on moderation_case.id = report.case_id
  where report.reporter_profile_id = reporter_id
    and report.client_submission_id = p_client_submission_id;

  if found then
    return query select
      existing_report.id,
      existing_report.case_id,
      existing_report.state,
      existing_report.created_at;
    return;
  end if;

  case p_target_kind
    when 'profile' then
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

  if target_subject_id = reporter_id then
    raise exception using
      errcode = '22023',
      message = 'A profile cannot report itself.';
  end if;

  insert into private.moderation_cases (
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
exception
  when unique_violation then
    select
      report.id,
      report.case_id,
      moderation_case.state,
      report.created_at
    into existing_report
    from private.moderation_reports as report
    join private.moderation_cases as moderation_case
      on moderation_case.id = report.case_id
    where report.reporter_profile_id = reporter_id
      and report.client_submission_id = p_client_submission_id;

    if found then
      return query select
        existing_report.id,
        existing_report.case_id,
        existing_report.state,
        existing_report.created_at;
      return;
    end if;
    raise;
end;
$$;

create function public.list_own_moderation_reports(
  p_expected_reporter_profile_id uuid,
  p_limit integer default 20,
  p_before_created_at timestamptz default null,
  p_before_report_id uuid default null
)
returns table (
  report_id uuid,
  case_id uuid,
  category text,
  explanation text,
  target_kind text,
  target_summary text,
  context_summary text,
  state text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  reporter_id uuid := private.require_moderation_identity(
    p_expected_reporter_profile_id,
    true
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Report page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_report_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both report cursor values must be provided together.';
  end if;

  return query
  select
    report.id,
    moderation_case.id,
    report.category,
    report.explanation,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    moderation_case.state,
    report.created_at
  from private.moderation_reports as report
  join private.moderation_cases as moderation_case
    on moderation_case.id = report.case_id
  where report.reporter_profile_id = reporter_id
    and (
      p_before_created_at is null
      or (report.created_at, report.id)
        < (p_before_created_at, p_before_report_id)
    )
  order by report.created_at desc, report.id desc
  limit p_limit;
end;
$$;

create function public.get_own_moderation_staff_access(
  p_expected_profile_id uuid
)
returns table (staff_role text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_moderation_identity(
    p_expected_profile_id,
    true
  );
begin
  return query
  select staff.staff_role
  from private.moderation_staff_roles as staff
  where staff.profile_id = current_profile_id
    and staff.is_active;
end;
$$;

create function public.list_moderation_cases(
  p_expected_staff_profile_id uuid,
  p_state text default null,
  p_limit integer default 25,
  p_before_created_at timestamptz default null,
  p_before_case_id uuid default null
)
returns table (
  case_id uuid,
  state text,
  state_version bigint,
  created_at timestamptz,
  category text,
  target_kind text,
  target_summary text,
  context_summary text,
  subject_profile_id uuid,
  subject_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);

  if p_state is not null
    and p_state not in ('received', 'under_review', 'completed') then
    raise exception using
      errcode = '22023',
      message = 'The moderation state filter is invalid.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Moderation queue page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_case_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both moderation queue cursor values must be provided together.';
  end if;

  return query
  select
    moderation_case.id,
    moderation_case.state,
    moderation_case.state_version,
    moderation_case.created_at,
    report.category,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    moderation_case.subject_profile_id,
    subject.display_name
  from private.moderation_cases as moderation_case
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  join public.profiles as subject
    on subject.id = moderation_case.subject_profile_id
  where (p_state is null or moderation_case.state = p_state)
    and (
      p_before_created_at is null
      or (moderation_case.created_at, moderation_case.id)
        < (p_before_created_at, p_before_case_id)
    )
  order by moderation_case.created_at desc, moderation_case.id desc
  limit p_limit;
end;
$$;

create function public.get_moderation_case_detail(
  p_expected_staff_profile_id uuid,
  p_case_id uuid
)
returns table (
  case_id uuid,
  state text,
  state_version bigint,
  created_at timestamptz,
  completed_at timestamptz,
  category text,
  explanation text,
  target_kind text,
  target_summary text,
  context_summary text,
  reporter_profile_id uuid,
  reporter_display_name text,
  subject_profile_id uuid,
  subject_display_name text,
  project_context_id uuid,
  resource_listing_context_id uuid,
  resource_request_context_id uuid,
  resource_chat_context_id uuid,
  notes jsonb,
  events jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);

  return query
  select
    moderation_case.id,
    moderation_case.state,
    moderation_case.state_version,
    moderation_case.created_at,
    moderation_case.completed_at,
    report.category,
    report.explanation,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    report.reporter_profile_id,
    reporter.display_name,
    moderation_case.subject_profile_id,
    subject.display_name,
    moderation_case.project_context_id,
    moderation_case.resource_listing_context_id,
    moderation_case.resource_request_context_id,
    moderation_case.resource_chat_context_id,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'note_id', note.id,
            'author_profile_id', note.author_profile_id,
            'author_display_name', author.display_name,
            'body', note.body,
            'created_at', note.created_at
          ) order by note.created_at, note.id
        )
        from private.moderation_case_notes as note
        join public.profiles as author on author.id = note.author_profile_id
        where note.case_id = moderation_case.id
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'event_id', event.id,
            'actor_profile_id', event.actor_profile_id,
            'actor_display_name', actor.display_name,
            'event_kind', event.event_kind,
            'from_state', event.from_state,
            'to_state', event.to_state,
            'state_version', event.state_version,
            'note_id', event.note_id,
            'created_at', event.created_at
          ) order by event.created_at, event.id
        )
        from private.moderation_case_events as event
        join public.profiles as actor on actor.id = event.actor_profile_id
        where event.case_id = moderation_case.id
      ),
      '[]'::jsonb
    )
  from private.moderation_cases as moderation_case
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  join public.profiles as reporter on reporter.id = report.reporter_profile_id
  join public.profiles as subject
    on subject.id = moderation_case.subject_profile_id
  where moderation_case.id = p_case_id;
end;
$$;

create function public.add_moderation_case_note(
  p_expected_staff_profile_id uuid,
  p_case_id uuid,
  p_body text
)
returns table (
  note_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_profile_id uuid := private.require_moderation_identity(
    p_expected_staff_profile_id,
    true
  );
  normalized_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  moderation_case private.moderation_cases%rowtype;
  new_note private.moderation_case_notes%rowtype;
begin
  perform private.require_moderation_staff(staff_profile_id);

  if char_length(normalized_body) not between 1 and 4000 then
    raise exception using
      errcode = '22023',
      message = 'A moderation note must contain between 1 and 4,000 characters.';
  end if;

  select * into moderation_case
  from private.moderation_cases as selected_case
  where selected_case.id = p_case_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The moderation case does not exist.';
  end if;

  insert into private.moderation_case_notes (
    case_id,
    author_profile_id,
    body
  )
  values (moderation_case.id, staff_profile_id, normalized_body)
  returning * into new_note;

  insert into private.moderation_case_events (
    case_id,
    actor_profile_id,
    event_kind,
    state_version,
    note_id,
    created_at
  )
  values (
    moderation_case.id,
    staff_profile_id,
    'note_added',
    moderation_case.state_version,
    new_note.id,
    new_note.created_at
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
    'moderation.note_added',
    staff_profile_id,
    'moderation_case',
    moderation_case.id,
    jsonb_build_object(
      'case_id', moderation_case.id,
      'note_id', new_note.id
    ),
    new_note.created_at
  );

  return query select new_note.id, new_note.created_at;
end;
$$;

create function public.transition_moderation_case(
  p_expected_staff_profile_id uuid,
  p_case_id uuid,
  p_expected_state_version bigint,
  p_target_state text
)
returns table (
  state text,
  state_version bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_profile_id uuid := private.require_moderation_identity(
    p_expected_staff_profile_id,
    true
  );
  current_case private.moderation_cases%rowtype;
  previous_state text;
  transition_time timestamptz := statement_timestamp();
begin
  perform private.require_moderation_staff(staff_profile_id);

  if p_target_state not in ('under_review', 'completed') then
    raise exception using
      errcode = '22023',
      message = 'The requested moderation state is invalid.';
  end if;

  select * into current_case
  from private.moderation_cases as moderation_case
  where moderation_case.id = p_case_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The moderation case does not exist.';
  end if;

  if current_case.state = p_target_state then
    return query select
      current_case.state,
      current_case.state_version,
      current_case.updated_at;
    return;
  end if;

  if p_expected_state_version is null
    or p_expected_state_version <> current_case.state_version then
    raise sqlstate 'PT409'
      using message = 'The moderation case changed before this action completed.';
  end if;

  if not (
    (current_case.state = 'received' and p_target_state = 'under_review')
    or (current_case.state = 'under_review' and p_target_state = 'completed')
    or (current_case.state = 'completed' and p_target_state = 'under_review')
  ) then
    raise sqlstate 'PT409'
      using message = 'The moderation case cannot make that state transition.';
  end if;

  previous_state := current_case.state;

  update private.moderation_cases as moderation_case
  set
    state = p_target_state,
    state_version = moderation_case.state_version + 1,
    updated_at = transition_time,
    completed_at = case
      when p_target_state = 'completed' then transition_time
      else null
    end
  where moderation_case.id = current_case.id
  returning * into current_case;

  insert into private.moderation_case_events (
    case_id,
    actor_profile_id,
    event_kind,
    from_state,
    to_state,
    state_version,
    created_at
  )
  values (
    current_case.id,
    staff_profile_id,
    'state_changed',
    previous_state,
    current_case.state,
    current_case.state_version,
    transition_time
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
    'moderation.case_state_changed',
    staff_profile_id,
    'moderation_case',
    current_case.id,
    jsonb_build_object(
      'case_id', current_case.id,
      'state', current_case.state,
      'state_version', current_case.state_version
    ),
    transition_time
  );

  return query select
    current_case.state,
    current_case.state_version,
    current_case.updated_at;
end;
$$;

comment on function public.submit_moderation_report(uuid, uuid, text, text, text, uuid, text, uuid) is
  'Creates one retry-safe manual-review case after deriving the subject and authorizing the exact typed target/context; it performs no enforcement.';
comment on function public.list_own_moderation_reports(uuid, integer, timestamptz, uuid) is
  'Returns only the expected reporter own narrow status projection with bounded keyset pagination.';
comment on function public.get_own_moderation_staff_access(uuid) is
  'Returns an active moderator/admin role only for the expected authenticated profile; ordinary users receive no row.';
comment on function public.list_moderation_cases(uuid, text, integer, timestamptz, uuid) is
  'Returns a bounded staff-only case queue and rechecks active staff authorization for every call.';
comment on function public.get_moderation_case_detail(uuid, uuid) is
  'Returns one staff-only case including sensitive original evidence, private notes, and identifier-only chronology.';
comment on function public.add_moderation_case_note(uuid, uuid, text) is
  'Appends one bounded staff-only note while keeping its body out of audit metadata.';
comment on function public.transition_moderation_case(uuid, uuid, bigint, text) is
  'Performs one compare-and-swap review-only state transition, including audited reopen, without product enforcement.';

revoke all privileges on function private.protect_moderation_append_only()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.protect_moderation_case_identity()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_moderation_identity(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_moderation_staff(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_has_project_association(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.moderation_target_summary(private.moderation_cases)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.moderation_context_summary(private.moderation_cases)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.submit_moderation_report(uuid, uuid, text, text, text, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_moderation_reports(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_moderation_staff_access(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_moderation_cases(uuid, text, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_moderation_case_detail(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.add_moderation_case_note(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.transition_moderation_case(uuid, uuid, bigint, text)
  from public, anon, authenticated, service_role;

grant execute on function public.submit_moderation_report(uuid, uuid, text, text, text, uuid, text, uuid)
  to authenticated;
grant execute on function public.list_own_moderation_reports(uuid, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_own_moderation_staff_access(uuid)
  to authenticated;
grant execute on function public.list_moderation_cases(uuid, text, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_moderation_case_detail(uuid, uuid)
  to authenticated;
grant execute on function public.add_moderation_case_note(uuid, uuid, text)
  to authenticated;
grant execute on function public.transition_moderation_case(uuid, uuid, bigint, text)
  to authenticated;
