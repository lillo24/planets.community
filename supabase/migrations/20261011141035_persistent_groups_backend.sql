-- GRP01: durable group identity, personal authority and a bounded public directory.
-- No legal verification, membership mirror, media storage, notifications or jobs.
create table private.community_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) <= 120),
  description text not null check (char_length(description) <= 4000),
  group_kind text not null check (group_kind in ('informal', 'organization')),
  locality text check (locality is null or char_length(locality) between 1 and 120),
  volunteering_focus boolean not null,
  publication_state text not null default 'draft' check (publication_state in ('draft', 'published', 'archived')),
  directory_suppressed boolean not null default false,
  version bigint not null default 1 check (version > 0),
  original_actor_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (publication_state <> 'published' or (char_length(name) >= 2 and char_length(description) >= 20))
);
comment on column private.community_groups.original_actor_id is
  'Immutable Auth UUID provenance, deliberately without a deletion-blocking account FK; not current authority.';
create table private.community_group_managers (
  group_id uuid primary key references private.community_groups(id) on delete restrict,
  profile_id uuid references public.profiles(id) on delete set null,
  appointed_by_actor_id uuid not null,
  appointed_at timestamptz not null default clock_timestamp()
);
comment on table private.community_group_managers is
  'One accountable person in GRP01. Separate authority anchor permits later reviewed multi-manager support without changing group IDs. Null identity fails closed; no automatic transfer.';
create index community_group_managers_profile_idx on private.community_group_managers(profile_id, group_id) where profile_id is not null;
create index community_groups_directory_idx on private.community_groups(created_at desc, id desc)
  where publication_state = 'published' and not directory_suppressed;
create index community_groups_kind_directory_idx on private.community_groups(group_kind, created_at desc, id desc)
  where publication_state = 'published' and not directory_suppressed;
create index community_groups_locality_directory_idx on private.community_groups(lower(locality), created_at desc, id desc)
  where publication_state = 'published' and not directory_suppressed;
create index community_groups_volunteering_directory_idx on private.community_groups(volunteering_focus, created_at desc, id desc)
  where publication_state = 'published' and not directory_suppressed;

create table private.community_group_command_receipts (
  actor_id uuid not null,
  client_request_id uuid not null,
  group_id uuid not null references private.community_groups(id) on delete restrict,
  intent_hash text not null check (intent_hash ~ '^[0-9a-f]{64}$'),
  accepted_version bigint not null,
  accepted_at timestamptz not null default clock_timestamp(),
  primary key (actor_id, client_request_id)
);
create index community_group_receipts_group_idx on private.community_group_command_receipts(group_id);
create table private.community_group_suppression_actions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  actor_id uuid not null,
  directory_suppressed boolean not null,
  reason text not null check (char_length(reason) between 10 and 4000),
  group_version bigint not null,
  created_at timestamptz not null default clock_timestamp()
);
create index community_group_suppression_history_idx on private.community_group_suppression_actions(group_id, group_version desc);
alter table private.community_groups enable row level security;
alter table private.community_group_managers enable row level security;
alter table private.community_group_command_receipts enable row level security;
alter table private.community_group_suppression_actions enable row level security;
revoke all on private.community_groups, private.community_group_managers,
  private.community_group_command_receipts, private.community_group_suppression_actions from public, anon, authenticated, service_role;
create trigger community_group_receipts_append_only before update or delete on private.community_group_command_receipts
  for each row execute function private.protect_moderation_append_only();
create trigger community_group_suppression_append_only before update or delete on private.community_group_suppression_actions
  for each row execute function private.protect_moderation_append_only();

create function private.protect_community_group_identity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.id <> old.id or new.original_actor_id <> old.original_actor_id or new.created_at <> old.created_at then
    raise exception using errcode = '55000', message = 'Group creation identity is immutable.';
  end if;
  return new;
end;
$$;
create trigger community_group_identity_immutable before update on private.community_groups
  for each row execute function private.protect_community_group_identity();

create function private.normalize_group_content(p_content jsonb) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  group_name text;
  purpose text;
  territory text;
  reserved_name text;
begin
  if jsonb_typeof(p_content) is distinct from 'object'
    or not (p_content ?& array['name','description','group_kind','volunteering_focus'])
    or (p_content - array['name','description','group_kind','locality','volunteering_focus']) <> '{}'::jsonb
    or jsonb_typeof(p_content->'name') is distinct from 'string'
    or jsonb_typeof(p_content->'description') is distinct from 'string'
    or jsonb_typeof(p_content->'group_kind') is distinct from 'string'
    or jsonb_typeof(p_content->'volunteering_focus') is distinct from 'boolean'
    or (p_content ? 'locality' and jsonb_typeof(p_content->'locality') not in ('string','null'))
    or p_content->>'group_kind' not in ('informal','organization') then
    raise exception using errcode = '22023', message = 'Group content has invalid fields or types.';
  end if;
  group_name := regexp_replace(p_content->>'name', '^[[:space:]]+|[[:space:]]+$', '', 'g');
  purpose := regexp_replace(p_content->>'description', '^[[:space:]]+|[[:space:]]+$', '', 'g');
  territory := nullif(regexp_replace(p_content->>'locality', '^[[:space:]]+|[[:space:]]+$', '', 'g'), '');
  if char_length(group_name) > 120 or char_length(purpose) > 4000 or char_length(territory) > 120 then
    raise exception using errcode = '22023', message = 'Group content exceeds its bounds.';
  end if;
  reserved_name := regexp_replace(lower(group_name), '[^a-z0-9]', '', 'g');
  if reserved_name = 'planets' or reserved_name like '%planetscommunity%'
    or (reserved_name like '%planets%' and (reserved_name like '%official%' or reserved_name like '%ufficial%')) then
    raise exception using errcode = '22023', message = 'The platform and official group identity is reserved.';
  end if;
  return jsonb_build_object('name', group_name, 'description', purpose, 'group_kind', p_content->>'group_kind',
    'locality', territory, 'volunteering_focus', (p_content->>'volunteering_focus')::boolean);
end;
$$;

create function private.require_group_actor(p_expected_profile_id uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_complete_profile(p_expected_profile_id);
begin
  -- A still-valid JWT for an absent Auth identity never authorizes a group operation.
  if not exists (select 1 from auth.users where id = actor) then
    raise exception using errcode = '42501', message = 'The group identity is unavailable.';
  end if;
  return actor;
end;
$$;
create function private.group_is_public(p_group_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.community_groups g
    join private.community_group_managers m on m.group_id = g.id
    join public.profiles p on p.id = m.profile_id and p.display_name is not null
    join auth.users a on a.id = p.id
    where g.id = p_group_id and g.publication_state = 'published' and not g.directory_suppressed);
$$;
-- Receipts share one actor/key namespace across commands. Authority is checked
-- again after waiting; a receipt is evidence of a result, never new authority.
create function private.lock_group_command(p_actor uuid, p_key uuid) returns void
language plpgsql volatile security invoker set search_path = '' as $$
begin
  if p_key is null then raise exception using errcode = '22023', message = 'A group command request ID is required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('group.command:' || p_actor::text || ':' || p_key::text, 0));
end;
$$;
create function private.group_command_hash(p_intent jsonb) returns text
language sql immutable security invoker set search_path = '' as $$
  select encode(extensions.digest(p_intent::text, 'sha256'), 'hex');
$$;
create function private.audit_group_change(p_action text, p_actor uuid, p_group uuid, p_version bigint) returns void
language sql volatile security invoker set search_path = '' as $$
  -- Raw actor UUID in identifier-only metadata avoids adding a group-specific
  -- account erasure blocker through audit_events.actor_user_id's RESTRICT FK.
  insert into private.audit_events(action, target_type, target_id, metadata)
    values (p_action, 'community_group', p_group, jsonb_build_object('actor_id',p_actor,'group_id',p_group,'version',p_version));
$$;

create function public.create_group_draft(p_expected_profile_id uuid, p_client_request_id uuid, p_content jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_actor(p_expected_profile_id);
  content jsonb := private.normalize_group_content(p_content);
  intent text := private.group_command_hash(jsonb_build_array('create',content));
  receipt private.community_group_command_receipts%rowtype;
  destination uuid;
begin
  perform private.lock_group_command(actor, p_client_request_id);
  perform private.require_group_actor(p_expected_profile_id);
  select * into receipt from private.community_group_command_receipts where actor_id = actor and client_request_id = p_client_request_id;
  if found then
    if receipt.intent_hash <> intent then raise exception using errcode = '22023', message = 'The accepted group command intent differs.'; end if;
    if not exists (select 1 from private.community_group_managers where group_id = receipt.group_id and profile_id = actor) then
      raise exception using errcode = '42501', message = 'The group is unavailable.';
    end if;
    return receipt.group_id;
  end if;
  insert into private.community_groups(name,description,group_kind,locality,volunteering_focus,original_actor_id)
    values (content->>'name',content->>'description',content->>'group_kind',content->>'locality',(content->>'volunteering_focus')::boolean,actor)
    returning id into destination;
  insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id) values (destination,actor,actor);
  insert into private.community_group_command_receipts(actor_id,client_request_id,group_id,intent_hash,accepted_version)
    values (actor,p_client_request_id,destination,intent,1);
  perform private.audit_group_change('group.created',actor,destination,1);
  perform private.audit_group_change('group.manager_appointed',actor,destination,1);
  return destination;
end;
$$;

create function public.recover_group_command(p_expected_profile_id uuid, p_client_request_id uuid)
returns table(group_id uuid, accepted_version bigint) language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.require_group_actor(p_expected_profile_id);
begin
  perform private.lock_group_command(actor,p_client_request_id);
  perform private.require_group_actor(p_expected_profile_id);
  return query select r.group_id,r.accepted_version from private.community_group_command_receipts r
    join private.community_group_managers m on m.group_id = r.group_id and m.profile_id = actor
    where r.actor_id = actor and r.client_request_id = p_client_request_id;
end;
$$;

create function public.get_own_group(p_expected_profile_id uuid, p_group_id uuid)
returns table(group_id uuid,name text,description text,group_kind text,locality text,volunteering_focus boolean,
  publication_state text,directory_suppressed boolean,version bigint,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_group_actor(p_expected_profile_id);
begin
  if not exists (select 1 from private.community_group_managers m where m.group_id = p_group_id and m.profile_id = actor) then
    raise exception using errcode = '42501', message = 'The group is unavailable.';
  end if;
  return query select g.id,g.name,g.description,g.group_kind,g.locality,g.volunteering_focus,g.publication_state,g.directory_suppressed,g.version,g.created_at,g.updated_at
    from private.community_groups g where g.id = p_group_id;
end;
$$;
create function public.list_own_groups(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(group_id uuid,name text,description text,group_kind text,locality text,volunteering_focus boolean,
  publication_state text,directory_suppressed boolean,version bigint,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_group_actor(p_expected_profile_id);
begin
  if p_limit is null or p_limit not between 1 and 50 or (p_before_created_at is null) <> (p_before_id is null)
    or (p_before_created_at is not null and not isfinite(p_before_created_at)) then
    raise exception using errcode = '22023', message = 'Invalid group page size or paired cursor.';
  end if;
  return query select g.id,g.name,g.description,g.group_kind,g.locality,g.volunteering_focus,g.publication_state,g.directory_suppressed,g.version,g.created_at,g.updated_at
    from private.community_groups g join private.community_group_managers m on m.group_id = g.id and m.profile_id = actor
    where p_before_id is null or (g.created_at,g.id) < (p_before_created_at,p_before_id)
    order by g.created_at desc,g.id desc limit p_limit;
end;
$$;

create function public.update_group(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_expected_version bigint,p_content jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_actor(p_expected_profile_id);
  content jsonb := private.normalize_group_content(p_content);
  intent text := private.group_command_hash(jsonb_build_array('update',p_group_id,p_expected_version,content));
  receipt private.community_group_command_receipts%rowtype;
  current_group private.community_groups%rowtype;
begin
  perform private.lock_group_command(actor,p_client_request_id);
  select * into current_group from private.community_groups where id = p_group_id for update;
  perform private.require_group_actor(p_expected_profile_id);
  if current_group.id is null or not exists (select 1 from private.community_group_managers where group_id = p_group_id and profile_id = actor) then
    raise exception using errcode = '42501', message = 'The group is unavailable.';
  end if;
  select * into receipt from private.community_group_command_receipts where actor_id = actor and client_request_id = p_client_request_id;
  if found then
    if receipt.intent_hash <> intent then raise exception using errcode = '22023', message = 'The accepted group command intent differs.'; end if;
    return receipt.accepted_version;
  end if;
  if p_expected_version is null or p_expected_version <> current_group.version then
    raise sqlstate 'PT409' using message = 'The group changed. Reload before editing.';
  end if;
  if current_group.publication_state = 'archived' then raise exception using errcode = '55000', message = 'Restore the archived group to draft before editing.'; end if;
  if current_group.publication_state = 'published' and (char_length(content->>'name') < 2 or char_length(content->>'description') < 20) then
    raise exception using errcode = '22023', message = 'A published group requires a name and purpose.';
  end if;
  if row(current_group.name,current_group.description,current_group.group_kind,current_group.locality,current_group.volunteering_focus)
    is distinct from row(content->>'name',content->>'description',content->>'group_kind',content->>'locality',(content->>'volunteering_focus')::boolean) then
    update private.community_groups set name=content->>'name',description=content->>'description',group_kind=content->>'group_kind',
      locality=content->>'locality',volunteering_focus=(content->>'volunteering_focus')::boolean,version=version+1,updated_at=clock_timestamp()
      where id=p_group_id returning * into current_group;
    perform private.audit_group_change('group.updated',actor,p_group_id,current_group.version);
  end if;
  insert into private.community_group_command_receipts(actor_id,client_request_id,group_id,intent_hash,accepted_version)
    values(actor,p_client_request_id,p_group_id,intent,current_group.version);
  return current_group.version;
end;
$$;

create function public.set_group_publication_state(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_expected_version bigint,p_publication_state text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_actor(p_expected_profile_id);
  intent text := private.group_command_hash(jsonb_build_array('state',p_group_id,p_expected_version,p_publication_state));
  receipt private.community_group_command_receipts%rowtype;
  current_group private.community_groups%rowtype;
begin
  if p_publication_state is null or p_publication_state not in ('draft','published','archived') then
    raise exception using errcode='22023',message='Invalid group publication state.';
  end if;
  perform private.lock_group_command(actor,p_client_request_id);
  select * into current_group from private.community_groups where id=p_group_id for update;
  perform private.require_group_actor(p_expected_profile_id);
  if current_group.id is null or not exists (select 1 from private.community_group_managers where group_id=p_group_id and profile_id=actor) then
    raise exception using errcode='42501',message='The group is unavailable.';
  end if;
  select * into receipt from private.community_group_command_receipts where actor_id=actor and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash <> intent then raise exception using errcode='22023',message='The accepted group command intent differs.'; end if;
    return receipt.accepted_version;
  end if;
  if p_expected_version is null or p_expected_version <> current_group.version then raise sqlstate 'PT409' using message='The group changed. Reload before changing publication.'; end if;
  if p_publication_state='published' and (char_length(current_group.name)<2 or char_length(current_group.description)<20) then
    raise exception using errcode='22023',message='Publication requires a name and purpose.';
  end if;
  -- An archived page must return to draft before an explicit publication.
  if current_group.publication_state='archived' and p_publication_state='published' then
    raise exception using errcode='55000',message='Restore the archived group to draft before publishing.';
  end if;
  if current_group.publication_state <> p_publication_state then
    update private.community_groups set publication_state=p_publication_state,version=version+1,updated_at=clock_timestamp()
      where id=p_group_id returning * into current_group;
    perform private.audit_group_change('group.publication_changed',actor,p_group_id,current_group.version);
  end if;
  insert into private.community_group_command_receipts(actor_id,client_request_id,group_id,intent_hash,accepted_version)
    values(actor,p_client_request_id,p_group_id,intent,current_group.version);
  return current_group.version;
end;
$$;

create function public.list_public_groups(p_search text default null,p_group_kind text default null,p_volunteering_focus boolean default null,
  p_locality text default null,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(group_id uuid,name text,description text,group_kind text,locality text,volunteering_focus boolean,version bigint,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_limit is null or p_limit not between 1 and 50 or (p_before_created_at is null) <> (p_before_id is null)
    or (p_before_created_at is not null and not isfinite(p_before_created_at))
    or (p_group_kind is not null and p_group_kind not in ('informal','organization'))
    or char_length(p_search)>120 or (p_locality is not null and (char_length(p_locality) not between 1 and 120 or p_locality ~ '^[[:space:]]|[[:space:]]$')) then
    raise exception using errcode='22023',message='Invalid group filters, page size or paired cursor.';
  end if;
  return query select g.id,g.name,g.description,g.group_kind,g.locality,g.volunteering_focus,g.version,g.created_at,g.updated_at
    from private.community_groups g
    join private.community_group_managers m on m.group_id=g.id
    join public.profiles p on p.id=m.profile_id and p.display_name is not null
    join auth.users a on a.id=p.id
    where g.publication_state='published' and not g.directory_suppressed
      and (p_search is null or strpos(lower(g.name || ' ' || g.description),lower(p_search))>0)
      and (p_group_kind is null or g.group_kind=p_group_kind)
      and (p_volunteering_focus is null or g.volunteering_focus=p_volunteering_focus)
      and (p_locality is null or lower(g.locality)=lower(p_locality))
      and (p_before_id is null or (g.created_at,g.id)<(p_before_created_at,p_before_id))
    order by g.created_at desc,g.id desc limit p_limit;
end;
$$;
create function public.get_public_group(p_group_id uuid)
returns table(group_id uuid,name text,description text,group_kind text,locality text,volunteering_focus boolean,version bigint,created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select g.id,g.name,g.description,g.group_kind,g.locality,g.volunteering_focus,g.version,g.created_at,g.updated_at
    from private.community_groups g where g.id=p_group_id and private.group_is_public(g.id);
$$;

create function public.set_group_directory_suppression(p_expected_staff_profile_id uuid,p_group_id uuid,p_client_request_id uuid,
  p_expected_version bigint,p_directory_suppressed boolean,p_reason text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_actor(p_expected_staff_profile_id);
  reason text := regexp_replace(p_reason,'^[[:space:]]+|[[:space:]]+$','','g');
  intent text := private.group_command_hash(jsonb_build_array('suppression',p_group_id,p_expected_version,p_directory_suppressed,reason));
  receipt private.community_group_command_receipts%rowtype;
  current_group private.community_groups%rowtype;
begin
  perform private.require_moderation_staff(actor);
  if p_directory_suppressed is null or reason is null or char_length(reason) not between 10 and 4000 then
    raise exception using errcode='22023',message='Suppression requires an explicit state and a private reason of 10 to 4,000 characters.';
  end if;
  perform private.lock_group_command(actor,p_client_request_id);
  select * into current_group from private.community_groups where id=p_group_id for update;
  perform private.require_group_actor(p_expected_staff_profile_id);
  perform private.require_moderation_staff(actor);
  if current_group.id is null then raise exception using errcode='42501',message='The group is unavailable.'; end if;
  select * into receipt from private.community_group_command_receipts where actor_id=actor and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash<>intent then raise exception using errcode='22023',message='The accepted group command intent differs.'; end if;
    return receipt.accepted_version;
  end if;
  if p_expected_version is null or p_expected_version<>current_group.version then raise sqlstate 'PT409' using message='The group changed. Reload before moderation.'; end if;
  if current_group.directory_suppressed<>p_directory_suppressed then
    update private.community_groups set directory_suppressed=p_directory_suppressed,version=version+1,updated_at=clock_timestamp()
      where id=p_group_id returning * into current_group;
    insert into private.community_group_suppression_actions(group_id,actor_id,directory_suppressed,reason,group_version)
      values(p_group_id,actor,p_directory_suppressed,reason,current_group.version);
    perform private.audit_group_change('group.suppression_changed',actor,p_group_id,current_group.version);
  end if;
  insert into private.community_group_command_receipts(actor_id,client_request_id,group_id,intent_hash,accepted_version)
    values(actor,p_client_request_id,p_group_id,intent,current_group.version);
  return current_group.version;
end;
$$;
create function public.get_group_staff_context(p_expected_staff_profile_id uuid,p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  perform private.require_group_actor(p_expected_staff_profile_id);
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select jsonb_build_object('group_id',g.id,'name',g.name,'description',g.description,'group_kind',g.group_kind,
    'locality',g.locality,'volunteering_focus',g.volunteering_focus,'publication_state',g.publication_state,
    'directory_suppressed',g.directory_suppressed,'version',g.version,'created_at',g.created_at,'updated_at',g.updated_at,
    'original_actor_id',g.original_actor_id,'manager_profile_id',m.profile_id,'publicly_available',private.group_is_public(g.id),
    'latest_suppression_action',(select jsonb_build_object('action_id',s.id,'actor_id',s.actor_id,'reason',s.reason,
      'directory_suppressed',s.directory_suppressed,'created_at',s.created_at,'group_version',s.group_version)
      from private.community_group_suppression_actions s where s.group_id=g.id order by s.group_version desc limit 1))
    into result from private.community_groups g join private.community_group_managers m on m.group_id=g.id where g.id=p_group_id;
  if result is null then raise exception using errcode='42501',message='The group is unavailable.'; end if;
  return result;
end;
$$;

revoke all on function private.protect_community_group_identity(),private.normalize_group_content(jsonb),private.require_group_actor(uuid),
  private.group_is_public(uuid),private.lock_group_command(uuid,uuid),private.group_command_hash(jsonb),private.audit_group_change(text,uuid,uuid,bigint)
  from public,anon,authenticated,service_role;
revoke all on function public.create_group_draft(uuid,uuid,jsonb),public.recover_group_command(uuid,uuid),public.get_own_group(uuid,uuid),
  public.list_own_groups(uuid,integer,timestamptz,uuid),public.update_group(uuid,uuid,uuid,bigint,jsonb),
  public.set_group_publication_state(uuid,uuid,uuid,bigint,text),public.set_group_directory_suppression(uuid,uuid,uuid,bigint,boolean,text),
  public.get_group_staff_context(uuid,uuid),public.list_public_groups(text,text,boolean,text,integer,timestamptz,uuid),public.get_public_group(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_group_draft(uuid,uuid,jsonb),public.recover_group_command(uuid,uuid),public.get_own_group(uuid,uuid),
  public.list_own_groups(uuid,integer,timestamptz,uuid),public.update_group(uuid,uuid,uuid,bigint,jsonb),
  public.set_group_publication_state(uuid,uuid,uuid,bigint,text),public.set_group_directory_suppression(uuid,uuid,uuid,bigint,boolean,text),
  public.get_group_staff_context(uuid,uuid) to authenticated;
grant execute on function public.list_public_groups(text,text,boolean,text,integer,timestamptz,uuid),public.get_public_group(uuid) to anon,authenticated;

-- Profile deletion may null the manager FK, but cannot rewrite appointment
-- provenance or automatically give a future/recreated identity the authority.
create function private.protect_group_manager_authority() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.group_id <> old.group_id or new.appointed_by_actor_id <> old.appointed_by_actor_id
    or new.appointed_at <> old.appointed_at
    or (new.profile_id is distinct from old.profile_id and new.profile_id is not null) then
    raise exception using errcode='55000',message='Group appointment provenance is immutable; transfer is not implemented.';
  end if;
  if old.profile_id is not null and new.profile_id is null then
    insert into private.audit_events(action,target_type,target_id,metadata)
      values('group.manager_unavailable','community_group',old.group_id,
        jsonb_build_object('group_id',old.group_id,'profile_id',old.profile_id));
  end if;
  return new;
end;
$$;
create trigger community_group_manager_authority before update on private.community_group_managers
  for each row execute function private.protect_group_manager_authority();
revoke all on function private.protect_group_manager_authority() from public,anon,authenticated,service_role;
