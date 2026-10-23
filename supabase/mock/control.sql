-- Separate, explicitly invoked mock control installation; never normal migrations.
do $$ begin
  if not exists(select 1 from mock_control.environment where singleton
    and project_ref='pnolarmzxmmjtguligfc' and operator_confirmed) then
    raise exception 'Missing independently confirmed mock marker';
  end if;
end $$;

-- Mock Auth never hands email/SMS to a provider. Admin generate-link plus the
-- ordinary verify exchange does not send a message and remains the broker path.
create or replace function mock_control.deny_external_auth_delivery(event jsonb)
returns jsonb language sql immutable set search_path='' as $$
  select jsonb_build_object('error',jsonb_build_object(
    'http_code',403,'message','External Auth delivery is disabled in this mock environment.'))
$$;
revoke all on function mock_control.deny_external_auth_delivery(jsonb) from public,anon,authenticated,service_role;
grant usage on schema mock_control to supabase_auth_admin;
grant execute on function mock_control.deny_external_auth_delivery(jsonb) to supabase_auth_admin;

create table if not exists mock_control.personas (
  persona_key text primary key check(persona_key ~ '^[a-z]{2,20}$'),
  user_id uuid not null unique references auth.users(id),
  email text not null unique check(email ~ '^[a-z]+@personas\.planets\.invalid$'),
  display_name text not null check(length(display_name) between 2 and 60),
  scenario text not null check(length(scenario) between 1 and 240),
  available boolean not null default true
);

-- One-time migration from the retired human-enrollment implementation. This
-- affects mock controls/recorded mock sessions only, never canonical content.
do $$ begin
  if to_regclass('mock_control.testers') is not null then
    if exists(select 1 from mock_control.environment where enabled) then
      raise exception 'Disable mock issuance before upgrading access controls';
    end if;
    delete from auth.sessions s using mock_control.deliveries d,mock_control.personas p
      where s.id=d.session_id and s.user_id=p.user_id;
    drop function if exists public.mock_control_catalog(text,uuid);
    drop function if exists public.mock_control_claim(text,uuid,uuid,text);
    drop function if exists public.mock_control_finish(text,uuid,uuid,uuid,text);
    drop function if exists public.mock_control_retire(text,uuid,uuid,text);
    drop function if exists public.mock_control_offboard(text,uuid);
    drop table mock_control.deliveries;
    drop table mock_control.catalog_rate;
    drop table mock_control.testers;
  end if;
end $$;

create table if not exists mock_control.clients (
  id uuid primary key default gen_random_uuid(),
  capability_hash text not null unique check(capability_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz not null default now()
);
create table if not exists mock_control.client_deliveries (
  client_id uuid not null references mock_control.clients(id),
  request_id uuid not null,
  persona_key text not null references mock_control.personas(persona_key),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '2 minutes',
  state text not null check(state in ('pending','issued','retired')),
  session_id uuid,
  encrypted_delivery text,
  primary key(client_id,request_id)
);
create index if not exists mock_client_delivery_time
  on mock_control.client_deliveries(client_id,created_at desc);
create table if not exists mock_control.fixtures (
  fixture_key text primary key, object_id uuid not null,
  initial_digest text not null, receipt jsonb not null
);
create table if not exists mock_control.client_rate (
  client_id uuid not null references mock_control.clients(id),
  kind text not null check(kind in ('catalog','issue','retire')),
  window_start timestamptz not null,requests integer not null check(requests>0),
  primary key(client_id,kind)
);
create table if not exists mock_control.global_rate (
  kind text primary key check(kind in ('bootstrap','catalog','issue','retire')),
  window_start timestamptz not null,requests integer not null check(requests>0)
);
alter table mock_control.personas enable row level security;
alter table mock_control.clients enable row level security;
alter table mock_control.client_deliveries enable row level security;
alter table mock_control.fixtures enable row level security;
alter table mock_control.client_rate enable row level security;
alter table mock_control.global_rate enable row level security;
revoke all on all tables in schema mock_control from public,anon,authenticated;

-- Call only while holding the environment row lock. Limits survive isolate/IP/
-- capability changes; they do not pretend random installation IDs identify people.
create or replace function mock_control.take_rate(p_client uuid,p_kind text)
returns void language plpgsql set search_path='' as $$
declare used integer; global_limit integer; client_limit integer;
begin
  global_limit:=case p_kind when 'bootstrap' then 60 when 'catalog' then 600
    when 'issue' then 30 when 'retire' then 120 else 0 end;
  client_limit:=case p_kind when 'catalog' then 60 when 'issue' then 6
    when 'retire' then 12 else 0 end;
  insert into mock_control.global_rate values(p_kind,date_trunc('minute',now()),1)
    on conflict(kind) do update set window_start=excluded.window_start,
      requests=case when mock_control.global_rate.window_start=excluded.window_start
        then mock_control.global_rate.requests+1 else 1 end returning requests into used;
  if used>global_limit then raise exception using errcode='PT429',message='Global mock limit reached'; end if;
  if p_client is not null then
    insert into mock_control.client_rate values(p_client,p_kind,date_trunc('minute',now()),1)
      on conflict(client_id,kind) do update set window_start=excluded.window_start,
        requests=case when mock_control.client_rate.window_start=excluded.window_start
          then mock_control.client_rate.requests+1 else 1 end returning requests into used;
    if used>client_limit then raise exception using errcode='PT429',message='Client mock limit reached'; end if;
  end if;
end $$;
revoke all on function mock_control.take_rate(uuid,text) from public,anon,authenticated,service_role;

create or replace function public.mock_control_client(p_capability text)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  perform 1 from mock_control.environment where enabled for update;
  if not found or p_capability !~ '^[a-f0-9]{64}$' then raise insufficient_privilege; end if;
  perform mock_control.take_rate(null,'bootstrap');
  if (select count(*) from mock_control.clients)>=10000
    then raise exception using errcode='PT429',message='Mock client capacity reached'; end if;
  insert into mock_control.clients(capability_hash) values(p_capability) returning id into result;
  return result;
end $$;

create or replace function public.mock_control_catalog(p_capability text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare client uuid; people jsonb;
begin
  perform 1 from mock_control.environment where enabled for update;
  if not found then raise insufficient_privilege; end if;
  select id into client from mock_control.clients where capability_hash=p_capability;
  if not found then raise insufficient_privilege; end if;
  perform mock_control.take_rate(client,'catalog');
  select coalesce(jsonb_agg(jsonb_build_object(
    'key',p.persona_key,'user_id',p.user_id,'email',p.email,
    'name',p.display_name,'scenario',p.scenario) order by p.persona_key),'[]'::jsonb) into people
    from (select * from mock_control.personas where available order by persona_key limit 12) p
    join auth.users u on u.id=p.user_id and u.email=p.email and u.deleted_at is null
      and u.role='authenticated' and u.is_super_admin is not true
    where not exists(select 1 from private.moderation_staff_roles s where s.profile_id=p.user_id);
  return jsonb_build_object('client_id',client,'personas',people);
end $$;

create or replace function public.mock_control_claim(p_capability text,p_request uuid,p_persona text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare client uuid; d mock_control.client_deliveries; p mock_control.personas;
begin
  perform 1 from mock_control.environment where enabled for update;
  if not found then raise insufficient_privilege; end if;
  select id into client from mock_control.clients where capability_hash=p_capability for update;
  if not found then raise insufficient_privilege; end if;
  select * into p from mock_control.personas where persona_key=p_persona and available for update;
  if not found or not exists(select 1 from auth.users where id=p.user_id and email=p.email and deleted_at is null
      and role='authenticated' and is_super_admin is not true)
    or exists(select 1 from private.moderation_staff_roles where profile_id=p.user_id)
    then raise insufficient_privilege; end if;
  select * into d from mock_control.client_deliveries where client_id=client and request_id=p_request for update;
  if found then
    if d.persona_key<>p_persona then raise exception using errcode='PT409',message='Request payload changed'; end if;
    if d.state='issued' and d.expires_at>now() then
      return jsonb_build_object('state','replay','delivery',d.encrypted_delivery);
    end if;
    return jsonb_build_object('state',case when d.state='pending' and d.expires_at>now() then 'pending' else 'expired' end);
  end if;
  update mock_control.client_deliveries set state='retired',encrypted_delivery=null
    where persona_key=p_persona and state='pending' and expires_at<=now();
  if exists(select 1 from mock_control.client_deliveries where persona_key=p_persona and state='pending')
    then return jsonb_build_object('state','pending'); end if;
  perform mock_control.take_rate(client,'issue');
  if exists(select 1 from mock_control.client_deliveries where client_id=client and state='pending' and expires_at>now())
    or (select count(*) from mock_control.client_deliveries where state='pending' and expires_at>now())>=32
    or (select count(*) from mock_control.client_deliveries)>=20000
    then raise exception using errcode='PT429',message='Mock operation capacity reached'; end if;
  insert into mock_control.client_deliveries(client_id,request_id,persona_key,state) values(client,p_request,p_persona,'pending');
  return jsonb_build_object('state','new','user_id',p.user_id,'email',p.email);
end $$;

create or replace function public.mock_control_finish(p_capability text,p_request uuid,p_session uuid,p_delivery text)
returns void language plpgsql security definer set search_path='' as $$
declare client uuid; d mock_control.client_deliveries;
begin
  perform 1 from mock_control.environment where enabled for update;
  if not found then raise insufficient_privilege; end if;
  select id into client from mock_control.clients where capability_hash=p_capability for update;
  if not found then raise insufficient_privilege; end if;
  select * into d from mock_control.client_deliveries where client_id=client and request_id=p_request for update;
  if not found or d.state<>'pending' or d.expires_at<=now() or length(p_delivery)>16384
    or not exists(select 1 from auth.sessions s join mock_control.personas p on p.user_id=s.user_id
      where s.id=p_session and p.persona_key=d.persona_key and p.available)
    then raise insufficient_privilege; end if;
  update mock_control.client_deliveries set state='issued',session_id=p_session,encrypted_delivery=p_delivery
    where client_id=client and request_id=p_request;
end $$;

create or replace function public.mock_control_retire(p_capability text,p_request uuid,p_persona text)
returns void language plpgsql security definer set search_path='' as $$
declare client uuid;
begin
  -- Retiring owned sessions remains possible after issuance is disabled.
  perform 1 from mock_control.environment where singleton for update;
  select id into client from mock_control.clients where capability_hash=p_capability for update;
  if not found then raise insufficient_privilege; end if;
  if exists(select 1 from mock_control.client_deliveries where client_id=client
    and request_id=p_request and persona_key<>p_persona) then
    raise exception using errcode='PT409',message='Request payload changed'; end if;
  if not exists(select 1 from mock_control.client_deliveries where client_id=client and request_id=p_request) then
    if not exists(select 1 from mock_control.personas where persona_key=p_persona)
      then raise insufficient_privilege; end if;
    perform mock_control.take_rate(client,'retire');
    if (select count(*) from mock_control.client_deliveries)>=20000
      then raise exception using errcode='PT429',message='Mock operation capacity reached'; end if;
    insert into mock_control.client_deliveries(client_id,request_id,persona_key,state)
      values(client,p_request,p_persona,'retired');
  end if;
  delete from auth.sessions where id in(select session_id from mock_control.client_deliveries
    where client_id=client and request_id=p_request);
  update mock_control.client_deliveries set state='retired',encrypted_delivery=null
    where client_id=client and request_id=p_request;
end $$;

-- Explicit mock-only shutdown: preserve world/content, retire every registered
-- persona refresh session. Existing bearer tokens expire within <= one hour.
create or replace function public.mock_control_shutdown()
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from mock_control.environment where singleton for update;
  update mock_control.environment set enabled=false where singleton;
  delete from auth.sessions where user_id in(select user_id from mock_control.personas);
  update mock_control.client_deliveries set encrypted_delivery=null,state='retired';
end $$;
revoke all on function public.mock_control_client(text),public.mock_control_catalog(text),
  public.mock_control_claim(text,uuid,text),public.mock_control_finish(text,uuid,uuid,text),
  public.mock_control_retire(text,uuid,text),public.mock_control_shutdown() from public,anon,authenticated;
grant execute on function public.mock_control_client(text),public.mock_control_catalog(text),
  public.mock_control_claim(text,uuid,text),public.mock_control_finish(text,uuid,uuid,text),
  public.mock_control_retire(text,uuid,text),public.mock_control_shutdown() to service_role;

create or replace function public.mock_control_retire_candidate(p_session uuid,p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  delete from auth.sessions where id=p_session and user_id=p_user
    and exists(select 1 from mock_control.personas where user_id=p_user);
end $$;
revoke all on function public.mock_control_retire_candidate(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mock_control_retire_candidate(uuid,uuid) to service_role;

-- MAPMOCK01: authenticated mock-only identity proof, with no caller arguments.
-- getUser alone does not reject every revoked JWT; require its live recorded
-- Auth session and current broker delivery. No normal profile or data is read.
create or replace function public.mock_basemap_identity_v1()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; session_text text := auth.jwt()->>'session_id';
begin
  if auth.uid() is null or session_text is null or session_text !~
    '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' then
    raise exception using errcode='42501',message='Mock map session unavailable';
  end if;
  select jsonb_build_object(
    'actor_scope',encode(extensions.digest('mapmock01:actor:'||s.user_id::text,'sha256'),'hex'),
    'client_scope',encode(extensions.digest('mapmock01:client:'||d.client_id::text,'sha256'),'hex'))
    into result
    from auth.sessions s
    join mock_control.client_deliveries d on d.session_id=s.id and d.state='issued'
    join mock_control.personas p on p.persona_key=d.persona_key and p.user_id=s.user_id and p.available
    cross join mock_control.environment e
    where s.id=session_text::uuid and s.user_id=auth.uid()
      and (s.not_after is null or s.not_after>statement_timestamp())
      and e.singleton and e.enabled and e.operator_confirmed
      and e.project_ref='pnolarmzxmmjtguligfc' and e.generation='mock-world-2026-10-21-v1'
    limit 1;
  if result is null then
    raise exception using errcode='42501',message='Mock map session unavailable';
  end if;
  return result;
end;
$$;
revoke all on function public.mock_basemap_identity_v1() from public,anon,authenticated,service_role;
grant execute on function public.mock_basemap_identity_v1() to authenticated;

-- Mock-only Auth protection. Ordinary profile/content edits remain canonical.
-- No weakening of normal OTP or product policies; this trigger is never shipped
-- as a product migration. Auth provider/MFA mutation is unsupported for fixtures.
create or replace function mock_control.protect_persona_credentials()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from mock_control.personas where user_id=old.id) and (
    new.email is distinct from old.email or new.phone is distinct from old.phone
    or new.encrypted_password is distinct from old.encrypted_password
    or new.email_change is distinct from old.email_change
    or new.phone_change is distinct from old.phone_change
    or new.raw_app_meta_data is distinct from old.raw_app_meta_data
    or new.deleted_at is distinct from old.deleted_at
  ) then raise insufficient_privilege; end if;
  return new;
end $$;
drop trigger if exists mock_fixture_credentials on auth.users;
create trigger mock_fixture_credentials before update on auth.users
  for each row execute function mock_control.protect_persona_credentials();

create or replace function mock_control.protect_persona_identity()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from mock_control.personas where user_id=coalesce(new.user_id,old.user_id)) then
    if tg_table_name='identities' and tg_op='UPDATE' and
      (to_jsonb(new)-'last_sign_in_at'-'updated_at')=(to_jsonb(old)-'last_sign_in_at'-'updated_at')
      then return new; end if;
    raise insufficient_privilege;
  end if;
  return coalesce(new,old);
end $$;
drop trigger if exists mock_fixture_identity on auth.identities;
create trigger mock_fixture_identity before insert or update or delete on auth.identities
  for each row execute function mock_control.protect_persona_identity();
drop trigger if exists mock_fixture_mfa on auth.mfa_factors;
create trigger mock_fixture_mfa before insert or update or delete on auth.mfa_factors
  for each row execute function mock_control.protect_persona_identity();
revoke all on function mock_control.protect_persona_credentials(),mock_control.protect_persona_identity()
  from public,anon,authenticated,service_role;
