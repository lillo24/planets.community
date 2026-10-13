-- Additive hardening of WORKSPACE02. Keep its original migration and all three
-- installed single-link RPC signatures/shapes unchanged.
alter table public.project_shared_workspaces
  add column version bigint not null default 1 check (version > 0);

create function private.advance_project_workspace_version()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  -- Includes writes through the legacy setter; timestamps alone are not a CAS
  -- token when multiple writes occur in the same transaction.
  new.version := old.version + 1;
  return new;
end;
$$;
create trigger project_shared_workspaces_version
before update on public.project_shared_workspaces
for each row execute function private.advance_project_workspace_version();

-- No link FK: a confirmed Add remains confirmed after somebody removes its
-- item. Retrying that command must never resurrect a deleted link.
create table private.project_workspace_add_receipts (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  request_id uuid not null,
  display_name text not null,
  workspace_url text not null,
  link_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (actor_id, project_id, request_id)
);
alter table private.project_workspace_add_receipts enable row level security;
revoke all on private.project_workspace_add_receipts from public, anon, authenticated, service_role;

create function private.project_workspace_link_json(w public.project_shared_workspaces)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object('id', w.id, 'project_id', w.project_id,
    'display_name', w.display_name, 'workspace_url', w.workspace_url,
    'created_at', w.created_at, 'updated_at', w.updated_at, 'version', w.version);
$$;

-- The collection API was unmerged/unreleased. Remove its old overloads before
-- introducing defaulted arguments; otherwise PostgREST cannot select a unique
-- function. The deployed legacy get/set/clear APIs are deliberately retained.
drop function public.list_project_workspace_links(uuid, uuid);
drop function public.save_project_workspace_link(uuid, uuid, text, text, uuid);
drop function public.remove_project_workspace_link(uuid, uuid, uuid);

create function public.list_project_workspace_links(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 10,
  p_before_created_at timestamptz default null, p_before_id uuid default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_can_read_project_workspace(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'The current profile cannot access this Project workspace.';
  end if;
  if p_limit is null or p_limit not between 1 and 50
    or (p_before_created_at is null) <> (p_before_id is null) then
    raise exception using errcode = '22023', message = 'A valid bounded workspace page and complete cursor are required.';
  end if;
  -- Existing (project_id, created_at, id) index supports the reverse keyset scan.
  -- The aggregate sees at most p_limit rows, never the entire collection.
  return (
    with page as (
      select w as link from public.project_shared_workspaces w
      where w.project_id = p_project_id and (p_before_created_at is null
        or (w.created_at, w.id) < (p_before_created_at, p_before_id))
      order by w.created_at desc, w.id desc limit p_limit + 1
    ), visible as (
      select link from page order by (link).created_at desc, (link).id desc limit p_limit
    )
    select jsonb_build_object(
      'items', (select coalesce(jsonb_agg(private.project_workspace_link_json(link)
        order by (link).created_at desc, (link).id desc), '[]'::jsonb) from visible),
      'can_manage', private.profile_is_project_manager(p_project_id, actor),
      'next_cursor', case when (select count(*) from page) > p_limit then
        (select jsonb_build_object('created_at', (link).created_at, 'id', (link).id)
          from visible order by (link).created_at, (link).id limit 1)
        else null end
    )
  );
end;
$$;

create function public.get_project_workspace_link(
  p_expected_profile_id uuid, p_project_id uuid, p_link_id uuid
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_can_read_project_workspace(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'The current profile cannot access this Project workspace.';
  end if;
  -- Null is the explicit legitimate removed/missing-item result, not an auth
  -- fallback. It cannot confirm an open or a successful new Add.
  return (select private.project_workspace_link_json(w)
    from public.project_shared_workspaces w where w.project_id = p_project_id and w.id = p_link_id);
end;
$$;

create function public.get_project_workspace_add_receipt(
  p_expected_manager_profile_id uuid, p_project_id uuid, p_client_request_id uuid
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_manager_profile_id);
  receipt private.project_workspace_add_receipts;
begin
  if not private.profile_is_project_manager(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'Only a current Project manager can recover a workspace Add.';
  end if;
  select r.* into receipt from private.project_workspace_add_receipts r
    where r.actor_id = actor and r.project_id = p_project_id and r.request_id = p_client_request_id;
  if not found then return jsonb_build_object('accepted', false); end if;
  return jsonb_build_object('accepted', true, 'link_id', receipt.link_id,
    'display_name', receipt.display_name, 'workspace_url', receipt.workspace_url,
    'item', (select private.project_workspace_link_json(w)
      from public.project_shared_workspaces w where w.project_id = p_project_id and w.id = receipt.link_id));
end;
$$;

create function public.save_project_workspace_link(
  p_expected_manager_profile_id uuid, p_project_id uuid,
  p_display_name text, p_workspace_url text, p_link_id uuid default null,
  p_client_request_id uuid default null, p_expected_version bigint default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  normalized_name text := btrim(p_display_name);
  normalized_url text;
  saved_id uuid;
  receipt private.project_workspace_add_receipts;
begin
  -- Shared Project lock first, as in legacy set/clear and manager lifecycle
  -- mutations. No receipt or item lock is acquired before this authority check.
  perform private.require_project_workspace_manager(p_expected_manager_profile_id, p_project_id);
  normalized_url := private.normalize_project_workspace_url(p_workspace_url);
  if normalized_name is null or char_length(normalized_name) not between 1 and 120
    or normalized_name ~ '[[:cntrl:]]' then
    raise exception using errcode = '22023', message = 'A valid workspace link name is required.';
  end if;
  if p_link_id is null then
    if p_client_request_id is null or p_expected_version is not null then
      raise exception using errcode = '22023', message = 'A workspace Add requires a stable command identity.';
    end if;
    select r.* into receipt from private.project_workspace_add_receipts r
      where r.actor_id = p_expected_manager_profile_id and r.project_id = p_project_id
        and r.request_id = p_client_request_id;
    if found then
      if receipt.display_name <> normalized_name or receipt.workspace_url <> normalized_url then
        raise exception using errcode = '40001', message = 'This workspace Add identity already belongs to different content.';
      end if;
      return receipt.link_id;
    end if;
    insert into public.project_shared_workspaces(project_id, display_name, workspace_url, legacy_slot, created_at, updated_at)
      values (p_project_id, normalized_name, normalized_url,
        not exists (select 1 from public.project_shared_workspaces w where w.project_id = p_project_id and w.legacy_slot),
        clock_timestamp(), clock_timestamp()) returning id into saved_id;
    insert into private.project_workspace_add_receipts(actor_id, project_id, request_id, display_name, workspace_url, link_id)
      values(p_expected_manager_profile_id, p_project_id, p_client_request_id, normalized_name, normalized_url, saved_id);
  else
    if p_expected_version is null or p_expected_version < 1 or p_client_request_id is not null then
      raise exception using errcode = '22023', message = 'Workspace editing requires its expected version.';
    end if;
    update public.project_shared_workspaces w
      set display_name = normalized_name, workspace_url = normalized_url, updated_at = clock_timestamp()
      where w.id = p_link_id and w.project_id = p_project_id and w.version = p_expected_version returning w.id into saved_id;
    if not found then
      if not exists(select 1 from public.project_shared_workspaces w where w.id = p_link_id and w.project_id = p_project_id) then
        raise exception using errcode = 'P0002', message = 'This workspace link was removed or is unavailable.';
      end if;
      raise exception using errcode = '40001', message = 'This workspace link changed. Reload and review it before retrying.';
    end if;
  end if;
  return saved_id;
end;
$$;

create function public.remove_project_workspace_link(
  p_expected_manager_profile_id uuid, p_project_id uuid, p_link_id uuid,
  p_expected_version bigint default null
)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_project_workspace_manager(p_expected_manager_profile_id, p_project_id);
  if p_expected_version is null or p_expected_version < 1 then
    raise exception using errcode = '22023', message = 'Workspace removal requires its expected version.';
  end if;
  delete from public.project_shared_workspaces w
    where w.id = p_link_id and w.project_id = p_project_id and w.version = p_expected_version;
  if not found then
    if not exists(select 1 from public.project_shared_workspaces w where w.id = p_link_id and w.project_id = p_project_id) then
      raise exception using errcode = 'P0002', message = 'This workspace link was removed or is unavailable.';
    end if;
    raise exception using errcode = '40001', message = 'This workspace link changed. Reload and review it before removing.';
  end if;
  return true;
end;
$$;

comment on column public.project_shared_workspaces.version is
  'Item CAS token, advanced by every update including legacy set. Creation order is independent of editing.';
comment on table private.project_workspace_add_receipts is
  'Durable private actor/Project/Add command receipts. Same-content retry returns the original identity, including after removal; independent commands may contain identical content.';
comment on function public.list_project_workspace_links(uuid, uuid, integer, timestamptz, uuid) is
  'Private newest-first keyset page, default 10/max 50. Explicit next cursor; no aggregate over the whole collection.';

revoke all on function private.advance_project_workspace_version() from public, anon, authenticated, service_role;
revoke all on function private.project_workspace_link_json(public.project_shared_workspaces) from public, anon, authenticated, service_role;
revoke all on function public.list_project_workspace_links(uuid, uuid, integer, timestamptz, uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_project_workspace_link(uuid, uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_project_workspace_add_receipt(uuid, uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.save_project_workspace_link(uuid, uuid, text, text, uuid, uuid, bigint) from public, anon, authenticated, service_role;
revoke all on function public.remove_project_workspace_link(uuid, uuid, uuid, bigint) from public, anon, authenticated, service_role;
grant execute on function public.list_project_workspace_links(uuid, uuid, integer, timestamptz, uuid) to authenticated;
grant execute on function public.get_project_workspace_link(uuid, uuid, uuid) to authenticated;
grant execute on function public.get_project_workspace_add_receipt(uuid, uuid, uuid) to authenticated;
grant execute on function public.save_project_workspace_link(uuid, uuid, text, text, uuid, uuid, bigint) to authenticated;
grant execute on function public.remove_project_workspace_link(uuid, uuid, uuid, bigint) to authenticated;
