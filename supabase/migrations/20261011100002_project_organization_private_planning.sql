-- CHECK01: no inference of consent from legacy tentative logistics. Reconcile
-- these records explicitly before rollout; this migration never rewrites them.
do $$ begin
  if exists (
    select 1 from public.proposals p join public.projects j on j.id=p.id
    where p.definition_phase='idea' and (
      p.starts_at is not null or p.ends_at is not null or p.event_timezone is not null
      or p.country_code is not null or p.locality is not null
      or p.administrative_area is not null or p.public_location_label is not null
      or p.selected_public_place is not null or p.approximate_location is not null
      or j.registration_capacity is not null
    )
  ) then
    raise exception using errcode='55000', message=
      'CHECK01 rollout blocked: reconcile legacy Idea logistics/capacity explicitly; no records were changed.';
  end if;
end $$;

create table private.project_organization (
  project_id uuid primary key references public.proposals(id) on delete cascade,
  revision bigint not null default 0 check(revision>=0),
  proposals jsonb not null default '{}'::jsonb check(jsonb_typeof(proposals)='object')
);
create table private.project_organization_tasks (
  project_id uuid not null references private.project_organization(project_id) on delete cascade,
  id uuid not null,
  parent_id uuid,
  title text not null check(title=btrim(title) and char_length(title) between 1 and 160),
  done boolean not null default false,
  position integer not null check(position>=0),
  author_id uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default statement_timestamp(),
  primary key(project_id,id),
  foreign key(project_id,parent_id) references private.project_organization_tasks(project_id,id) on delete cascade,
  check(id is distinct from parent_id)
);
create index project_organization_tasks_order on private.project_organization_tasks(project_id,parent_id,position,id);
create table private.project_organization_receipts (
  actor_id uuid not null references public.profiles(id),
  request_id uuid not null,
  project_id uuid not null references private.project_organization(project_id) on delete cascade,
  input jsonb not null,
  revision bigint not null,
  primary key(actor_id,request_id)
);
-- Unforgeable transaction-scoped capability, NOT a client-settable GUC.
-- Only the private publication trigger / confirmation RPC can insert it.
create table private.project_organization_official_writes (
  project_id uuid primary key references public.proposals(id) on delete cascade,
  transaction_id bigint not null
);
alter table private.project_organization enable row level security;
alter table private.project_organization_tasks enable row level security;
alter table private.project_organization_receipts enable row level security;
alter table private.project_organization_official_writes enable row level security;
revoke all on private.project_organization, private.project_organization_tasks,
  private.project_organization_receipts, private.project_organization_official_writes
  from public,anon,authenticated,service_role;

create function private.organization_official_write_allowed(p_project_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.project_organization_official_writes
    where project_id=p_project_id and transaction_id=txid_current());
$$;

create function private.protect_idea_official_details()
returns trigger language plpgsql security definer set search_path='' as $$
declare proposed jsonb := '{}'::jsonb; cap integer; counts boolean;
begin
  if old.lifecycle_state='draft' and new.lifecycle_state='published' and new.definition_phase='idea' then
    select registration_capacity,count_organizers_toward_capacity into cap,counts
      from public.projects where id=new.id for update;
    if new.locality is not null or new.public_location_label is not null then
      proposed := proposed || jsonb_build_object('location',jsonb_build_object(
        'text',coalesce(new.public_location_label,new.locality), 'country_code',new.country_code,
        'locality',new.locality,'administrative_area',new.administrative_area,'label',new.public_location_label));
    end if;
    if new.starts_at is not null or new.ends_at is not null or new.event_timezone is not null then
      proposed := proposed || jsonb_build_object('schedule',jsonb_build_object(
        'starts_at',new.starts_at,'ends_at',new.ends_at,'timezone',new.event_timezone));
    end if;
    if cap is not null then
      proposed := proposed || jsonb_build_object('capacity',jsonb_build_object('limit',cap,'count_organizers',counts));
    end if;
    insert into private.project_organization(project_id,proposals) values(new.id,proposed);
    -- Draft logistics are suggestions, not publication consent. Preserve precise
    -- venue/directions privately, and never manufacture a geographic reference.
    new.starts_at:=null; new.ends_at:=null; new.event_timezone:=null;
    new.country_code:=null; new.locality:=null; new.administrative_area:=null;
    new.public_location_label:=null; new.selected_public_place:=null; new.approximate_location:=null;
    update public.projects set registration_capacity=null where id=new.id;
  elsif old.definition_phase='idea' and old.lifecycle_state='published'
    and row(new.starts_at,new.ends_at,new.event_timezone,new.country_code,new.locality,
      new.administrative_area,new.public_location_label,new.selected_public_place,new.approximate_location)
      is distinct from row(old.starts_at,old.ends_at,old.event_timezone,old.country_code,old.locality,
      old.administrative_area,old.public_location_label,old.selected_public_place,old.approximate_location)
    and not private.organization_official_write_allowed(new.id) then
    raise exception using errcode='PT409',message='Use Organization to propose and explicitly confirm Idea details.';
  end if;
  return new;
end $$;
create trigger check01_official_details before update on public.proposals
  for each row execute function private.protect_idea_official_details();

create function private.protect_new_idea_precise_location()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.lifecycle_state='draft' and new.lifecycle_state='published' and new.definition_phase='idea' then
    update public.proposal_meeting_details set exact_location_visibility='participants' where proposal_id=new.id;
  end if;
  return new;
end $$;
create trigger check01_precise_location after update on public.proposals
  for each row execute function private.protect_new_idea_precise_location();

create function private.protect_idea_official_capacity()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if row(new.registration_capacity,new.count_organizers_toward_capacity)
    is distinct from row(old.registration_capacity,old.count_organizers_toward_capacity)
    and exists(select 1 from public.proposals where id=new.id and definition_phase='idea' and lifecycle_state='published')
    and not private.organization_official_write_allowed(new.id) then
    raise exception using errcode='PT409',message='Use Organization to propose and explicitly confirm Idea capacity.';
  end if;
  return new;
end $$;
create trigger check01_official_capacity before update on public.projects
  for each row execute function private.protect_idea_official_capacity();

create function private.validate_organization_task_tree()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  -- All supported writers serialize concrete Proposal -> shared Project -> state.
  -- Lock here too so trusted direct inserts cannot race the depth/count checks.
  perform 1 from private.project_organization where project_id=new.project_id for update;
  if tg_op='UPDATE' and row(new.id,new.project_id,new.parent_id,new.author_id)
      is distinct from row(old.id,old.project_id,old.parent_id,old.author_id) then
    raise exception using errcode='22023',message='Task identity, parent and author are immutable.';
  end if;
  if tg_op='INSERT' and (select count(*) from private.project_organization_tasks where project_id=new.project_id)>=120 then
    raise exception using errcode='22023',message='Organization allows at most 120 tasks including subtasks.';
  end if;
  if new.parent_id is not null and not exists(
    select 1 from private.project_organization_tasks where project_id=new.project_id and id=new.parent_id and parent_id is null
  ) then
    raise exception using errcode='22023',message='A subtask needs a root task in the same Project; only one level is allowed.';
  end if;
  if new.done and exists(select 1 from private.project_organization_tasks where project_id=new.project_id and parent_id=new.id) then
    raise exception using errcode='22023',message='A parent completion is derived from its children.';
  end if;
  return new;
end $$;
create trigger check01_task_tree before insert or update on private.project_organization_tasks
  for each row execute function private.validate_organization_task_tree();

create function private.organization_snapshot(p_actor uuid,p_project_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'project_id',p.id,'revision',coalesce(o.revision,0),'definition_phase',p.definition_phase,
    'can_mutate',p.lifecycle_state='published' and (p.definition_phase='idea' or p.ends_at>statement_timestamp()),
    'can_plan',p.definition_phase='idea' and private.profile_has_project_structural_authority(p.id,p_actor),
    'can_manage_tasks',private.profile_has_project_structural_authority(p.id,p_actor),
    'proposals',coalesce(o.proposals,'{}'::jsonb),
    'official',jsonb_build_object(
      'location',case when p.locality is not null then jsonb_build_object('text',p.public_location_label,
        'country_code',p.country_code,'locality',p.locality,'administrative_area',p.administrative_area,'label',p.public_location_label) end,
      'schedule',case when p.starts_at is not null then jsonb_build_object('starts_at',p.starts_at,'ends_at',p.ends_at,'timezone',p.event_timezone) end,
      'capacity',case when j.registration_capacity is not null then jsonb_build_object('limit',j.registration_capacity,'count_organizers',j.count_organizers_toward_capacity) end),
    'schedule_ready',p.starts_at>statement_timestamp() and p.ends_at>p.starts_at,
    'tasks',coalesce((select jsonb_agg(jsonb_build_object(
      'id',t.id,'parent_id',t.parent_id,'title',t.title,'position',t.position,
      'author_id',t.author_id,'updated_by',t.updated_by,'updated_at',t.updated_at,
      'done',case when exists(select 1 from private.project_organization_tasks c where c.project_id=t.project_id and c.parent_id=t.id)
        then (select bool_and(c.done) from private.project_organization_tasks c where c.project_id=t.project_id and c.parent_id=t.id) else t.done end,
      'can_edit',t.author_id=p_actor or private.profile_has_project_structural_authority(p.id,p_actor),
      'can_remove',(t.author_id=p_actor and not exists(select 1 from private.project_organization_tasks c
        where c.project_id=t.project_id and c.parent_id=t.id and c.author_id<>p_actor)) or private.profile_has_project_structural_authority(p.id,p_actor)
      ) order by t.position,t.id) from private.project_organization_tasks t where t.project_id=p.id),'[]'::jsonb)
  ) from public.proposals p join public.projects j on j.id=p.id
  left join private.project_organization o on o.project_id=p.id where p.id=p_project_id;
$$;

create function public.get_project_organization_v1(p_expected_profile_id uuid,p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  -- Historical messages are a log; this mutable planner deliberately retains
  -- current-group access only, including after end/cancellation. No snapshots
  -- are leaked to departed members or revoked delegates.
  if not private.profile_can_read_project_workspace(p_project_id,actor)
    or not exists(select 1 from public.proposals where id=p_project_id and lifecycle_state<>'draft') then
    raise exception using errcode='42501',message='Project Organization is unavailable.';
  end if;
  return private.organization_snapshot(actor,p_project_id);
end $$;

create function private.validate_organization_decision(p_kind text,p_value jsonb,p_confirm boolean)
returns void language plpgsql stable security definer set search_path='' as $$
declare starts timestamptz; ends timestamptz;
begin
  if p_kind is null or p_kind not in ('location','schedule','capacity') or p_value is null
    or jsonb_typeof(p_value)<>'object' or octet_length(p_value::text)>4096 then
    raise exception using errcode='22023',message='Invalid planning decision.';
  end if;
  if p_kind='location' then
    if exists(select 1 from jsonb_object_keys(p_value) k where k not in ('text','country_code','locality','administrative_area','label'))
      or jsonb_typeof(p_value->'text') is distinct from 'string'
      or exists(select 1 from jsonb_each(p_value) f where f.key<>'text' and jsonb_typeof(f.value) not in ('string','null'))
      or nullif(btrim(p_value->>'text'),'') is null or char_length(p_value->>'text')>180
      or char_length(p_value->>'locality')>120 or char_length(p_value->>'label')>180
      or char_length(p_value->>'administrative_area')>120
      or (p_value->>'country_code' is not null and p_value->>'country_code'!~'^[A-Z]{2}$') then
      raise exception using errcode='22023',message='A bounded public-area suggestion is required; no coordinates or exact venue fields.';
    end if;
    if p_confirm and (nullif(btrim(p_value->>'locality'),'') is null
      or nullif(btrim(p_value->>'label'),'') is null or p_value->>'country_code' is null) then
      raise exception using errcode='22023',message='Confirm a structured public city/country/label, not an ambiguous suggestion.';
    end if;
  elsif p_kind='schedule' then
    if exists(select 1 from jsonb_object_keys(p_value) k where k not in ('starts_at','ends_at','timezone'))
      or jsonb_typeof(p_value->'starts_at') is distinct from 'string'
      or jsonb_typeof(p_value->'ends_at') is distinct from 'string'
      or jsonb_typeof(p_value->'timezone') is distinct from 'string' then
      raise exception using errcode='22023',message='Invalid schedule fields.';
    end if;
    starts := (p_value->>'starts_at')::timestamptz; ends := (p_value->>'ends_at')::timestamptz;
    if starts is null or ends is null or not isfinite(starts) or not isfinite(ends) or ends<=starts
      or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_value->>'timezone')
      or (p_confirm and starts<=statement_timestamp()) then
      raise exception using errcode='22023',message='Choose a valid future start, later end and IANA timezone.';
    end if;
  else
    if exists(select 1 from jsonb_object_keys(p_value) k where k not in ('limit','count_organizers'))
      or jsonb_typeof(p_value->'limit') is distinct from 'number'
      or (p_value->>'limit')!~'^[0-9]+$' or (p_value->>'limit')::numeric not between 1 and 100000
      or jsonb_typeof(p_value->'count_organizers') is distinct from 'boolean' then
      raise exception using errcode='22023',message='Choose a capacity of 1 to 100,000 and the organizer-counting setting.';
    end if;
  end if;
end $$;

create function public.mutate_project_organization_v1(p_expected_profile_id uuid,p_project_id uuid,
  p_expected_revision bigint,p_request_id uuid,p_command jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
  p public.proposals%rowtype; o private.project_organization%rowtype;
  receipt private.project_organization_receipts%rowtype;
  task private.project_organization_tasks%rowtype; structural boolean;
  action text := p_command->>'action'; kind text := p_command->>'kind'; value jsonb := p_command->'value';
  input jsonb; task_id uuid; new_parent_id uuid; next_position integer; wanted integer;
begin
  if p_expected_revision is null or p_expected_revision<0 or p_request_id is null
    or p_command is null or jsonb_typeof(p_command)<>'object' or octet_length(p_command::text)>8192 then
    raise exception using errcode='22023',message='A revision, stable request ID and bounded command are required.';
  end if;
  select * into p from public.proposals where id=p_project_id for update;
  perform 1 from public.projects where id=p_project_id for update;
  if p.id is null or p.lifecycle_state='draft' or not private.profile_can_read_project_workspace(p_project_id,actor) then
    raise exception using errcode='42501',message='Project Organization is unavailable.';
  end if;
  structural := private.profile_has_project_structural_authority(p_project_id,actor);
  insert into private.project_organization(project_id) values(p_project_id) on conflict do nothing;
  select * into o from private.project_organization where project_id=p_project_id for update;
  input:=jsonb_build_array(p_project_id,p_expected_revision,p_command);
  select * into receipt from private.project_organization_receipts where actor_id=actor and request_id=p_request_id;
  if found then
    if receipt.input is distinct from input then
      raise exception using errcode='22023',message='Organization retry input changed.';
    end if;
    if receipt.revision<>o.revision then
      raise exception using errcode='PT409',message='Organization retry was superseded; reload.';
    end if;
    return private.organization_snapshot(actor,p_project_id);
  end if;
  if o.revision<>p_expected_revision then
    raise exception using errcode='PT409',message='Organization changed; reload before editing.';
  end if;
  if p.lifecycle_state<>'published' or (p.definition_phase='defined' and p.ends_at<=statement_timestamp()) then
    raise exception using errcode='55000',message='This Project Organization is read-only.';
  end if;
  if action in ('save_decision','confirm_decision') then
    if not structural or p.definition_phase<>'idea' then
      raise exception using errcode='42501',message='Only the Creator/current Co-creator can plan an Idea.';
    end if;
    perform private.require_complete_profile(actor);
    if not private.has_current_profile_photo(actor) then
      raise exception using errcode='PT422',message='A current profile photo is required for planning decisions.';
    end if;
    if action='save_decision' then
      perform private.validate_organization_decision(kind,value,false);
      update private.project_organization set proposals=jsonb_set(proposals,array[kind],value) where project_id=p_project_id;
    else
      value:=o.proposals->kind;
      perform private.validate_organization_decision(kind,value,true);
      insert into private.project_organization_official_writes values(p_project_id,txid_current());
      if kind='location' then
        update public.proposals set country_code=btrim(value->>'country_code'),locality=btrim(value->>'locality'),
          administrative_area=nullif(btrim(value->>'administrative_area'),''),public_location_label=btrim(value->>'label'),
          selected_public_place=null,approximate_location=null where id=p_project_id;
        -- A changed city invalidates its old precise selection, using LOCATION02
        -- ownership and receipt-revision triggers; confirming never exposes it.
        if row(p.country_code,p.locality,p.administrative_area) is distinct from
          row(btrim(value->>'country_code'),btrim(value->>'locality'),nullif(btrim(value->>'administrative_area'),'')) then
          update public.proposal_meeting_details set selected_exact_place=null,exact_location=null where proposal_id=p_project_id;
        end if;
      elsif kind='schedule' then
        update public.proposals set starts_at=(value->>'starts_at')::timestamptz,ends_at=(value->>'ends_at')::timestamptz,
          event_timezone=value->>'timezone' where id=p_project_id;
      else
        perform private.set_project_registration_capacity_for_structural_edit(actor,p_project_id,
          (value->>'limit')::integer,(value->>'count_organizers')::boolean);
      end if;
      delete from private.project_organization_official_writes where project_id=p_project_id;
      update private.project_organization set proposals=proposals-kind where project_id=p_project_id;
      insert into private.audit_events(action,actor_user_id,target_type,target_id)
        values('project.organization.confirmed',actor,'proposal',p_project_id);
      insert into private.outbox_events(event_type,payload) values('proposal.updated',jsonb_build_object('proposal_id',p_project_id,'actor_id',actor));
    end if;
  elsif action='add_task' then
    if jsonb_typeof(p_command->'title') is distinct from 'string' then
      raise exception using errcode='22023',message='A task title must be text.';
    end if;
    task_id:=(p_command->>'task_id')::uuid; new_parent_id:=(p_command->>'parent_id')::uuid;
    if task_id is null then raise exception using errcode='22023',message='A stable task ID is required.'; end if;
    if new_parent_id is not null then
      -- A formerly completed leaf becomes an unchecked parent; completion is now
      -- derived from the new child. The Project/state lock serializes toggles.
      update private.project_organization_tasks set done=false,updated_by=actor,updated_at=statement_timestamp()
        where project_id=p_project_id and id=new_parent_id;
    end if;
    select coalesce(max(position)+1,0) into next_position from private.project_organization_tasks
      where project_id=p_project_id and parent_id is not distinct from new_parent_id;
    insert into private.project_organization_tasks(project_id,id,parent_id,title,position,author_id,updated_by)
      values(p_project_id,task_id,new_parent_id,btrim(p_command->>'title'),next_position,actor,actor);
  elsif action in ('edit_task','remove_task','set_task_done','move_task') then
    task_id:=(p_command->>'task_id')::uuid;
    select * into task from private.project_organization_tasks where project_id=p_project_id and id=task_id;
    if not found then raise exception using errcode='PT409',message='Task no longer exists; reload.'; end if;
    if action in ('edit_task','remove_task') and not structural and task.author_id<>actor then
      raise exception using errcode='42501',message='Only the author or Creator/Co-creator can edit/remove this task.';
    end if;
    if action='edit_task' then
      if jsonb_typeof(p_command->'title') is distinct from 'string' then
        raise exception using errcode='22023',message='A task title must be text.';
      end if;
      update private.project_organization_tasks set title=btrim(p_command->>'title'),updated_by=actor,updated_at=statement_timestamp()
        where project_id=p_project_id and id=task_id;
    elsif action='remove_task' then
      if not structural and exists(select 1 from private.project_organization_tasks
        where project_id=p_project_id and parent_id=task_id and author_id<>actor) then
        raise exception using errcode='42501',message='Cannot remove another participant''s subtasks.';
      end if;
      delete from private.project_organization_tasks where project_id=p_project_id and id=task_id;
    elsif action='set_task_done' then
      if jsonb_typeof(p_command->'done') is distinct from 'boolean'
        or exists(select 1 from private.project_organization_tasks where project_id=p_project_id and parent_id=task_id) then
        raise exception using errcode='22023',message='Only leaf tasks can be checked/reopened; parents follow their children.';
      end if;
      update private.project_organization_tasks set done=(p_command->>'done')::boolean,updated_by=actor,updated_at=statement_timestamp()
        where project_id=p_project_id and id=task_id;
    else
      if not structural then raise exception using errcode='42501',message='Only the Creator/Co-creator can reorder tasks.'; end if;
      wanted:=(p_command->>'position')::integer;
      if wanted is null or wanted not between 0 and 119 then raise exception using errcode='22023',message='Invalid task position.'; end if;
      wanted:=least(wanted,(select count(*)::integer-1 from private.project_organization_tasks
        where project_id=p_project_id and parent_id is not distinct from task.parent_id));
      with ordered as (
        select id,(row_number() over(order by position,id)-1)::integer as pos
        from private.project_organization_tasks where project_id=p_project_id and parent_id is not distinct from task.parent_id and id<>task_id
      ) update private.project_organization_tasks t set position=case when ordered.pos>=wanted then ordered.pos+1 else ordered.pos end,updated_by=actor,updated_at=statement_timestamp()
        from ordered where t.project_id=p_project_id and t.id=ordered.id;
      update private.project_organization_tasks set position=wanted,updated_by=actor,updated_at=statement_timestamp()
        where project_id=p_project_id and id=task_id;
    end if;
  else
    raise exception using errcode='22023',message='Unknown Organization command.';
  end if;
  update private.project_organization set revision=revision+1 where project_id=p_project_id returning * into o;
  insert into private.project_organization_receipts values(actor,p_request_id,p_project_id,input,o.revision);
  return private.organization_snapshot(actor,p_project_id);
end $$;

revoke all on function private.organization_official_write_allowed(uuid),private.protect_idea_official_details(),
  private.protect_new_idea_precise_location(),
  private.protect_idea_official_capacity(),private.validate_organization_task_tree(),
  private.organization_snapshot(uuid,uuid),private.validate_organization_decision(text,jsonb,boolean),
  public.get_project_organization_v1(uuid,uuid),public.mutate_project_organization_v1(uuid,uuid,bigint,uuid,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.get_project_organization_v1(uuid,uuid),
  public.mutate_project_organization_v1(uuid,uuid,bigint,uuid,jsonb) to authenticated;
comment on function public.mutate_project_organization_v1(uuid,uuid,bigint,uuid,jsonb) is
  'CHECK01 v1: concrete Proposal then shared Project lock, current identity/authority, global revision CAS and actor-bound retry receipt. Private proposals never enter canonical fields until explicit confirmation. No Needs/chat/provider side effects.';
