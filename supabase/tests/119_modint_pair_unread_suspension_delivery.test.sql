begin;
select plan(8);
select is((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prosrc ~ 'realtime[.]send[[:space:]]*[(]'),1::bigint,
  'All private broadcasters compose one suspended-recipient filter');
select ok(position('private.send_account_active_realtime' in pg_get_functiondef(
  'private.signal_participation_conversation(uuid)'::regprocedure))>0,'Pair hints use the canonical delivery boundary');
select ok(position('private.send_account_active_realtime' in pg_get_functiondef(
  'private.signal_message_unread(uuid)'::regprocedure))>0,'Unread hints use the canonical delivery boundary');
select ok(position('private.send_account_active_realtime' in pg_get_functiondef(
  'public.send_project_join_request_chat_message(uuid,uuid,text)'::regprocedure))>0,'Legacy sends retain filtered endpoint delivery');
select ok(not has_function_privilege('authenticated','private.send_account_active_realtime(jsonb,text,text,boolean)','EXECUTE'),
  'Clients cannot forge private deliveries');
select ok(exists(select 1 from pg_policy where polname='account_active_required' and not polpermissive),
  'Suspension remains a restrictive rule for new joins, including pair/unread policies');
select throws_ok($$select private.send_account_active_realtime('{}','synthetic','message-unread:profile:not-a-profile',true)$$,
  '22023',null,'Invalid unread addressing fails loudly');
select throws_ok($$select private.send_account_active_realtime('{}','synthetic','message-unread:profile:00000000-0000-4000-8000-000000000001',false)$$,
  '22023',null,'Public delivery cannot bypass the private recipient rule');
select * from finish();
rollback;
