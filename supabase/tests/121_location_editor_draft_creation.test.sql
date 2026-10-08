begin;
select no_plan();
select has_table('private','recurring_draft_creations','narrow immutable editor receipts exist');
select ok((select relrowsecurity from pg_class where oid='private.recurring_draft_creations'::regclass),'receipts enable RLS');
select is((select count(*) from pg_policy where polrelid='private.recurring_draft_creations'::regclass),0::bigint,'no raw client policies');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) as actor(role_name)
  where has_table_privilege(role_name,'private.recurring_draft_creations','SELECT,INSERT,UPDATE,DELETE')),'no API role raw receipt access');
select ok(not exists(select 1 from pg_constraint where conrelid='private.recurring_draft_creations'::regclass
  and contype='f' and confdeltype<>'r'),'restrictive references do not delete canonical drafts');
select ok(exists(select 1 from pg_trigger where tgrelid='private.recurring_draft_creations'::regclass
  and tgfoid='private.protect_moderation_append_only()'::regprocedure),'receipts append-only');
select ok((select bool_and(prosecdef and coalesce(proconfig,array[]::text[]) @> array['search_path=""']) from pg_proc
  where pronamespace='public'::regnamespace and proname in ('create_editor_recurring_activity_draft','recover_editor_recurring_activity_draft')),'RPCs hardened');
select ok((select bool_and(has_function_privilege('authenticated',oid,'EXECUTE')
  and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE')) from pg_proc
  where pronamespace='public'::regnamespace and proname in ('create_editor_recurring_activity_draft','recover_editor_recurring_activity_draft')),'authenticated-only RPCs');
select throws_ok($$select public.recover_editor_recurring_activity_draft('e4000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002')$$,
  '42501',null,'recovery denies absent identity');

select has_table('private','resource_draft_creations','narrow immutable editor receipts exist');
select ok((select relrowsecurity from pg_class where oid='private.resource_draft_creations'::regclass),'receipts enable RLS');
select is((select count(*) from pg_policy where polrelid='private.resource_draft_creations'::regclass),0::bigint,'no raw client policies');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) as actor(role_name)
  where has_table_privilege(role_name,'private.resource_draft_creations','SELECT,INSERT,UPDATE,DELETE')),'no API role raw receipt access');
select ok(not exists(select 1 from pg_constraint where conrelid='private.resource_draft_creations'::regclass
  and contype='f' and confdeltype<>'r'),'restrictive references do not delete canonical drafts');
select ok(exists(select 1 from pg_trigger where tgrelid='private.resource_draft_creations'::regclass
  and tgfoid='private.protect_moderation_append_only()'::regprocedure),'receipts append-only');
select ok((select bool_and(prosecdef and coalesce(proconfig,array[]::text[]) @> array['search_path=""']) from pg_proc
  where pronamespace='public'::regnamespace and proname in ('create_editor_resource_listing_draft','recover_editor_resource_listing_draft')),'RPCs hardened');
select ok((select bool_and(has_function_privilege('authenticated',oid,'EXECUTE')
  and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE')) from pg_proc
  where pronamespace='public'::regnamespace and proname in ('create_editor_resource_listing_draft','recover_editor_resource_listing_draft')),'authenticated-only RPCs');
select throws_ok($$select public.recover_editor_resource_listing_draft('e4000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002')$$,
  '42501',null,'recovery denies absent identity');
select * from finish();
rollback;
