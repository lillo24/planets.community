begin;
select no_plan();

select has_function('public','list_group_project_conversations',array['uuid','uuid','integer','timestamp with time zone','uuid'],'Group Project conversations have an independent bounded endpoint');
select has_function('public','list_own_group_project_chat_folders',array['uuid','uuid[]'],'Loaded chat mapping is bounded and independently authorized');
select has_function('public','list_group_discussion_links_v2',array['uuid','uuid','uuid','integer','timestamp with time zone','uuid'],'Current room scope has a versioned collection reader');
select ok(not has_function_privilege('anon',oid,'execute')
  and not has_function_privilege('service_role',oid,'execute')
  and has_function_privilege('authenticated',oid,'execute'),proname||' is authenticated only')
from pg_proc where pronamespace='public'::regnamespace and proname in (
  'list_group_project_conversations','list_own_group_project_chat_folders',
  'get_group_discussion_link_v2','list_group_discussion_links_v2',
  'add_group_discussion_link_v2','update_group_discussion_link_v2','remove_group_discussion_link_v2');
select ok(proconfig @> array['search_path=""'],proname||' fixes its privileged search path')
from pg_proc where pronamespace='public'::regnamespace and proname in (
  'list_group_project_conversations','list_own_group_project_chat_folders',
  'get_group_discussion_link_v2','list_group_discussion_links_v2',
  'add_group_discussion_link_v2','update_group_discussion_link_v2','remove_group_discussion_link_v2');
set local role anon;
select throws_ok($$select public.list_group_project_conversations(gen_random_uuid(),gen_random_uuid())$$,'42501',null,'Anonymous guessed Group ID cannot list Project conversations');
select throws_ok($$select public.list_own_group_project_chat_folders(gen_random_uuid(),array[gen_random_uuid()])$$,'42501',null,'Anonymous guessed chat ID cannot map a Group');
select throws_ok($$select public.list_group_discussion_links_v2(gen_random_uuid(),gen_random_uuid())$$,'42501',null,'Anonymous current workspace remains unavailable');
reset role;
select * from finish();
rollback;
