begin;
select plan(27);

select has_table('private','message_streams','Unread serialization is application-owned');
select has_table('private','message_sources','Source identities stay separate from original messages');
select has_table('private','message_incoming','Send-time recipient eligibility is durable');
select has_table('private','message_read_frontiers','Own read frontiers are durable');
select has_table('private','message_read_snapshots','Read boundaries are server-issued snapshots');
select ok((select bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='private' and c.relname in ('message_streams','message_sources','message_incoming','message_read_frontiers','message_read_snapshots')),'Every unread table has RLS');
select ok(not exists(select 1 from information_schema.role_table_grants where table_schema='private'
  and table_name in ('message_streams','message_sources','message_incoming','message_read_frontiers','message_read_snapshots')
  and grantee in ('anon','authenticated','service_role')),'No client/service direct unread table grants');
select ok(not exists(select 1 from information_schema.columns where table_schema='private'
  and table_name in ('message_streams','message_sources','message_incoming','message_read_frontiers','message_read_snapshots')
  and column_name in ('body','request_message','read_at','exact_location')),'Metadata never stores bodies, request notes or read-receipt time');
select ok(has_function_privilege('authenticated','public.get_own_message_unread_summary(uuid)','EXECUTE'),'Authenticated summary boundary exists');
select ok(not has_function_privilege('anon','public.get_own_message_unread_summary(uuid)','EXECUTE'),'Anonymous callers cannot read totals');
select ok(not has_function_privilege('service_role','public.get_own_message_unread_summary(uuid)','EXECUTE'),'Service role cannot impersonate own-state RPC');
select ok(has_function_privilege('authenticated','public.acknowledge_own_message_read(uuid,text,uuid,uuid)','EXECUTE'),'Authenticated acknowledgement boundary exists');
select ok(not has_function_privilege('anon','public.acknowledge_own_message_read(uuid,text,uuid,uuid)','EXECUTE'),'Anonymous acknowledgement denied');
select ok(not has_function_privilege('authenticated','private.own_message_unread(uuid)','EXECUTE'),'Privileged aggregate cannot be called with a foreign identity');
select ok(not has_function_privilege('authenticated','private.message_recipients(text,uuid)','EXECUTE'),'Recipient enumeration is private');
select ok(not has_function_privilege('authenticated','private.signal_message_unread(uuid)','EXECUTE'),'Clients cannot forge own/foreign invalidations');
select ok(not has_function_privilege('authenticated','private.record_message_unread()','EXECUTE'),'Clients cannot invoke metadata writer');
select ok(not has_function_privilege('authenticated','private.can_read_message_conversation(text,uuid,uuid)','EXECUTE'),'History authorization helper is private');
select is((select count(*) from pg_trigger where not tgisinternal and tgname in ('msg02_record_pair','msg02_record_legacy','msg02_record_project','msg02_record_resource')),4::bigint,'All four immutable human-message sources share the writer');
select is((select count(*) from pg_trigger where not tgisinternal and tgname in ('msg02_membership_access','msg02_delegate_access','msg02_pair_access','msg02_pair_read_only','msg02_resource_read_only')),5::bigint,'Relevant access/read-only transitions invalidate');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.proname in ('record_message_unread','own_message_unread','get_own_message_unread_summary','get_own_message_feed_page','acknowledge_own_message_read','list_own_scoped_conversation_items_v3')
  and (not p.prosecdef or not coalesce(p.proconfig @> array['search_path=""'],false))),'Privileged functions have safe search paths');
select ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='realtime' and c.relname like 'message_unread%'),'No application objects added to realtime');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select throws_ok($$select * from private.message_incoming$$,'42501',null,'Own cursors cannot be read directly');
select throws_ok($$select public.get_own_message_unread_summary('00000000-0000-4000-8000-000000000002')$$,'42501',null,'Expected identity mismatch fails before exposing totals');
select throws_ok($$select public.acknowledge_own_message_read('00000000-0000-4000-8000-000000000002','project_chat','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004')$$,'42501',null,'Foreign acknowledgements fail');
select throws_ok($$select public.get_own_message_feed_page('00000000-0000-4000-8000-000000000002','project_chat','00000000-0000-4000-8000-000000000003',31)$$,'42501',null,'Foreign snapshots fail');
reset role;
select is((select count(*) from private.message_read_frontiers where profile_id='00000000-0000-4000-8000-000000000001'),0::bigint,'Failed foreign operations leave no read state');
select * from finish();
rollback;
