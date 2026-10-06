begin;
select no_plan();

select has_table('private', 'proposal_templates', 'linked identities are private');
select has_table('private', 'proposal_template_baselines', 'draft baselines are private');
select is((select count(*) from pg_policy where polrelid in (
  'private.proposal_templates'::regclass, 'private.proposal_template_baselines'::regclass
)), 0::bigint, 'there are no raw-client template policies');
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'private.proposal_templates'::regclass, 'private.proposal_template_baselines'::regclass
)), 'template internals enable RLS');
select ok(not exists (
  select 1 from unnest(array['anon','authenticated','service_role']) as actor(role_name)
  cross join unnest(array['private.proposal_templates','private.proposal_template_baselines']) as object(table_name)
  where has_table_privilege(actor.role_name, object.table_name, 'SELECT,INSERT,UPDATE,DELETE')
), 'no API role has direct internal table privileges');
select ok(not exists (
  select 1 from pg_proc as routine join pg_namespace as namespace on namespace.oid = routine.pronamespace
  where namespace.nspname = 'private' and (
    routine.proname like '%proposal_template%' or routine.proname = 'link_published_proposal_template'
  ) and (has_function_privilege('anon', routine.oid, 'EXECUTE')
    or has_function_privilege('authenticated', routine.oid, 'EXECUTE')
    or has_function_privilege('service_role', routine.oid, 'EXECUTE'))
), 'private template helpers and triggers are owner-only');
select ok((select bool_and(prosecdef and provolatile = 's'
  and coalesce(proconfig, array[]::text[]) @> array['search_path=""'])
  from pg_proc where oid in (
    'public.list_public_proposal_templates(integer,timestamptz,uuid,uuid[],text)'::regprocedure,
    'public.get_public_proposal_template(uuid)'::regprocedure,
    'public.list_public_proposal_template_resource_blueprints(uuid,text,integer,uuid)'::regprocedure,
    'public.get_own_proposal_template_baseline(uuid,uuid)'::regprocedure
  )), 'all four RPCs are hardened and share a stable statement snapshot');
select ok((select bool_and(has_function_privilege('anon', oid, 'EXECUTE')
  and has_function_privilege('authenticated', oid, 'EXECUTE')
  and not has_function_privilege('service_role', oid, 'EXECUTE'))
  from pg_proc where oid in (
    'public.list_public_proposal_templates(integer,timestamptz,uuid,uuid[],text)'::regprocedure,
    'public.get_public_proposal_template(uuid)'::regprocedure,
    'public.list_public_proposal_template_resource_blueprints(uuid,text,integer,uuid)'::regprocedure
  )), 'public reads have deliberate anonymous/authenticated grants');
select ok(has_function_privilege('authenticated', 'public.get_own_proposal_template_baseline(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.get_own_proposal_template_baseline(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('service_role', 'public.get_own_proposal_template_baseline(uuid,uuid)', 'EXECUTE'),
  'baseline has no anonymous or general staff/service path');
select ok(to_regclass('private.proposal_templates_catalog_idx') is not null,
  'eligible catalog has an immutable paired keyset index');
select is((select count(*) from pg_constraint where conrelid = 'private.proposal_templates'::regclass
  and contype = 'u'), 1::bigint, 'source identity is unique');
select ok(not exists (select 1 from pg_constraint where conrelid in (
  'private.proposal_templates'::regclass, 'private.proposal_template_baselines'::regclass
) and contype = 'f' and confdeltype <> 'r'), 'existing restrictive retention is preserved');
select columns_are('private','proposal_template_baselines',
  array['template_id','title','summary','description','skill_selections','captured_at'],
  'baseline has only narrow comparison content');
select * from finish();
rollback;
