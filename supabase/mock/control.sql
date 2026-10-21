-- Separate, explicitly invoked mock control installation; never normal migrations.
do $$ begin
  if not exists(select 1 from mock_control.environment where singleton
    and project_ref='pnolarmzxmmjtguligfc' and operator_confirmed) then
    raise exception 'Missing independently confirmed mock marker';
  end if;
end $$;

create table if not exists mock_control.personas (
  persona_key text primary key check(persona_key ~ '^[a-z]{2,20}$'),
  user_id uuid not null unique references auth.users(id),
  email text not null unique check(email ~ '^[a-z]+@personas\.planets\.invalid$'),
  display_name text not null check(length(display_name) between 2 and 60),
  scenario text not null check(length(scenario) between 1 and 240),
  available boolean not null default true
);
create table if not exists mock_control.testers (
  issuer text not null check(issuer='https://cllpvruvrrvxczjitlqd.supabase.co/auth/v1'),
  user_id uuid not null,
  enrolled boolean not null default true,
  primary key(issuer,user_id)
);
create table if not exists mock_control.deliveries (
  issuer text not null,
  tester_id uuid not null,
  request_id uuid not null,
  persona_key text not null references mock_control.personas(persona_key),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '2 minutes',
  state text not null check(state in ('pending','issued','retired')),
  session_id uuid,
  encrypted_delivery text,
  primary key(issuer,tester_id,request_id),
  foreign key(issuer,tester_id) references mock_control.testers(issuer,user_id)
);
create index if not exists mock_delivery_tester_time
  on mock_control.deliveries(issuer,tester_id,created_at desc);
create table if not exists mock_control.fixtures (
  fixture_key text primary key,
  object_id uuid not null,
  initial_digest text not null,
  receipt jsonb not null
);
create table if not exists mock_control.catalog_rate (
  issuer text not null,tester_id uuid not null,window_start timestamptz not null,
  requests integer not null check(requests>0),primary key(issuer,tester_id,window_start)
);
alter table mock_control.personas enable row level security;
alter table mock_control.testers enable row level security;
alter table mock_control.deliveries enable row level security;
alter table mock_control.fixtures enable row level security;
alter table mock_control.catalog_rate enable row level security;
revoke all on all tables in schema mock_control from public,anon,authenticated;

create or replace function public.mock_control_catalog(p_issuer text,p_tester uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare used integer;
begin
  if not exists(select 1 from mock_control.environment where enabled)
    or not exists(select 1 from mock_control.testers where issuer=p_issuer and user_id=p_tester and enrolled)
    then raise insufficient_privilege; end if;
  insert into mock_control.catalog_rate(issuer,tester_id,window_start,requests)
    values(p_issuer,p_tester,date_trunc('minute',now()),1)
    on conflict(issuer,tester_id,window_start) do update set requests=mock_control.catalog_rate.requests+1 returning requests into used;
  if used>60 then raise exception using errcode='PT429',message='Catalog limit reached'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'key',p.persona_key,'user_id',p.user_id,'email',p.email,
    'name',p.display_name,'scenario',p.scenario) order by p.persona_key),'[]'::jsonb)
    from (select * from mock_control.personas where available order by persona_key limit 12) p
    join auth.users u on u.id=p.user_id and u.email=p.email and u.deleted_at is null
    where not exists(select 1 from private.moderation_staff_roles s where s.profile_id=p.user_id));
end $$;

create or replace function public.mock_control_claim(p_issuer text,p_tester uuid,p_request uuid,p_persona text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d mock_control.deliveries; p mock_control.personas;
begin
  perform 1 from mock_control.environment where enabled for update;
  if not found then raise insufficient_privilege; end if;
  perform 1 from mock_control.testers where issuer=p_issuer and user_id=p_tester and enrolled for update;
  if not found or not exists(select 1 from mock_control.environment where enabled) then raise insufficient_privilege; end if;
  select * into p from mock_control.personas where persona_key=p_persona and available for update;
  if not found or not exists(select 1 from auth.users where id=p.user_id and email=p.email and deleted_at is null)
    or exists(select 1 from private.moderation_staff_roles where profile_id=p.user_id)
    then raise insufficient_privilege; end if;
  select * into d from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester and request_id=p_request for update;
  if found then
    if d.persona_key<>p_persona then raise exception using errcode='PT409',message='Request payload changed'; end if;
    if d.state='issued' and d.expires_at>now() then
      return jsonb_build_object('state','replay','delivery',d.encrypted_delivery);
    end if;
    return jsonb_build_object('state',case when d.expires_at>now() then 'pending' else 'expired' end);
  end if;
  -- One OTP exchange at a time per shared account: GoTrue's one-time login
  -- tokens are account-scoped. Other testers retry their ORIGINAL operation.
  update mock_control.deliveries set state='retired',encrypted_delivery=null
    where persona_key=p_persona and state='pending' and expires_at<=now();
  if exists(select 1 from mock_control.deliveries where persona_key=p_persona and state='pending')
    then return jsonb_build_object('state','pending'); end if;
  if (select count(*) from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester and created_at>now()-interval '1 minute')>=6
    or exists(select 1 from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester and state='pending' and expires_at>now())
    or (select count(*) from mock_control.deliveries where state='pending' and expires_at>now())>=32
    then raise exception using errcode='PT429',message='Switch limit reached'; end if;
  insert into mock_control.deliveries(issuer,tester_id,request_id,persona_key,state) values(p_issuer,p_tester,p_request,p_persona,'pending');
  return jsonb_build_object('state','new','user_id',p.user_id,'email',p.email);
end $$;

create or replace function public.mock_control_finish(p_issuer text,p_tester uuid,p_request uuid,p_session uuid,p_delivery text)
returns void language plpgsql security definer set search_path='' as $$
declare d mock_control.deliveries;
begin
  perform 1 from mock_control.testers where issuer=p_issuer and user_id=p_tester and enrolled for update;
  if not found or not exists(select 1 from mock_control.environment where enabled) then raise insufficient_privilege; end if;
  select * into d from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester and request_id=p_request for update;
  if not found or d.state<>'pending' or d.expires_at<=now() or length(p_delivery)>16384
    or not exists(select 1 from auth.sessions s join mock_control.personas p on p.user_id=s.user_id
      where s.id=p_session and p.persona_key=d.persona_key and p.available)
    then raise insufficient_privilege; end if;
  update mock_control.deliveries set state='issued',session_id=p_session,encrypted_delivery=p_delivery
    where issuer=p_issuer and tester_id=p_tester and request_id=p_request;
end $$;

create or replace function public.mock_control_retire(p_issuer text,p_tester uuid,p_request uuid,p_persona text)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from mock_control.testers where issuer=p_issuer and user_id=p_tester for update;
  if not found then raise insufficient_privilege; end if;
  if exists(select 1 from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester
    and request_id=p_request and persona_key<>p_persona) then
    raise exception using errcode='PT409',message='Request payload changed'; end if;
  delete from auth.sessions where id in(select session_id from mock_control.deliveries
    where issuer=p_issuer and tester_id=p_tester and request_id=p_request);
  update mock_control.deliveries set state='retired',encrypted_delivery=null
    where issuer=p_issuer and tester_id=p_tester and request_id=p_request;
end $$;

-- Revokes only this tester's issued refresh sessions. Already issued bearer tokens
-- remain valid until JWT expiry (configure <= 1 hour); this is not instant logout.
create or replace function public.mock_control_offboard(p_issuer text,p_tester uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from mock_control.testers where issuer=p_issuer and user_id=p_tester for update;
  update mock_control.testers set enrolled=false where issuer=p_issuer and user_id=p_tester;
  delete from auth.sessions where id in(select session_id from mock_control.deliveries where issuer=p_issuer and tester_id=p_tester);
  update mock_control.deliveries set encrypted_delivery=null,state='retired' where issuer=p_issuer and tester_id=p_tester;
end $$;

revoke all on function public.mock_control_catalog(text,uuid),
  public.mock_control_claim(text,uuid,uuid,text),public.mock_control_finish(text,uuid,uuid,uuid,text),
  public.mock_control_retire(text,uuid,uuid,text),public.mock_control_offboard(text,uuid) from public,anon,authenticated;
grant execute on function public.mock_control_catalog(text,uuid),
  public.mock_control_claim(text,uuid,uuid,text),public.mock_control_finish(text,uuid,uuid,uuid,text),
  public.mock_control_retire(text,uuid,uuid,text),public.mock_control_offboard(text,uuid) to service_role;

create or replace function public.mock_control_retire_candidate(p_session uuid,p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  delete from auth.sessions where id=p_session and user_id=p_user
    and exists(select 1 from mock_control.personas where user_id=p_user);
end $$;
revoke all on function public.mock_control_retire_candidate(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mock_control_retire_candidate(uuid,uuid) to service_role;

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
