-- Apply only after independently verifying the dedicated project's identity.
-- The operator substitutes the reviewed migration inventory SHA256; no secrets.
create schema if not exists mock_control;
revoke all on schema mock_control from public, anon, authenticated;
create table if not exists mock_control.environment (
  singleton boolean primary key default true check (singleton),
  project_ref text not null check (project_ref = 'pnolarmzxmmjtguligfc'),
  generation text not null check (generation = 'mock-world-2026-10-21-v1'),
  schema_fingerprint text not null check (schema_fingerprint ~ '^[a-f0-9]{64}$'),
  operator_confirmed boolean not null check (operator_confirmed),
  enabled boolean not null default false,
  anchored_at timestamptz not null default now()
);
alter table mock_control.environment enable row level security;
revoke all on mock_control.environment from public, anon, authenticated;
-- Insertion is deliberately an independent operator action, not bootstrap.
