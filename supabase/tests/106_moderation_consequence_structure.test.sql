begin;
select no_plan();
select has_table('private', 'moderation_consequences');
select has_table('private', 'moderation_consequence_actions');
select ok(relrowsecurity, relname || ' has RLS') from pg_class
  where oid in ('private.moderation_consequences'::regclass, 'private.moderation_consequence_actions'::regclass);
select ok(not has_table_privilege(role_name, table_name, 'SELECT,INSERT,UPDATE,DELETE'), role_name || ' has no ' || table_name || ' convenience access')
  from unnest(array['anon','authenticated','service_role']) as roles(role_name)
  cross join unnest(array['private.moderation_consequences','private.moderation_consequence_actions']) as tables(table_name);
select is(count(*)::integer, 0, 'Consequence tables have no client RLS policies') from pg_policy
  where polrelid in ('private.moderation_consequences'::regclass, 'private.moderation_consequence_actions'::regclass);
select ok(confdeltype = 'r', conname || ' restricts deletion') from pg_constraint
  where contype = 'f' and conrelid in ('private.moderation_consequences'::regclass, 'private.moderation_consequence_actions'::regclass);
select ok(prosecdef and proconfig @> array['search_path=""'], proname || ' is hardened') from pg_proc
  where pronamespace = 'public'::regnamespace and proname in (
    'apply_moderation_consequence','revoke_moderation_consequence','list_own_moderation_consequences','list_moderation_case_consequence_history');
select ok(not has_function_privilege('anon', oid, 'EXECUTE'), proname || ' denies anon') from pg_proc
  where pronamespace = 'public'::regnamespace and proname in (
    'apply_moderation_consequence','revoke_moderation_consequence','list_own_moderation_consequences','list_moderation_case_consequence_history');
select ok(not has_function_privilege('service_role', oid, 'EXECUTE'), proname || ' denies service convenience APIs') from pg_proc
  where pronamespace = 'public'::regnamespace and proname in (
    'apply_moderation_consequence','revoke_moderation_consequence','list_own_moderation_consequences','list_moderation_case_consequence_history');
select ok(not has_function_privilege('authenticated', oid, 'EXECUTE'), proname || ' is private') from pg_proc
  where pronamespace = 'private'::regnamespace and proname in (
    'profile_has_active_safety_notice','profile_has_active_interaction_restriction',
    'project_has_active_content_hide','resource_listing_has_active_content_hide',
    'lock_profile_new_interactions','assert_profile_new_interactions_available',
    'require_consequence_staff','withdraw_pending_outbound_requests_for_restriction','record_moderation_consequence_event');
select has_index('private', 'moderation_consequences', 'moderation_consequences_active_profile_idx');
select has_index('private', 'moderation_consequences', 'moderation_consequences_active_project_idx');
select has_index('private', 'moderation_consequences', 'moderation_consequences_active_resource_idx');
select has_trigger('private', 'moderation_consequences', 'moderation_consequences_preserve_history');
select has_trigger('private', 'moderation_consequence_actions', 'moderation_consequence_actions_append_only');
select ok(position('lock_profile_new_interactions' in pg_get_functiondef('private.lock_project_manager_interactions(uuid,uuid)'::regprocedure))
  < position('lock_user_interaction_pair' in pg_get_functiondef('private.lock_project_manager_interactions(uuid,uuid)'::regprocedure)), 'Project profile barrier precedes pair locks');
select ok(position('lock_profile_new_interactions' in pg_get_functiondef('public.request_resource_listing(uuid,uuid,text)'::regprocedure))
  < position('lock_user_interaction_pair' in pg_get_functiondef('public.request_resource_listing(uuid,uuid,text)'::regprocedure)), 'Resource profile barrier precedes pair locks');
select * from finish();
rollback;
