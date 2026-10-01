create table public.project_shared_workspaces (
  project_id uuid primary key
    constraint project_shared_workspaces_project_id_fkey
      references public.projects (id) on delete cascade,
  workspace_url text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_shared_workspaces_url_length check (
    char_length(workspace_url) between 1 and 2048
  ),
  constraint project_shared_workspaces_url_trimmed check (
    workspace_url = btrim(workspace_url)
  ),
  constraint project_shared_workspaces_url_https check (
    workspace_url ~ '^https://[^/?#@]+([/?#].*)?$'
    and workspace_url !~ '[[:space:][:cntrl:]]'
    and substring(workspace_url from '^https://([^/?#]+)') ~
      '^([A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$'
  )
);

comment on table public.project_shared_workspaces is
  'One current provider-neutral external workspace link per Project. The URL is group-sensitive and is exposed only through identity-bound RPCs.';
comment on column public.project_shared_workspaces.workspace_url is
  'Absolute HTTPS workspace URL. External providers own file content and access permissions; this value must never enter public Project reads or generic event payloads.';

alter table public.project_shared_workspaces enable row level security;
revoke all privileges on table public.project_shared_workspaces
  from public, anon, authenticated, service_role;

create function private.normalize_project_workspace_url(p_workspace_url text)
returns text
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  normalized_url text := btrim(p_workspace_url);
  authority text;
begin
  if p_workspace_url is null
    or normalized_url = ''
    or char_length(normalized_url) > 2048
    or normalized_url !~ '^https://[^/?#@]+([/?#].*)?$'
    or normalized_url ~ '[[:space:][:cntrl:]]' then
    raise exception using
      errcode = '22023',
      message = 'A valid absolute HTTPS workspace URL is required.';
  end if;

  authority := substring(normalized_url from '^https://([^/?#]+)');
  if authority is null
    or authority !~
      '^([A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$' then
    raise exception using
      errcode = '22023',
      message = 'A valid absolute HTTPS workspace URL is required.';
  end if;

  return normalized_url;
end;
$$;

create function private.profile_can_read_project_workspace(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile_id is not null and (
    private.profile_is_project_manager(p_project_id, p_profile_id)
    or private.profile_has_current_project_membership(
      p_project_id,
      p_profile_id
    )
  );
$$;

create function public.get_own_project_shared_workspace(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns table (
  project_id uuid,
  workspace_url text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
begin
  if not private.profile_can_read_project_workspace(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The current profile cannot access this Project workspace.';
  end if;

  return query
  select workspace.project_id, workspace.workspace_url, workspace.updated_at
  from public.project_shared_workspaces as workspace
  where workspace.project_id = p_project_id;
end;
$$;

create function public.set_project_shared_workspace(
  p_expected_manager_profile_id uuid,
  p_project_id uuid,
  p_workspace_url text
)
returns table (
  project_id uuid,
  workspace_url text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  normalized_url text := private.normalize_project_workspace_url(
    p_workspace_url
  );
begin
  perform 1
  from public.projects as project
  where project.id = p_project_id
  for update;

  if not found
    or not private.profile_is_project_manager(
      p_project_id,
      current_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can manage its workspace.';
  end if;

  insert into public.project_shared_workspaces as workspace (
    project_id,
    workspace_url,
    created_at,
    updated_at
  ) values (
    p_project_id,
    normalized_url,
    statement_timestamp(),
    statement_timestamp()
  )
  on conflict on constraint project_shared_workspaces_pkey do update
  set workspace_url = excluded.workspace_url,
      updated_at = statement_timestamp();

  return query
  select workspace.project_id, workspace.workspace_url, workspace.updated_at
  from public.project_shared_workspaces as workspace
  where workspace.project_id = p_project_id;
end;
$$;

create function public.clear_project_shared_workspace(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  deleted_count integer;
begin
  perform 1
  from public.projects as project
  where project.id = p_project_id
  for update;

  if not found
    or not private.profile_is_project_manager(
      p_project_id,
      current_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can manage its workspace.';
  end if;

  delete from public.project_shared_workspaces as workspace
  where workspace.project_id = p_project_id;
  get diagnostics deleted_count = row_count;
  return deleted_count = 1;
end;
$$;

comment on function public.get_own_project_shared_workspace(uuid, uuid) is
  'Returns zero or one private workspace link to a current Project manager or current participant. Historical chat entitlement is deliberately insufficient.';
comment on function public.set_project_shared_workspace(uuid, uuid, text) is
  'Serializes on the Project and sets one normalized HTTPS workspace URL for the current Creator, Co-creator, or Co-organizer.';
comment on function public.clear_project_shared_workspace(uuid, uuid) is
  'Idempotently clears the private workspace link for the current Creator, Co-creator, or Co-organizer.';

revoke all on function private.normalize_project_workspace_url(text)
  from public, anon, authenticated, service_role;
revoke all on function private.profile_can_read_project_workspace(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_own_project_shared_workspace(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.set_project_shared_workspace(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.clear_project_shared_workspace(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.get_own_project_shared_workspace(uuid, uuid)
  to authenticated;
grant execute on function public.set_project_shared_workspace(uuid, uuid, text)
  to authenticated;
grant execute on function public.clear_project_shared_workspace(uuid, uuid)
  to authenticated;
