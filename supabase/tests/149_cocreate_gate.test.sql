begin;
select no_plan();
select has_table('private','cocreate_settings','Experimental settings stay private');
select ok(relrowsecurity,'Settings have RLS defense in depth')
from pg_class where oid='private.cocreate_settings'::regclass;
select ok(not has_table_privilege(r,'private.cocreate_settings',p),r||' cannot '||p||' the gate')
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) p;
select ok(not has_function_privilege(r,oid,'EXECUTE'),r||' cannot call '||proname)
from pg_proc cross join unnest(array['anon','authenticated','service_role']) r
where pronamespace='private'::regnamespace and proname like '%cocreate%';
select ok(proconfig @> array['search_path=""'],proname||' fixes search path')
from pg_proc where proname like '%cocreate%';
select is(public.get_cocreate_availability(),'{"enabled":false}'::jsonb,'Availability defaults OFF');
select throws_ok($$select private.require_cocreate_enabled()$$,'42501','Co-creation is unavailable.','Disabled direct domain call denies');
set local role anon;
select is(public.get_cocreate_availability(),'{"enabled":false}'::jsonb,'Guests can inspect only availability');
select throws_ok($$update private.cocreate_settings set enabled=true$$,'42501',null,'Guest cannot activate');
select throws_ok($$select private.require_cocreate_actor(null)$$,'42501',null,'No guest private helper bypass');
reset role;
set local role authenticated;
select throws_ok($$update private.cocreate_settings set enabled=true$$,'42501',null,'Signed in cannot activate');
reset role;
update private.cocreate_settings set enabled=true;
select lives_ok($$select private.require_cocreate_enabled()$$,'Owner activation opens domain prerequisite only');
select throws_ok($$select private.require_cocreate_actor(null)$$,'42501',null,'Enabled does not imply admission');
insert into auth.users(id,email) values
 ('ca010000-0000-4000-8000-000000000001','cocreate-tap-ready@planets.invalid'),
 ('ca010000-0000-4000-8000-000000000002','cocreate-tap-incomplete@planets.invalid');
insert into public.profiles(id,display_name) values
 ('ca010000-0000-4000-8000-000000000001','Fictional ready actor'),
 ('ca010000-0000-4000-8000-000000000002',null);
select set_config('request.jwt.claim.sub','ca010000-0000-4000-8000-000000000001',true);
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000001')$$,'42501',null,'Existing policy acceptance required server-side');
insert into private.policy_acceptances(account_id,bundle_version)
values ('ca010000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1');
select is(private.require_cocreate_actor('ca010000-0000-4000-8000-000000000001'),
 'ca010000-0000-4000-8000-000000000001'::uuid,'Ready actor with current acceptance allowed');
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000002')$$,'42501',null,'Expected identity cannot select another actor');
update auth.users set banned_until=statement_timestamp()+interval '1 hour'
 where id='ca010000-0000-4000-8000-000000000001';
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000001')$$,'42501',null,'A retained JWT cannot bypass a live Auth ban');
update auth.users set banned_until=null,deleted_at=statement_timestamp()
 where id='ca010000-0000-4000-8000-000000000001';
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000001')$$,'42501',null,'Deleted identity cannot act through stale JWT');
update auth.users set deleted_at=null,is_anonymous=true
 where id='ca010000-0000-4000-8000-000000000001';
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000001')$$,'42501',null,'Anonymous Auth is not an eligible account');
select set_config('request.jwt.claim.sub','ca010000-0000-4000-8000-000000000002',true);
insert into private.policy_acceptances(account_id,bundle_version)
values ('ca010000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1');
select throws_ok($$select private.require_cocreate_actor('ca010000-0000-4000-8000-000000000002')$$,'42501',null,'Acceptance does not complete the profile');
update private.cocreate_settings set enabled=false;
select is(private.require_cocreate_identity('ca010000-0000-4000-8000-000000000002'),
 'ca010000-0000-4000-8000-000000000002'::uuid,'Identity-only own exit works while disabled/incomplete');
delete from private.cocreate_settings;
select is(public.get_cocreate_availability(),'{"enabled":false}'::jsonb,'Missing config fails closed');
select throws_ok($$select private.require_cocreate_enabled()$$,'42501',null,'Missing config does not open domain');
select * from finish();
rollback;
