begin;
select no_plan();
select has_table('private','proposal_template_applications','immutable private receipts exist');
select ok((select relrowsecurity from pg_class where oid='private.proposal_template_applications'::regclass),'receipts enable RLS');
select is((select count(*) from pg_policy where polrelid='private.proposal_template_applications'::regclass),0::bigint,'no raw client policies');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) as actor(role_name)
  where has_table_privilege(role_name,'private.proposal_template_applications','SELECT,INSERT,UPDATE,DELETE')),'all API roles denied raw provenance');
select ok(not exists(select 1 from pg_constraint where conrelid='private.proposal_template_applications'::regclass
  and contype='f' and confdeltype<>'r'),'restrictive retention without cascading derivative deletion');
select ok(exists(select 1 from pg_trigger where tgrelid='private.proposal_template_applications'::regclass
  and tgfoid='private.protect_moderation_append_only()'::regprocedure),'receipts append-only');
select ok((select bool_and(prosecdef and coalesce(proconfig,array[]::text[]) @> array['search_path=""']) from pg_proc where oid in (
  'public.create_proposal_draft_from_template(uuid,uuid,text,uuid,boolean)'::regprocedure,
  'public.get_own_proposal_template_application(uuid,uuid)'::regprocedure)),'RPCs hardened');
select ok((select bool_and(has_function_privilege('authenticated',oid,'EXECUTE')
  and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE')) from pg_proc where oid in (
  'public.create_proposal_draft_from_template(uuid,uuid,text,uuid,boolean)'::regprocedure,
  'public.get_own_proposal_template_application(uuid,uuid)'::regprocedure)),'authenticated-only RPC grants');
select is((select provolatile::text from pg_proc where oid='public.get_own_proposal_template_application(uuid,uuid)'::regprocedure),'s','read uses one snapshot');
select throws_ok($$select public.create_proposal_draft_from_template('e3000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000002','tw01:'||repeat('0',64),'e3000000-0000-4000-8000-000000000003')$$,
  '42501',null,'copy denies absent identity');
select throws_ok($$select public.get_own_proposal_template_application('e3000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000003')$$,
  '42501',null,'receipt read denies absent identity');
select * from finish();
rollback;
