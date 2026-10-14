begin;
select no_plan();
select ok(has_function_privilege('authenticated',oid,'execute') and not has_function_privilege('anon',oid,'execute') and not has_function_privilege('service_role',oid,'execute'),proname||' is authenticated only')
from pg_proc where pronamespace='public'::regnamespace and proname in ('get_own_message_unread_summary_with_discussions','get_group_discussion_message_page');
select ok(proconfig @> array['search_path=""'],proname||' fixes search path') from pg_proc where pronamespace='public'::regnamespace and proname in ('get_own_message_unread_summary_with_discussions','get_group_discussion_message_page');
select ok(strpos(pg_get_functiondef('private.group_discussion_command(uuid,uuid,text,uuid,uuid,jsonb)'::regprocedure),'perform private.require_group_identity(p_actor);')>0,'Exit checks live identity after locks');
select ok(strpos(pg_get_functiondef('private.group_discussion_signal(uuid)'::regprocedure),'private.signal_message_unread(p_actor)')>0,'Existing account unread hints include C invalidation');
select ok(not has_function_privilege('authenticated','private.pre_discussion_moderation_target_summary(private.moderation_cases)','execute'),'Summary helper is not a client API');
set local role anon;
select throws_ok($$select public.get_own_message_unread_summary_with_discussions(null)$$,'42501',null,'Guest gets no unread metadata');
reset role;
select * from finish();
rollback;
