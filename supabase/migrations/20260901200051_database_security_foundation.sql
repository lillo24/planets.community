-- Supabase migrations run as `postgres`. ALTER DEFAULT PRIVILEGES is creator-specific, so these
-- rules protect objects created by that same role in future PLANETS migrations.

create schema private authorization postgres;

comment on schema private is
  'Non-API PLANETS data and implementation details. Client roles have no schema access.';

revoke all privileges on schema private from public, anon, authenticated, service_role;

-- Client roles may use `public` only after a migration grants access to a specific object. They
-- never need to create objects in the API schema themselves.
revoke create on schema public from public, anon, authenticated, service_role;

-- Supabase can install Data API default grants for objects owned by `postgres`. Revoke every
-- table and sequence privilege, not only the common CRUD subset, so new object types remain
-- fail-closed as PostgreSQL evolves.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from public, anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke all privileges on sequences from public, anon, authenticated, service_role;

-- PostgreSQL itself grants EXECUTE on new routines to PUBLIC. Revoking PUBLIC is essential:
-- revoking only anon/authenticated/service_role would still leave them access through PUBLIC.
alter default privileges for role postgres in schema public
  revoke all privileges on functions from public, anon, authenticated, service_role;

-- `private` is already unreachable without schema USAGE. Matching object defaults adds defense in
-- depth if a future migration grants narrowly scoped schema access to another trusted role.
alter default privileges for role postgres in schema private
  revoke all privileges on tables from public, anon, authenticated, service_role;

alter default privileges for role postgres in schema private
  revoke all privileges on sequences from public, anon, authenticated, service_role;

alter default privileges for role postgres in schema private
  revoke all privileges on functions from public, anon, authenticated, service_role;

-- Spatial support belongs in the existing non-API extension schema. Product location tables and
-- visibility rules are intentionally deferred to later plans.
create extension postgis with schema extensions;
