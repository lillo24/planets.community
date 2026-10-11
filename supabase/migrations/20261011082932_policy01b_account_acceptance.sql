-- POLICY01B: private account-level Terms/Rules acknowledgements, independent of
-- profile completion. Published versions are registered by reviewed migrations.
create table private.policy_bundle_versions (
  bundle_version text primary key,
  constraint policy_bundle_versions_valid check (
    length(bundle_version) between 1 and 100
    and bundle_version = btrim(bundle_version)
  )
);

insert into private.policy_bundle_versions (bundle_version)
values ('POLICY01-2026-10-08-v1');

create table private.policy_acceptances (
  account_id uuid not null references auth.users (id) on delete cascade,
  bundle_version text not null references private.policy_bundle_versions (bundle_version),
  accepted_at timestamptz not null default clock_timestamp(),
  primary key (account_id, bundle_version)
);

create index policy_acceptances_bundle_version_idx
  on private.policy_acceptances (bundle_version);

comment on table private.policy_acceptances is
  'First explicit authenticated Terms/Rules acceptance per account and published bundle. No client timestamp, marketing consent or proof of reading. Account erasure also removes these rows; no independent retention exemption is introduced.';
comment on table private.policy_bundle_versions is
  'Published Terms/Rules versions registered by additive migration alongside coordinated mobile/site bundle changes. Clients cannot register versions.';

alter table private.policy_bundle_versions enable row level security;
alter table private.policy_acceptances enable row level security;
revoke all on table private.policy_bundle_versions, private.policy_acceptances
  from public, anon, authenticated, service_role;

create function private.require_policy_acceptance_account(
  p_expected_account_id uuid,
  p_bundle_version text
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
begin
  if actor_id is null or p_expected_account_id is distinct from actor_id
    or not exists (select 1 from auth.users as account where account.id = actor_id) then
    raise exception using errcode = '42501',
      message = 'The authenticated account must match the expected policy account.';
  end if;
  if p_bundle_version is null or not exists (
    select 1 from private.policy_bundle_versions as bundle
    where bundle.bundle_version = p_bundle_version
  ) then
    raise exception using errcode = '22023',
      message = 'A registered policy bundle version is required.';
  end if;
  return actor_id;
end;
$$;

create function public.get_policy_acceptance(
  p_expected_account_id uuid,
  p_bundle_version text
)
returns table (account_id uuid, bundle_version text, accepted_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := private.require_policy_acceptance_account(p_expected_account_id, p_bundle_version);
begin
  return query
    select acceptance.account_id, acceptance.bundle_version, acceptance.accepted_at
    from private.policy_acceptances as acceptance
    where acceptance.account_id = actor_id and acceptance.bundle_version = p_bundle_version;
end;
$$;

create function public.accept_policy_bundle(
  p_expected_account_id uuid,
  p_bundle_version text
)
returns table (account_id uuid, bundle_version text, accepted_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := private.require_policy_acceptance_account(p_expected_account_id, p_bundle_version);
begin
  -- The unique key serializes simultaneous device submissions. DO NOTHING
  -- preserves the initial server timestamp; the next statement sees its winner.
  insert into private.policy_acceptances (account_id, bundle_version)
  values (actor_id, p_bundle_version)
  on conflict on constraint policy_acceptances_pkey do nothing;

  return query
    select acceptance.account_id, acceptance.bundle_version, acceptance.accepted_at
    from private.policy_acceptances as acceptance
    where acceptance.account_id = actor_id and acceptance.bundle_version = p_bundle_version;
end;
$$;

revoke all on function private.require_policy_acceptance_account(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.get_policy_acceptance(uuid, text), public.accept_policy_bundle(uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.get_policy_acceptance(uuid, text), public.accept_policy_bundle(uuid, text)
  to authenticated;

comment on function public.get_policy_acceptance(uuid, text) is
  'Exact registered version read for auth.uid(), with expected-account race protection. Zero rows means no acceptance; all failures are errors.';
comment on function public.accept_policy_bundle(uuid, text) is
  'Explicit idempotent acknowledgement returning the original server timestamp. Existing domain operations retain their authorization; this is not a database-wide acceptance gate.';
