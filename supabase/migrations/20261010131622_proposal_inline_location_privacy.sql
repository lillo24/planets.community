-- LOCATION02: one primary Proposal place selection, separate private directions.
-- No backfill, provider activation or change to existing exact-place visibility.
alter table private.location_search_batches drop constraint location_search_batches_slot_check;
alter table private.location_search_batches add constraint location_search_batches_slot_check
  check (slot in ('area','exact','public','place') and (slot <> 'place' or item_kind = 'one_time'));


create or replace function public.reserve_location_search_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_query_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_search_config%rowtype; batch private.location_search_batches%rowtype;
  current_revision bigint; daily timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
  minute timestamptz := date_trunc('minute',statement_timestamp()); used_count integer;
 provider_status text;
begin
  current_revision := private.lock_location_item(p_actor,p_kind,p_item);
  if p_revision is distinct from current_revision then return jsonb_build_object('status','stale_selection'); end if;
  if p_session is null or p_query_hash is null or p_query_hash !~ '^[a-f0-9]{64}$'
    or p_slot is null or (p_slot='place' and p_kind<>'one_time') or (p_kind='resource' and p_slot<>'public') or (p_kind<>'resource' and p_slot not in ('area','exact','place')) then
    raise exception using errcode='22023',message='Invalid location search scope.';
  end if;
  select * into cfg from private.location_search_config where singleton for update;
  if not found or not cfg.enabled then return jsonb_build_object('status','disabled'); end if;
  provider_status := private.reserve_location_provider_v1('editor',p_actor,false);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
  -- Remove expired derived data without retaining provider responses/search text.
  delete from private.location_search_batches where expires_at<=statement_timestamp();
  delete from private.location_search_budgets where bucket<daily;
  select * into batch from private.location_search_batches
    where actor=p_actor and item_kind=p_kind and item_id=p_item and revision=p_revision
      and slot=p_slot and session_id=p_session and query_hash=p_query_hash and expires_at>statement_timestamp()
    order by expires_at desc limit 1;
  if found then
    if not batch.ready then return jsonb_build_object('status','search_pending'); end if;
    return jsonb_build_object('status','ok','cached',true,'suggestions',coalesce(
      (select jsonb_agg(jsonb_build_object('id',r.id,'place',r.place,'expires_at',batch.expires_at) order by r.id)
       from private.location_selection_receipts r where r.batch_id=batch.id and r.used_request is null),'[]'::jsonb));
  end if;
  -- Rendering shares an account ceiling with autocomplete. The search-config
  -- row lock above serializes both meters; cache hits consume no new credits.
  if not exists(select 1 from private.location_preview_config where singleton) then
    return jsonb_build_object('status','metering_unavailable');
  end if;
  if exists(select 1 from private.location_preview_config c where singleton
    and (c.enabled or c.account_daily_credit_limit>0)
    and coalesce((select used from private.location_preview_usage where scope='credits:global' and bucket=daily),0)
      +coalesce((select used from private.location_search_budgets where scope='global' and bucket=daily),0)+1
      >c.account_daily_credit_limit) then
    return jsonb_build_object('status','budget_exhausted');
  end if;
  select used into used_count from private.location_search_budgets where scope='global' and bucket=daily;
  if coalesce(used_count,0)>=cfg.global_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='actor:'||p_actor and bucket=daily;
  if coalesce(used_count,0)>=cfg.actor_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='minute:'||p_actor and bucket=minute;
  if coalesce(used_count,0)>=cfg.actor_minute then return jsonb_build_object('status','rate_limited'); end if;
  provider_status := private.reserve_location_provider_v1('editor',p_actor,true);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
  insert into private.location_search_budgets(scope,bucket,used) values ('global',daily,1),('actor:'||p_actor,daily,1),('minute:'||p_actor,minute,1)
    on conflict(scope,bucket) do update set used=private.location_search_budgets.used+1;
  insert into private.location_search_batches(actor,item_kind,item_id,revision,slot,session_id,query_hash)
    values(p_actor,p_kind,p_item,p_revision,p_slot,p_session,p_query_hash) returning * into batch;
  return jsonb_build_object('status','ok','cached',false,'batch_id',batch.id);
end;
$$;

-- One-time directions are independent of the selected point; Tavoli retain their contract.
create or replace function private.invalidate_selected_exact_location()
returns trigger language plpgsql security definer set search_path = '' as $$
declare parent_id uuid;
begin
  if tg_table_name <> 'proposal_meeting_details'
    and new.exact_meeting_text is distinct from old.exact_meeting_text
    and new.selected_exact_place is not distinct from old.selected_exact_place then
    new.selected_exact_place := null; new.exact_location := null;
  end if;
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    if tg_table_name = 'proposal_meeting_details' then
      parent_id := new.proposal_id;
      update public.proposals set location_revision = location_revision + 1 where id = parent_id;
    else
      parent_id := new.recurring_activity_id;
      update public.recurring_activities set location_revision = location_revision + 1 where id = parent_id;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.replace_proposal_content(
  p_proposal_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_event_timezone text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_skill_ids uuid[],
  p_skill_importances text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_title text := nullif(btrim(p_title), '');
  normalized_summary text := nullif(btrim(p_summary), '');
  normalized_description text := nullif(btrim(p_description), '');
  normalized_timezone text := nullif(btrim(p_event_timezone), '');
  normalized_country_code text := nullif(upper(btrim(p_country_code)), '');
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_administrative_area text := nullif(btrim(p_administrative_area), '');
  normalized_public_location_label text := nullif(btrim(p_public_location_label), '');
  normalized_exact_meeting_text text := nullif(btrim(p_exact_meeting_text), '');
  normalized_visibility text := coalesce(
    nullif(btrim(p_exact_location_visibility), ''),
    'participants'
  );
begin
  -- Ordinary manual locality edits invalidate both old place selections. This
  -- keeps the disabled/offline UI valid without trusting a stale client cache.
  if exists(select 1 from public.proposals p where p.id=p_proposal_id
    and row(p.country_code,p.locality,p.administrative_area,p.public_location_label)
      is distinct from row(normalized_country_code,normalized_locality,normalized_administrative_area,normalized_public_location_label)) then
    update public.proposal_meeting_details set selected_exact_place=null,exact_location=null where proposal_id=p_proposal_id;
  end if;
  -- A stale ordinary form must not publish a newer selection or undo a scoped
  -- visibility change. Place visibility is now changed through the revision RPC.
  if exists (select 1 from public.proposal_meeting_details m
    where m.proposal_id=p_proposal_id and m.selected_exact_place is not null
      and m.exact_location_visibility is distinct from normalized_visibility) then
    raise exception using errcode='40001',message='Place visibility changed; reload the Project.';
  end if;
  if normalized_title is not null
    and char_length(normalized_title) not between 2 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Proposal title must contain between 2 and 100 characters.';
  end if;

  if normalized_summary is not null and char_length(normalized_summary) > 240 then
    raise exception using
      errcode = '22023',
      message = 'Proposal summary must contain at most 240 characters.';
  end if;

  if normalized_description is not null and char_length(normalized_description) > 5000 then
    raise exception using
      errcode = '22023',
      message = 'Proposal description must contain at most 5000 characters.';
  end if;

  if normalized_timezone is not null and char_length(normalized_timezone) > 100 then
    raise exception using
      errcode = '22023',
      message = 'Proposal time zone is invalid.';
  end if;

  if normalized_country_code is not null
    and normalized_country_code !~ '^[A-Z]{2}$' then
    raise exception using
      errcode = '22023',
      message = 'Proposal country code must contain two letters.';
  end if;

  if normalized_locality is not null and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal locality must contain at most 120 characters.';
  end if;

  if normalized_administrative_area is not null
    and char_length(normalized_administrative_area) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal administrative area must contain at most 120 characters.';
  end if;

  if normalized_public_location_label is not null
    and char_length(normalized_public_location_label) > 180 then
    raise exception using
      errcode = '22023',
      message = 'Proposal public location label must contain at most 180 characters.';
  end if;

  if normalized_exact_meeting_text is not null
    and char_length(normalized_exact_meeting_text) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'Exact meeting information must contain at most 1000 characters.';
  end if;

  if normalized_visibility not in ('public', 'participants') then
    raise exception using
      errcode = '22023',
      message = 'Exact location visibility must be public or participants.';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception using
      errcode = '22023',
      message = 'Proposal end time must be later than its start time.';
  end if;

  if p_skill_ids is null
    or p_skill_importances is null
    or cardinality(p_skill_ids) <> cardinality(p_skill_importances)
    or array_position(p_skill_ids, null) is not null
    or array_position(p_skill_importances, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skills and importance values must be matching non-null lists.';
  end if;

  if cardinality(p_skill_ids) <> (
    select count(distinct requested.skill_id)
    from unnest(p_skill_ids) as requested(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'A proposal skill may be selected only once.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_importances) as requested(importance)
    where requested.importance not in ('required', 'useful')
  ) then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill importance must be required or useful.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_ids) as requested(skill_id)
    left join public.skills as skill on skill.id = requested.skill_id
    where skill.id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'One or more proposal skills are not in the catalog.';
  end if;

  update public.proposals
  set
    title = normalized_title,
    summary = normalized_summary,
    description = normalized_description,
    starts_at = p_starts_at,
    ends_at = p_ends_at,
    event_timezone = normalized_timezone,
    country_code = normalized_country_code,
    locality = normalized_locality,
    administrative_area = normalized_administrative_area,
    public_location_label = normalized_public_location_label
  where id = p_proposal_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The proposal does not exist.';
  end if;

  insert into public.proposal_meeting_details (
    proposal_id,
    exact_meeting_text,
    exact_location_visibility
  )
  values (
    p_proposal_id,
    normalized_exact_meeting_text,
    normalized_visibility
  )
  on conflict (proposal_id)
  do update set
    exact_meeting_text = excluded.exact_meeting_text,
    exact_location_visibility = excluded.exact_location_visibility;

  delete from public.proposal_skills
  where proposal_id = p_proposal_id;

  insert into public.proposal_skills (proposal_id, skill_id, importance)
  select
    p_proposal_id,
    requested.skill_id,
    requested.importance
  from unnest(p_skill_ids, p_skill_importances) as requested(skill_id, importance);
end;
$$;

create or replace function public.get_authorized_item_location_v1(p_expected_profile_id uuid,p_kind text,p_item uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_resource_listing_identity(p_expected_profile_id); result jsonb;
begin
  if p_kind='resource' then
    if not exists(select 1 from public.get_own_resource_listing(actor,p_item)) then
      raise exception using errcode='42501',message='Location read unavailable.';
    end if;
    select jsonb_build_object('revision',location_revision,'public_place',selected_public_place,'exact_place',null)
      into result from public.resource_listings where id=p_item;
  elsif p_kind in ('one_time','recurring') then
    -- Reuse effective canonical membership/manager rules, including revocation.
    perform * from public.get_project_participant_meeting_details(actor,p_item);
    if p_kind='one_time' then
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place,
          'public_label',p.public_location_label,'locality',p.locality,'country_code',p.country_code,
          'administrative_area',p.administrative_area,'exact_is_public',m.exact_location_visibility='public')
        into result from public.proposals p join public.proposal_meeting_details m on m.proposal_id=p.id where p.id=p_item;
    else
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place)
        into result from public.recurring_activities p join public.recurring_activity_meeting_details m on m.recurring_activity_id=p.id where p.id=p_item;
    end if;
    if result is null then raise exception using errcode='22023',message='Location item kind mismatch.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return result;
end;
$$;

-- Compatibility projection: exact_meeting_text now carries only a deliberately public verified place LABEL.
-- Legacy arrival free text is participants-only in every visibility mode.
create or replace function public.get_public_proposal(p_proposal_id uuid)
returns table (
  proposal_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    proposal.id,
    cover.object_path,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.selected_exact_place->>'label'
      else null
    end,
    (meeting.exact_location_visibility <> 'public' or meeting.selected_exact_place is null)
      and (meeting.exact_meeting_text is not null or meeting.exact_location is not null)
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.lifecycle_state = 'published'
$$;

create function public.apply_proposal_place_v1(
  p_expected_profile_id uuid, p_item uuid, p_expected_revision bigint,
  p_request_id uuid, p_action text, p_receipt uuid default null
)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  current_actor uuid := private.require_resource_listing_identity(p_expected_profile_id);
  revision bigint; input jsonb; retry private.location_write_receipts%rowtype;
  place jsonb;
begin
  revision := private.lock_location_item(current_actor,'one_time',p_item);
  if p_request_id is null or p_expected_revision is null or p_action is null
    or p_action not in ('replace','clear','public','participants')
    or (p_action='replace') is distinct from (p_receipt is not null) then
    raise exception using errcode='22023',message='Invalid Proposal place mutation.';
  end if;
  input := jsonb_build_array('proposal_place_v1',p_item,p_expected_revision,p_action,p_receipt);
  select w.* into retry from private.location_write_receipts w where w.actor=current_actor and w.request_id=p_request_id;
  if found then
    if retry.input is distinct from input then
      raise exception using errcode='22023',message='Place retry input changed.';
    end if;
    if retry.revision<>revision then raise exception using errcode='40001',message='Place retry superseded.'; end if;
    return retry.revision;
  end if;
  if revision<>p_expected_revision then raise exception using errcode='40001',message='Place revision changed.'; end if;
  if p_action in ('public','participants') then
    if not exists(select 1 from public.proposal_meeting_details
      where proposal_id=p_item and selected_exact_place is not null) then
      raise exception using errcode='22023',message='Select an exact place before changing visibility.';
    end if;
    update public.proposal_meeting_details set exact_location_visibility=p_action where proposal_id=p_item;
  else
    if p_action='replace' then
      place := private.consume_location_receipt(current_actor,'one_time',p_item,revision,'place',p_receipt,p_request_id);
    end if;
    if place->>'kind'='locality' then
      update public.proposals set selected_public_place=place,approximate_location=private.selected_place_point(place),
        country_code=place->>'country_code',locality=place->>'locality',
        administrative_area=place->>'administrative_area',public_location_label=place->>'label' where id=p_item;
      update public.proposal_meeting_details set selected_exact_place=null,exact_location=null,
        exact_location_visibility='participants' where proposal_id=p_item;
    elsif place is not null then
      -- Structured city TEXT is safe; its geometry is never copied/rounded from
      -- the exact result. An independently selected matching broad area survives.
      update public.proposals set
        selected_public_place=case when selected_public_place->>'locality'=place->>'locality'
          and selected_public_place->>'administrative_area' is not distinct from place->>'administrative_area'
          then selected_public_place else null end,
        approximate_location=case when selected_public_place->>'locality'=place->>'locality'
          and selected_public_place->>'administrative_area' is not distinct from place->>'administrative_area'
          then approximate_location else null end,
        country_code=place->>'country_code',locality=place->>'locality',administrative_area=place->>'administrative_area',
        public_location_label=case when selected_public_place->>'locality'=place->>'locality'
          and selected_public_place->>'administrative_area' is not distinct from place->>'administrative_area'
          then selected_public_place->>'label' else concat_ws(', ',place->>'locality',place->>'administrative_area','Italia') end where id=p_item;
      update public.proposal_meeting_details set selected_exact_place=place,exact_location=private.selected_place_point(place),
        exact_location_visibility='participants' where proposal_id=p_item;
    else
      update public.proposals set selected_public_place=null,approximate_location=null where id=p_item;
      update public.proposal_meeting_details set selected_exact_place=null,exact_location=null,
        exact_location_visibility='participants' where proposal_id=p_item;
    end if;
  end if;
  revision := private.lock_location_item(current_actor,'one_time',p_item);
  insert into private.location_write_receipts values(current_actor,p_request_id,'one_time',p_item,input,revision);
  insert into private.audit_events(action,actor_user_id,target_type,target_id)
    values('location.updated',current_actor,'one_time',p_item);
  return revision;
end;
$$;
revoke all on function public.apply_proposal_place_v1(uuid,uuid,bigint,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.apply_proposal_place_v1(uuid,uuid,bigint,uuid,text,uuid) to authenticated;
comment on function public.apply_proposal_place_v1(uuid,uuid,bigint,uuid,text,uuid) is
 'LOCATION02: actor/item/revision/slot receipt-bound place selection and explicit visibility. New exact selections default private; directions never become public.';
comment on column public.proposal_meeting_details.exact_meeting_text is
 'Optional arrival instructions, participants/organizers only regardless of selected exact-place visibility. Legacy free text remains in protected storage.';


comment on column public.proposal_meeting_details.exact_location_visibility is
 'Visibility of the verified selected exact place only. Arrival instructions remain participants/organizers only in every mode.';

-- Old one-time exact-slot clients also default every new verified place to private.
create or replace function public.apply_item_location_v1(p_expected_profile_id uuid,p_kind text,p_item uuid,p_expected_revision bigint,
  p_request_id uuid,p_public_action text,p_public_receipt uuid,p_exact_action text,p_exact_receipt uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare current_actor uuid := private.require_resource_listing_identity(p_expected_profile_id);
  revision bigint; input jsonb; retry private.location_write_receipts%rowtype; public_place jsonb; exact_place jsonb;
begin
  revision := private.lock_location_item(current_actor,p_kind,p_item);
  if p_request_id is null or p_expected_revision is null or p_public_action is null or p_exact_action is null
    or p_public_action not in ('unchanged','replace','clear') or p_exact_action not in ('unchanged','replace','clear')
    or (p_public_action='replace') is distinct from (p_public_receipt is not null)
    or (p_exact_action='replace') is distinct from (p_exact_receipt is not null)
    or (p_kind='resource' and p_exact_action<>'unchanged') then
    raise exception using errcode='22023',message='Invalid location mutation.';
  end if;
  input := jsonb_build_array(p_kind,p_item,p_expected_revision,p_public_action,p_public_receipt,p_exact_action,p_exact_receipt);
  select w.* into retry from private.location_write_receipts w where w.actor=current_actor and w.request_id=p_request_id;
  if found then
    if retry.input is distinct from input then raise exception using errcode='22023',message='Location retry input changed.'; end if;
    if retry.revision<>revision then raise exception using errcode='40001',message='Location retry superseded.'; end if;
    return retry.revision;
  end if;
  if revision<>p_expected_revision then raise exception using errcode='40001',message='Location revision changed.'; end if;
  if p_public_action='replace' then public_place := private.consume_location_receipt(current_actor,p_kind,p_item,revision,
    case when p_kind='resource' then 'public' else 'area' end,p_public_receipt,p_request_id); end if;
  if p_exact_action='replace' then exact_place := private.consume_location_receipt(current_actor,p_kind,p_item,revision,'exact',p_exact_receipt,p_request_id); end if;
  if p_public_action<>'unchanged' then
    if p_kind='one_time' then
      update public.proposals set selected_public_place=public_place, approximate_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    elsif p_kind='recurring' then
      update public.recurring_activities set selected_public_place=public_place, approximate_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    else
      update public.resource_listings set selected_public_place=public_place,public_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    end if;
  end if;
  if p_exact_action<>'unchanged' then
    if p_kind='one_time' then
      update public.proposal_meeting_details set selected_exact_place=exact_place,exact_location=private.selected_place_point(exact_place),
        exact_location_visibility=case when p_exact_action='replace' then 'participants' else exact_location_visibility end where proposal_id=p_item;
    else
      update public.recurring_activity_meeting_details set selected_exact_place=exact_place,exact_location=private.selected_place_point(exact_place) where recurring_activity_id=p_item;
    end if;
  end if;
  revision := private.lock_location_item(current_actor,p_kind,p_item);
  insert into private.location_write_receipts values(current_actor,p_request_id,p_kind,p_item,input,revision);
  insert into private.audit_events(action,actor_user_id,target_type,target_id)
    values('location.updated',current_actor,p_kind,p_item);
  -- No provider content or location enters generic audit/outbox notifications.
  return revision;
end;
$$;
