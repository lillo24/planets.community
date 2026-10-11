begin;
select no_plan();

select ok((select relrowsecurity from pg_class where oid='private.location_text_origins'::regclass),
  'Public text provenance storage has RLS');
select ok(not has_table_privilege('anon','private.location_text_origins','select,insert,update,delete'),
  'Anonymous clients cannot inspect or forge provenance');
select ok(not has_table_privilege('authenticated','private.location_text_origins','select,insert,update,delete'),
  'Authenticated clients cannot inspect or forge provenance');
select ok(not has_table_privilege('service_role','private.location_text_origins','select,insert,update,delete'),
  'Edge service cannot forge manual authorship');
select ok(not has_function_privilege('anon','public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text)','execute'),
  'Anonymous clients cannot confirm manual authorship');
select ok(not has_function_privilege('service_role','public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text)','execute'),
  'Service role cannot impersonate a manual editor');
select ok(has_function_privilege('authenticated','public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text)','execute'),
  'Signed-in editor has the guarded manual confirmation entry point');

set local role authenticated;
select throws_ok($$select private.public_location_text_source('one_time',gen_random_uuid())$$,'42501',null,
  'Private provenance helper is unavailable directly to clients');
select throws_ok($$select * from private.location_text_origins$$,'42501',null,
  'Clients cannot enumerate private provenance records');
reset role;

select * from finish();
rollback;
