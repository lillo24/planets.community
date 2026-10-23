-- COCREATE A01. This gate is independent of every client Sandbox preference.
create table private.cocreate_settings (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  policy_bundle_version text not null references private.policy_bundle_versions(bundle_version),
  post_lifetime_days integer not null default 30 check (post_lifetime_days between 1 and 90),
  max_open_posts integer not null default 5 check (max_open_posts between 1 and 20),
  request_cooldown_seconds integer not null default 300 check (request_cooldown_seconds between 60 and 86400),
  recruitment_cooldown_seconds integer not null default 3600 check (recruitment_cooldown_seconds between 60 and 86400)
);
insert into private.cocreate_settings(singleton,policy_bundle_version)
values (true,'POLICY01-2026-10-08-v1');
alter table private.cocreate_settings enable row level security;
revoke all on private.cocreate_settings from public,anon,authenticated,service_role;
comment on table private.cocreate_settings is
  'Experimental owner-controlled availability and bounded limits. Default OFF. No client activation endpoint; enable only in the owned disposable local setup. Policy acceptance reuses the published bundle, never a second consent.';

create function public.get_cocreate_availability() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('enabled',coalesce((select enabled from private.cocreate_settings where singleton),false));
$$;
create function private.require_cocreate_enabled() returns void
language plpgsql stable security definer set search_path='' as $$
begin
  if not coalesce((select enabled from private.cocreate_settings where singleton),false) then
    raise sqlstate '42501' using message='Co-creation is unavailable.';
  end if;
end;
$$;
create function private.cocreate_account_available(p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.users a join public.profiles p on p.id=a.id
    where a.id=p_actor and a.deleted_at is null
      and (a.banned_until is null or a.banned_until <= statement_timestamp())
      and not coalesce(a.is_anonymous,false) and p.display_name is not null);
$$;
create function private.require_cocreate_identity(p_expected_profile_id uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  -- Own-exit/recovery may use this identity-only boundary with gate OFF.
  -- It never grants history, send, admission or another person's metadata.
  return actor;
end;
$$;
create function private.require_cocreate_actor(p_expected_profile_id uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;
begin
  perform private.require_cocreate_enabled();
  actor:=private.require_cocreate_identity(p_expected_profile_id);
  if not private.cocreate_account_available(actor) or not exists(
    select 1 from private.policy_acceptances a join private.cocreate_settings c
      on c.singleton and c.policy_bundle_version=a.bundle_version where a.account_id=actor
  ) then
    raise sqlstate '42501' using message='Co-creation is unavailable for this account.';
  end if;
  return actor;
end;
$$;
revoke all on function public.get_cocreate_availability() from public,anon,authenticated,service_role;
grant execute on function public.get_cocreate_availability() to anon,authenticated;
revoke all on function private.require_cocreate_enabled(),
  private.cocreate_account_available(uuid),private.require_cocreate_identity(uuid),
  private.require_cocreate_actor(uuid) from public,anon,authenticated,service_role;
