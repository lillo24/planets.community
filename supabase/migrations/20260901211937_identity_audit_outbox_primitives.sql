create table public.profiles (
  id uuid primary key
    constraint profiles_id_fkey references auth.users (id) on delete restrict,
  created_at timestamptz not null default now()
);

comment on table public.profiles is
  'One-to-one PLANETS application identity anchor for a Supabase Auth user.';

alter table public.profiles enable row level security;

create policy "Authenticated users can read their own profile anchor"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Authenticated users can create their own profile anchor"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

-- The client supplies only its Auth UUID. PostgreSQL owns the canonical creation timestamp.
grant select on table public.profiles to authenticated;
grant insert (id) on table public.profiles to authenticated;

create table private.audit_events (
  id uuid primary key default gen_random_uuid(),
  action text not null
    constraint audit_events_action_nonempty check (length(btrim(action)) > 0),
  actor_user_id uuid
    constraint audit_events_actor_user_id_fkey references auth.users (id) on delete restrict,
  target_type text
    constraint audit_events_target_type_nonempty
      check (target_type is null or length(btrim(target_type)) > 0),
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb
    constraint audit_events_metadata_object check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

comment on table private.audit_events is
  'Append-oriented operational and security history for trusted database/server operations.';

create index audit_events_created_at_idx
  on private.audit_events (created_at desc, id);

create index audit_events_actor_user_id_created_at_idx
  on private.audit_events (actor_user_id, created_at desc, id)
  where actor_user_id is not null;

create table private.outbox_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null
    constraint outbox_events_event_type_nonempty check (length(btrim(event_type)) > 0),
  payload jsonb not null default '{}'::jsonb
    constraint outbox_events_payload_object check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  available_at timestamptz not null default now()
    constraint outbox_events_available_at_not_before_created_at
      check (available_at >= created_at),
  published_at timestamptz
    constraint outbox_events_published_at_not_before_created_at
      check (published_at is null or published_at >= created_at)
);

comment on table private.outbox_events is
  'Transaction-local handoff records for a later dispatcher; this table is not a delivery queue.';

create index outbox_events_pending_available_at_idx
  on private.outbox_events (available_at, created_at, id)
  where published_at is null;

-- These revokes make the reviewed private-table boundary explicit even though 01A defaults
-- already deny privileges to the API roles.
revoke all privileges on table private.audit_events
  from public, anon, authenticated, service_role;
revoke all privileges on table private.outbox_events
  from public, anon, authenticated, service_role;
