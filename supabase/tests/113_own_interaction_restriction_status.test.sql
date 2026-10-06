begin;
select no_plan();
insert into auth.users(id,email)
select format('fa100000-0000-4000-8000-%s',lpad(n::text,12,'0'))::uuid,
  'own-status-' || n || '@planets.invalid' from generate_series(1,4) n;
insert into public.profiles(id,display_name)
select id,'Synthetic own-status profile' from auth.users
where id::text like 'fa100000-%' and id <> 'fa100000-0000-4000-8000-000000000004';
insert into private.moderation_staff_roles(profile_id,staff_role)
values('fa100000-0000-4000-8000-000000000001','admin');
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id)
values('fa200000-0000-4000-8000-000000000001','under_review',
 'fa100000-0000-4000-8000-000000000002','profile','fa100000-0000-4000-8000-000000000002');

select is(pg_get_function_result('public.get_own_interaction_restriction_status(uuid)'::regprocedure),
 'boolean','Projection is only one boolean, no staff/case/target/reason fields');
select ok(not has_function_privilege('anon','public.get_own_interaction_restriction_status(uuid)','execute'),
 'Anonymous has no execute grant');
select ok(not has_function_privilege('service_role','public.get_own_interaction_restriction_status(uuid)','execute'),
 'No service-only shortcut');
select ok(not has_function_privilege('authenticated','private.profile_has_active_interaction_restriction(uuid)','execute'),
 'Private arbitrary-subject predicate remains inaccessible');
set local role authenticated;
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000002';
select is(public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002'),false,
 'Inactive own state');
select throws_ok($$select public.get_own_interaction_restriction_status(null)$$,'42501',null,'Expected ID required');
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000003')$$,
 '42501',null,'Cannot read another identity');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000004';
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000004')$$,
 '42501',null,'Missing profile anchor denied');
set local request.jwt.claim.sub = '';
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002')$$,
 '42501',null,'Authenticated role without Auth identity denied');
set local role anon;
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002')$$,
 '42501',null,'Anonymous API denied');

set local role authenticated;
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000001';
create temporary table restriction_episode as select public.apply_moderation_consequence(
 'fa100000-0000-4000-8000-000000000001','fa200000-0000-4000-8000-000000000001',
 'interaction_restriction','Synthetic own reason','Synthetic private note') as id;
-- These 21 newer removed episodes conceal the active older restriction on page
-- one. Use canonical staff transitions, not a fabricated history page.
do $$
declare episode uuid;
begin
 for i in 1..21 loop
   episode := public.apply_moderation_consequence(
    'fa100000-0000-4000-8000-000000000001','fa200000-0000-4000-8000-000000000001',
    'safety_notice','Synthetic newer notice','Synthetic private note');
   perform public.revoke_moderation_consequence(
    'fa100000-0000-4000-8000-000000000001',episode,'Synthetic removed notice','Synthetic private note');
 end loop;
end;
$$;
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000002';
select is((select count(*)::int from public.list_own_moderation_consequences(
 'fa100000-0000-4000-8000-000000000002')),20,'History page is full');
select ok(not exists(select 1 from public.list_own_moderation_consequences(
 'fa100000-0000-4000-8000-000000000002') where consequence_type='interaction_restriction'),
 'Active older restriction is absent from first history page');
select is(public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002'),
 true,'Canonical current predicate still confirms active restriction');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000003';
select is(public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000003'),
 false,'Unrelated identity reads only its own inactive state');
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002')$$,
 '42501',null,'Active subject cannot be probed by another identity');

set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000001';
select public.revoke_moderation_consequence('fa100000-0000-4000-8000-000000000001',
 (select id from restriction_episode),'Synthetic removal','Synthetic private note');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000002';
select is(public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002'),
 false,'Revocation returns fresh inactive state');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000001';
create temporary table reapplied_episode as select public.apply_moderation_consequence(
 'fa100000-0000-4000-8000-000000000001','fa200000-0000-4000-8000-000000000001',
 'interaction_restriction','Synthetic reapplied reason','Synthetic private note') as id;
select isnt((select id from restriction_episode),(select id from reapplied_episode),'Reapply retains old episode');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000002';
select is(public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002'),
 true,'Reapply returns fresh active state');
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000001';
create temporary table suspension_episode as select public.apply_account_suspension(
 'fa100000-0000-4000-8000-000000000001','fa200000-0000-4000-8000-000000000001',
 'Synthetic suspension','Synthetic private note') as id;
set local request.jwt.claim.sub = 'fa100000-0000-4000-8000-000000000002';
select throws_ok($$select public.get_own_interaction_restriction_status('fa100000-0000-4000-8000-000000000002')$$,
 'PT403',null,'Ordinary own-state read is denied while suspended');
select throws_ok($$select * from public.list_own_moderation_consequences('fa100000-0000-4000-8000-000000000002')$$,
 'PT403',null,'General own history still denied while suspended');
select is((select is_suspended from public.get_own_account_suspension_status(
 'fa100000-0000-4000-8000-000000000002')),true,'Existing narrow suspension exception remains authoritative');
select * from finish();
rollback;
