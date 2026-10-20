begin;
select plan(9);
select ok(p.prosecdef and p.provolatile='s' and p.proconfig @> array['search_path=""'],
  'Combined unread uses a stable authenticated snapshot and fixed search path')
from pg_proc p where p.oid='public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)'::regprocedure;
select ok(has_function_privilege('authenticated','public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)','execute')
  and not has_function_privilege('anon','public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)','execute')
  and not has_function_privilege('service_role','public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)','execute'),
  'Combined unread is an authenticated-only API');
select ok(to_regprocedure('public.get_own_message_unread_summary_with_discussions(uuid)') is not null
  and to_regprocedure('public.get_own_message_unread_summary_v3(uuid)') is not null,
  'Installed C and D/M readers remain available');
select ok(to_regprocedure('public.acknowledge_group_discussion_read_v2(uuid,uuid,text)') is not null
  and to_regprocedure('public.acknowledge_own_message_read_v3(uuid,text,uuid,uuid)') is not null,
  'C snapshot and D/M boundary ACKs remain separate');
select ok(p.prosecdef and p.provolatile='s' and p.proconfig @> array['search_path=""'],
  'Target-bound Idea selector is a stable read-only authorization projection')
from pg_proc p where p.oid='public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)'::regprocedure;
select ok(has_function_privilege('authenticated','public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)','execute')
  and not has_function_privilege('anon','public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)','execute')
  and not has_function_privilege('service_role','public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)','execute'),
  'Idea destination metadata is authenticated only');
set local role anon;
select throws_ok($$select public.get_own_message_unread_summary_with_contacts_and_discussions(null)$$,
  '42501',null,'Anonymous callers receive no combined unread metadata');
select throws_ok($$select public.list_group_discussion_invite_destinations(null,null,null)$$,
  '42501',null,'Anonymous callers receive no Idea destinations');
reset role;
set local role authenticated;
select throws_ok($$select public.get_own_message_unread_summary_with_contacts_and_discussions('e0600000-0000-4000-8000-000000000001')$$,
  '42501',null,'An authenticated role without an actor cannot read another identity');
reset role;
select * from finish();
rollback;
