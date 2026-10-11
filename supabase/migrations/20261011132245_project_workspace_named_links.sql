-- Upgrade in place: no copy/backfill retry can duplicate an existing URL.
alter table public.project_shared_workspaces
  add column id uuid not null default gen_random_uuid(),
  add column display_name text not null default 'Workspace',
  add column legacy_slot boolean not null default true;
alter table public.project_shared_workspaces
  drop constraint project_shared_workspaces_pkey,
  add constraint project_shared_workspaces_pkey primary key (id),
  add constraint project_shared_workspaces_name_valid check (
    display_name = btrim(display_name)
    and char_length(display_name) between 1 and 120
    and display_name !~ '[[:cntrl:]]'
  );
alter table public.project_shared_workspaces alter column legacy_slot set default false;
create index project_shared_workspaces_order_idx
  on public.project_shared_workspaces(project_id, created_at, id);
create unique index project_shared_workspaces_legacy_idx
  on public.project_shared_workspaces(project_id) where legacy_slot;
comment on table public.project_shared_workspaces is
  'Private named HTTPS link collection. RPC-only; names and URLs never enter public projections, templates or events.';
comment on column public.project_shared_workspaces.legacy_slot is
  'At most one compatibility entry per Project. Legacy get/set/clear operate only on this entry; deletion never promotes another link.';

create function private.require_project_workspace_manager(p_expected_profile_id uuid, p_project_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  perform 1 from public.projects where id = p_project_id for update;
  if not found or not private.profile_is_project_manager(p_project_id, actor) then
    raise exception using errcode = '42501',
      message = 'Only a current Project manager can manage its workspace.';
  end if;
end;
$$;

create function public.list_project_workspace_links(p_expected_profile_id uuid, p_project_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_can_read_project_workspace(p_project_id, actor) then
    raise exception using errcode = '42501',
      message = 'The current profile cannot access this Project workspace.';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'id', w.id, 'project_id', w.project_id, 'display_name', w.display_name,
    'workspace_url', w.workspace_url, 'created_at', w.created_at, 'updated_at', w.updated_at
  ) order by w.created_at, w.id), '[]'::jsonb)
    from public.project_shared_workspaces w where w.project_id = p_project_id);
end;
$$;

-- Both add and update are item-specific; never replace a caller's stale list.
create function public.save_project_workspace_link(
  p_expected_manager_profile_id uuid, p_project_id uuid,
  p_display_name text, p_workspace_url text, p_link_id uuid default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  normalized_name text := btrim(p_display_name);
  normalized_url text;
  saved_id uuid;
begin
  perform private.require_project_workspace_manager(p_expected_manager_profile_id, p_project_id);
  normalized_url := private.normalize_project_workspace_url(p_workspace_url);
  if normalized_name is null or char_length(normalized_name) not between 1 and 120
    or normalized_name ~ '[[:cntrl:]]' then
    raise exception using errcode = '22023', message = 'A valid workspace link name is required.';
  end if;
  if p_link_id is null then
    insert into public.project_shared_workspaces(project_id, display_name, workspace_url, legacy_slot, created_at, updated_at)
      values (p_project_id, normalized_name, normalized_url,
        not exists (select 1 from public.project_shared_workspaces w where w.project_id = p_project_id and w.legacy_slot),
        clock_timestamp(), clock_timestamp()) returning id into saved_id;
  else
    update public.project_shared_workspaces w
      set display_name = normalized_name, workspace_url = normalized_url, updated_at = clock_timestamp()
      where w.id = p_link_id and w.project_id = p_project_id returning w.id into saved_id;
    if not found then
      raise exception using errcode = '42501', message = 'This workspace link is unavailable.';
    end if;
  end if;
  return saved_id;
end;
$$;

create function public.remove_project_workspace_link(
  p_expected_manager_profile_id uuid, p_project_id uuid, p_link_id uuid
)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_project_workspace_manager(p_expected_manager_profile_id, p_project_id);
  delete from public.project_shared_workspaces w where w.id = p_link_id and w.project_id = p_project_id;
  if not found then
    raise exception using errcode = '42501', message = 'This workspace link is unavailable.';
  end if;
  return true;
end;
$$;

-- Keep exact deployed signatures and result shapes. The designated entry is
-- shared with the new APIs, never a divergent duplicate or a whole-list clear.
create or replace function public.get_own_project_shared_workspace(p_expected_profile_id uuid, p_project_id uuid)
returns table(project_id uuid, workspace_url text, updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_can_read_project_workspace(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'The current profile cannot access this Project workspace.';
  end if;
  return query select w.project_id, w.workspace_url, w.updated_at
    from public.project_shared_workspaces w where w.project_id = p_project_id and w.legacy_slot;
end;
$$;

create or replace function public.set_project_shared_workspace(
  p_expected_manager_profile_id uuid, p_project_id uuid, p_workspace_url text
)
returns table(project_id uuid, workspace_url text, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_manager_profile_id);
  normalized_url text := private.normalize_project_workspace_url(p_workspace_url);
begin
  -- Keep the existing Project-first concurrency and actor contract explicit.
  perform 1 from public.projects p where p.id = p_project_id for update;
  if not found or not private.profile_is_project_manager(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'Only a current Project manager can manage its workspace.';
  end if;
  update public.project_shared_workspaces w
    set workspace_url = normalized_url, updated_at = statement_timestamp()
    where w.project_id = p_project_id and w.legacy_slot;
  if not found then
    insert into public.project_shared_workspaces(project_id, workspace_url, legacy_slot, created_at, updated_at)
      values (p_project_id, normalized_url, true, statement_timestamp(), statement_timestamp());
  end if;
  return query select w.project_id, w.workspace_url, w.updated_at
    from public.project_shared_workspaces w where w.project_id = p_project_id and w.legacy_slot;
end;
$$;

create or replace function public.clear_project_shared_workspace(p_expected_manager_profile_id uuid, p_project_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_project_workspace_manager(p_expected_manager_profile_id, p_project_id);
  delete from public.project_shared_workspaces w where w.project_id = p_project_id and w.legacy_slot;
  return found;
end;
$$;

comment on function public.get_own_project_shared_workspace(uuid, uuid) is
  'Legacy API: reads only the designated compatibility entry. Current group entitlement is required.';
comment on function public.set_project_shared_workspace(uuid, uuid, text) is
  'Legacy API: creates/updates only the compatibility entry; preserves its editable name and all additional links.';
comment on function public.clear_project_shared_workspace(uuid, uuid) is
  'Legacy API: clears only the compatibility entry, never promotes or deletes other links.';

revoke all on function private.require_project_workspace_manager(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.list_project_workspace_links(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.save_project_workspace_link(uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.remove_project_workspace_link(uuid, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_project_workspace_links(uuid, uuid) to authenticated;
grant execute on function public.save_project_workspace_link(uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.remove_project_workspace_link(uuid, uuid, uuid) to authenticated;
