begin;
select no_plan();
select has_table('private','proposal_template_removal_actions','protected removal records exist');
select ok((select relrowsecurity from pg_class where oid='private.proposal_template_removal_actions'::regclass),'removal records enable RLS');
select is((select count(*) from pg_policy where polrelid='private.proposal_template_removal_actions'::regclass),0::bigint,'no raw-client removal policies');
select ok(not exists (select 1 from unnest(array['anon','authenticated','service_role']) as actor(role_name)
  where has_table_privilege(role_name,'private.proposal_template_removal_actions','SELECT,INSERT,UPDATE,DELETE')),'no API role has raw reason/receipt access');
select ok(not exists (select 1 from pg_constraint where conrelid='private.proposal_template_removal_actions'::regclass
  and contype='f' and confdeltype<>'r'),'removal retention uses restrictive foreign keys');
select col_is_fk('private','moderation_cases','target_proposal_template_id','template target is a typed foreign key');
select col_is_fk('private','moderation_cases','template_source_proposal_id','source provenance has its own typed foreign key');
select ok(to_regclass('private.proposal_template_one_effective_removal_idx') is not null,'one effective removal enforced by a partial unique index');
select ok((select bool_and(prosecdef and coalesce(proconfig,array[]::text[]) @> array['search_path=""']) from pg_proc where oid in (
  'public.get_moderation_case_template(uuid,uuid)'::regprocedure,
  'public.list_moderation_case_template_blueprints(uuid,uuid,text,integer,uuid)'::regprocedure,
  'public.remove_moderation_case_template(uuid,uuid,uuid,uuid,text,text)'::regprocedure)),'all staff template RPCs are hardened');
select ok((select bool_and(has_function_privilege('authenticated',oid,'EXECUTE')
  and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE')) from pg_proc where oid in (
  'public.get_moderation_case_template(uuid,uuid)'::regprocedure,
  'public.list_moderation_case_template_blueprints(uuid,uuid,text,integer,uuid)'::regprocedure,
  'public.remove_moderation_case_template(uuid,uuid,uuid,uuid,text,text)'::regprocedure)),'staff RPC grants do not create anonymous/service-role access');
select ok((select bool_and(provolatile='s') from pg_proc where oid in (
  'public.get_moderation_case_template(uuid,uuid)'::regprocedure,
  'public.list_moderation_case_template_blueprints(uuid,uuid,text,integer,uuid)'::regprocedure)),'staff read projection uses one statement snapshot');
select ok(exists(select 1 from pg_trigger where tgrelid='private.proposal_template_removal_actions'::regclass
  and tgfoid='private.protect_moderation_append_only()'::regprocedure),'reasons and attribution are append-only');
select throws_ok($$select public.get_moderation_case_template('e2000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000002')$$,
  '42501',null,'staff projection explicitly denies absent identity');
select throws_ok($$select public.remove_moderation_case_template('e2000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000002','e2000000-0000-4000-8000-000000000003','e2000000-0000-4000-8000-000000000004','tw01:'||repeat('0',64),'Explicit bounded reason')$$,
  '42501',null,'enforcement explicitly denies absent identity');
select * from finish();
rollback;
