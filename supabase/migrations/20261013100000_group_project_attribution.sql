-- GRP03C: publication provenance, never inherited Project authority.
alter table public.projects
  add column attributed_group_id uuid,
  add column attribution_version bigint not null default 0 check (attribution_version >= 0),
  add column attribution_assigned_by uuid,
  add column attribution_assigned_at timestamptz,
  add column first_published_at timestamptz,
  add column attribution_published_by uuid;
comment on column public.projects.attributed_group_id is
  'Private draft selection, frozen at first publication. Raw UUID provenance has no account/group deletion blocker and conveys no Project authority.';
-- Every previously published Project is permanently personal, including terminal
-- sources. No retrofit, history rewrite, template inheritance or authority copy.
update public.projects p set first_published_at = s.published_at
from (select id,published_at from public.proposals where published_at is not null
  union all select id,published_at from public.recurring_activities where published_at is not null) s
where s.id=p.id;
create index projects_group_publication_idx on public.projects
  (attributed_group_id,first_published_at desc,id desc)
  where attributed_group_id is not null and first_published_at is not null;

create table private.project_attribution_receipts (
  actor_id uuid not null,
  command_kind text not null,
  client_request_id uuid not null,
  intent_hash text not null,
  project_id uuid not null,
  accepted_result jsonb not null,
  accepted_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,command_kind,client_request_id)
);
alter table private.project_attribution_receipts enable row level security;
revoke all on private.project_attribution_receipts from public,anon,authenticated,service_role;
create trigger project_attribution_receipts_append_only before update or delete
on private.project_attribution_receipts for each row execute function private.protect_moderation_append_only();

create function private.require_project_group_representation(p_actor uuid,p_group uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  -- Source -> Project anchor -> group -> sorted Auth identities -> profiles.
  -- All group content, suppression and role commands hold this same group row.
  -- Identity locks also serialize deletion/incompleteness with this decision.
  -- No block-pair/relationship lock is acquired: this is structural publication,
  -- not a new social interaction or a grant of Project authority.
  perform 1 from private.community_groups where id=p_group for update;
  perform 1 from auth.users a where a.id=p_actor or a.id in
    (select profile_id from private.community_group_managers where group_id=p_group)
    order by a.id for share;
  perform 1 from public.profiles p where p.id=p_actor or p.id in
    (select profile_id from private.community_group_managers where group_id=p_group)
    order by p.id for share;
  perform private.require_group_identity(p_actor);
  if not private.group_is_public(p_group)
    or private.group_authority_role(p_group,p_actor) not in ('creator','co_creator')
    or private.group_authority_role(p_group,p_actor) is null then
    raise sqlstate '42501' using message='Group representation is unavailable. Refresh or publish personally.',
      detail=jsonb_build_object('reason','group_representation_unavailable')::text;
  end if;
end;
$$;

create function private.project_group_binding(p_project uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('project_id',p.id,'group_id',p.attributed_group_id,
    'version',p.attribution_version,'frozen',p.first_published_at is not null,
    'group_available',coalesce(private.group_is_public(p.attributed_group_id),false),
    'group_name',case when private.group_is_public(p.attributed_group_id) then
      (select name from private.community_groups where id=p.attributed_group_id) end)
  from public.projects p where p.id=p_project;
$$;

create function public.get_own_project_group(p_expected_profile_id uuid,p_project_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := private.require_group_identity(p_expected_profile_id);
begin
  if not exists(select 1 from public.projects where id=p_project_id and creator_profile_id=actor) then
    raise sqlstate '42501' using message='The Project is unavailable.';
  end if;
  return private.project_group_binding(p_project_id);
end;
$$;

create function private.assign_project_group(p_actor uuid,p_project uuid,p_version bigint,p_group uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare project public.projects%rowtype;
begin
  -- Match existing content/publication source-first locking, preventing cycles
  -- between an association save and an ordinary editor save/publication.
  perform 1 from public.proposals where id=p_project for update;
  perform 1 from public.recurring_activities where id=p_project for update;
  select * into project from public.projects where id=p_project for update;
  perform private.require_group_identity(p_actor);
  if project.id is null or project.creator_profile_id<>p_actor then
    raise sqlstate '42501' using message='The Project is unavailable.';
  end if;
  if project.first_published_at is not null then
    raise sqlstate '55000' using message='Publication attribution is frozen.';
  end if;
  if p_version is null or project.attribution_version<>p_version then
    raise sqlstate 'PT409' using message='Project attribution changed. Reload the draft.';
  end if;
  -- Clearing is deliberately available after representation is lost.
  if p_group is not null then perform private.require_project_group_representation(p_actor,p_group); end if;
  update public.projects set attributed_group_id=p_group,
    attribution_version=attribution_version+1,
    attribution_assigned_by=p_actor,attribution_assigned_at=clock_timestamp()
    where id=p_project;
  insert into private.audit_events(action,target_type,target_id,metadata)
    values('project.group_assigned','project',p_project,
      jsonb_build_object('actor_id',p_actor,'group_id',p_group,'version',project.attribution_version+1));
  return private.project_group_binding(p_project);
end;
$$;

create function public.set_project_group(p_expected_profile_id uuid,p_project_id uuid,
  p_client_request_id uuid,p_expected_version bigint,p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid := private.require_group_identity(p_expected_profile_id);
  intent text := private.group_command_hash(jsonb_build_array(p_project_id,p_expected_version,p_group_id));
  receipt private.project_attribution_receipts%rowtype;
  result jsonb;
begin
  if p_client_request_id is null then raise sqlstate '22023' using message='A request ID is required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('project.group:'||actor::text||':'||p_client_request_id::text,0));
  perform private.require_group_identity(p_expected_profile_id);
  select * into receipt from private.project_attribution_receipts where actor_id=actor
    and command_kind='set' and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash<>intent then raise sqlstate '22023' using message='The accepted attribution intent differs.'; end if;
    if not exists(select 1 from public.projects where id=p_project_id and creator_profile_id=actor) then
      raise sqlstate '42501' using message='The Project is unavailable.';
    end if;
    return receipt.accepted_result;
  end if;
  result := private.assign_project_group(actor,p_project_id,p_expected_version,p_group_id);
  insert into private.project_attribution_receipts(actor_id,command_kind,client_request_id,intent_hash,project_id,accepted_result)
    values(actor,'set',p_client_request_id,intent,p_project_id,result);
  return result;
end;
$$;

create function private.freeze_project_group_publication() returns trigger
language plpgsql security definer set search_path='' as $$
declare project public.projects%rowtype;
begin
  if new.published_at is null then return new; end if;
  -- Already-published edits/lifecycle changes retain ordinary lock behavior.
  -- The marker is immutable and every first publication below freezes it.
  if tg_op='UPDATE' and old.published_at is not null then return new; end if;
  select * into project from public.projects where id=new.id for update;
  if project.first_published_at is not null then return new; end if;
  if project.attributed_group_id is not null then
    -- Also covers legacy RPCs and trusted direct source transitions. A source
    -- owner cannot publish a grouped draft under an absent/forged actor.
    if auth.uid() is distinct from project.creator_profile_id then
      raise sqlstate '42501' using message='The real Project Creator must publish this association.';
    end if;
    perform private.require_project_group_representation(project.creator_profile_id,project.attributed_group_id);
    perform 1 from public.profile_photos where profile_id=project.creator_profile_id for share;
    if not private.has_current_profile_photo(project.creator_profile_id) then
      raise sqlstate 'PT422' using message='A current profile photo is required for this trust-sensitive action.';
    end if;
  end if;
  update public.projects set first_published_at=new.published_at,
    attribution_published_by=case when auth.uid()=creator_profile_id then auth.uid() end where id=new.id;
  if project.attributed_group_id is not null then
    insert into private.audit_events(action,target_type,target_id,metadata)
      values('project.group_published','project',new.id,
        jsonb_build_object('actor_id',project.creator_profile_id,'group_id',project.attributed_group_id,'version',project.attribution_version));
  end if;
  return new;
end;
$$;
-- Alphabetically after the source-registration AFTER INSERT trigger. Every
-- source path shares this guard; exceptions roll back source/outbox/template.
create trigger zz_proposals_freeze_group_publication after insert or update on public.proposals
  for each row execute function private.freeze_project_group_publication();
create trigger zz_recurring_freeze_group_publication after insert or update on public.recurring_activities
  for each row execute function private.freeze_project_group_publication();

create function private.protect_frozen_project_group() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.first_published_at is not null and
    (new.attributed_group_id is distinct from old.attributed_group_id
      or new.attribution_version<>old.attribution_version
      or new.attribution_assigned_by is distinct from old.attribution_assigned_by
      or new.attribution_assigned_at is distinct from old.attribution_assigned_at
      or new.first_published_at is distinct from old.first_published_at
      or new.attribution_published_by is distinct from old.attribution_published_by) then
    raise sqlstate '55000' using message='Publication attribution is frozen.';
  end if;
  return new;
end;
$$;
create trigger projects_protect_group_publication before update on public.projects
  for each row execute function private.protect_frozen_project_group();

create function public.list_my_publishable_groups(p_expected_profile_id uuid,p_limit integer default 20,
  p_cursor_created_at timestamptz default null,p_cursor_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := private.require_group_identity(p_expected_profile_id);
begin
  if p_limit is null or p_limit not between 1 and 50
    or (p_cursor_created_at is null)<>(p_cursor_id is null) then
    raise sqlstate '22023' using message='A bounded page and paired cursor are required.';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.id desc),'[]') from
    (select g.id,g.name,g.group_kind,g.created_at from private.community_groups g
      join (select group_id from private.community_group_managers where profile_id=actor
        union select group_id from private.group_delegates where profile_id=actor
          and revoked_at is null and delegate_role='co_creator') represented on represented.group_id=g.id
      where private.group_is_public(g.id) and private.group_authority_role(g.id,actor) in ('creator','co_creator')
        and (p_cursor_id is null or (g.created_at,g.id)<(p_cursor_created_at,p_cursor_id))
      order by g.created_at desc,g.id desc limit p_limit) page);
end;
$$;

create function public.get_public_project_groups(p_project_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if p_project_ids is null or cardinality(p_project_ids)>50 then
    raise sqlstate '22023' using message='At most 50 Project IDs are required.';
  end if;
  return (select coalesce(jsonb_agg(case when private.group_is_public(p.attributed_group_id) then
    jsonb_build_object('project_id',p.id,'state','group','group_id',g.id,'name',g.name,'group_kind',g.group_kind)
    else jsonb_build_object('project_id',p.id,'state','unavailable') end),'[]')
    from public.projects p left join private.community_groups g on g.id=p.attributed_group_id
    where p.id=any(p_project_ids) and p.attributed_group_id is not null
      and p.first_published_at is not null and private.is_project_publicly_viewable(p.id));
end;
$$;

create function public.list_public_group_projects(p_group_id uuid,p_limit integer default 20,
  p_cursor_published_at timestamptz default null,p_cursor_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if p_group_id is null or p_limit is null or p_limit not between 1 and 50
    or (p_cursor_published_at is null)<>(p_cursor_id is null) then
    raise sqlstate '22023' using message='A group, bounded page and paired cursor are required.';
  end if;
  if not private.group_is_public(p_group_id) then
    raise sqlstate '42501' using message='The group is unavailable.';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(page) order by page.published_at desc,page.project_id desc),'[]') from
    (select p.id project_id,p.project_kind,p.first_published_at published_at,
      coalesce(o.title,r.title) title,coalesce(o.summary,r.summary) summary,
      o.definition_phase,
      coalesce(o.lifecycle_state::text,r.lifecycle_state::text) lifecycle_state
      from public.projects p left join public.proposals o on o.id=p.id
      left join public.recurring_activities r on r.id=p.id
      where p.attributed_group_id=p_group_id and p.first_published_at is not null
        and private.is_project_publicly_viewable(p.id)
        and (p_cursor_id is null or (p.first_published_at,p.id)<(p_cursor_published_at,p_cursor_id))
      order by p.first_published_at desc,p.id desc limit p_limit) page);
end;
$$;

revoke all on function private.require_project_group_representation(uuid,uuid),
  private.project_group_binding(uuid),private.assign_project_group(uuid,uuid,bigint,uuid),
  private.freeze_project_group_publication(),private.protect_frozen_project_group()
  from public,anon,authenticated,service_role;
revoke all on function public.get_own_project_group(uuid,uuid),public.set_project_group(uuid,uuid,uuid,bigint,uuid),
  public.list_my_publishable_groups(uuid,integer,timestamptz,uuid),public.get_public_project_groups(uuid[]),
  public.list_public_group_projects(uuid,integer,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_project_group(uuid,uuid),public.set_project_group(uuid,uuid,uuid,bigint,uuid),
  public.list_my_publishable_groups(uuid,integer,timestamptz,uuid) to authenticated;
grant execute on function public.get_public_project_groups(uuid[]),public.list_public_group_projects(uuid,integer,timestamptz,uuid)
  to anon,authenticated;
