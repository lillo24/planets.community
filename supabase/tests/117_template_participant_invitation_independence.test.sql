begin;
select no_plan();
-- Synthetic source setup; invitations, admission/revocation and copying use
-- the real actor operations. Only the elapsed-time fixture clock is trusted SQL.
insert into auth.users(id,email) values
 ('fa710000-0000-4000-8000-000000000001','stack-source@planets.invalid'),
 ('fa710000-0000-4000-8000-000000000002','stack-participant@planets.invalid'),
 ('fa710000-0000-4000-8000-000000000003','stack-copy@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic stack actor' from auth.users where email in ('stack-source@planets.invalid','stack-participant@planets.invalid','stack-copy@planets.invalid');
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,description,starts_at,ends_at,published_at)
values ('fa720000-0000-4000-8000-000000000001','fa710000-0000-4000-8000-000000000001','published','Independent template source','Reusable synthetic text',now()+interval '1 day',now()+interval '2 days',now());
update public.projects set registration_capacity=8 where id='fa720000-0000-4000-8000-000000000001';
create temp table stack_links(invitation_id uuid,invite_token text,created_at timestamptz);
create temp table stack_copy(proposal_id uuid,source_proposal_id uuid,accepted_content_version text,accepted_at timestamptz);
grant all on stack_links,stack_copy to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa710000-0000-4000-8000-000000000001',true);
insert into stack_links select * from public.create_project_participant_invitation('fa710000-0000-4000-8000-000000000001','fa720000-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub','fa710000-0000-4000-8000-000000000002',true);
select public.accept_project_participant_invitation('fa710000-0000-4000-8000-000000000002',invite_token,'fa730000-0000-4000-8000-000000000001') from stack_links;
select set_config('request.jwt.claim.sub','fa710000-0000-4000-8000-000000000001',true);
select public.revoke_project_participant_invitation('fa710000-0000-4000-8000-000000000001','fa720000-0000-4000-8000-000000000001',invitation_id) from stack_links;
insert into stack_links select * from public.create_project_participant_invitation('fa710000-0000-4000-8000-000000000001','fa720000-0000-4000-8000-000000000001');
reset role;
update public.proposals set starts_at=now()-interval '4 days',ends_at=now()-interval '3 days' where id='fa720000-0000-4000-8000-000000000001';
select set_config('test.stack_template',(select id::text from private.proposal_templates where source_proposal_id='fa720000-0000-4000-8000-000000000001'),true);
select set_config('test.stack_version',(select private.proposal_template_content_version(private.proposal_template_reusable_content('fa720000-0000-4000-8000-000000000001'))),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','fa710000-0000-4000-8000-000000000003',true);
insert into stack_copy select proposal_id,source_proposal_id,accepted_content_version,accepted_at from public.create_proposal_draft_from_template('fa710000-0000-4000-8000-000000000003',current_setting('test.stack_template')::uuid,current_setting('test.stack_version'),'fa730000-0000-4000-8000-000000000002',false);
reset role;
select is((select count(*) from public.project_memberships where project_id='fa720000-0000-4000-8000-000000000001' and originating_request_id is null and originating_participant_invitation_id is not null),1::bigint,'source retains real direct-admission origin');
select is((select count(*) from private.project_participant_invitations where project_id='fa720000-0000-4000-8000-000000000001'),2::bigint,'source retains current and revoked generations');
select is((select count(*) from public.proposals where id in (select proposal_id from stack_copy) and lifecycle_state='draft' and creator_profile_id='fa710000-0000-4000-8000-000000000003'),1::bigint,'independent draft belongs to copying actor');
select is((select count(*) from public.project_memberships where project_id in (select proposal_id from stack_copy)),0::bigint,'copy contains no source participants or origins');
select is((select count(*) from private.project_participant_invitations where project_id in (select proposal_id from stack_copy)),0::bigint,'copy inherits no current/revoked capability generation');
select is((select count(*) from private.project_participant_admissions where project_id in (select proposal_id from stack_copy)),0::bigint,'copy inherits no admission receipts');
select is((select count(*) from public.project_join_requests where project_id in (select proposal_id from stack_copy)),0::bigint,'copy fabricates no request');
select is((select count(*) from private.proposal_template_applications where proposal_id in (select proposal_id from stack_copy)),1::bigint,'copy has only its own accepted template provenance');
select * from finish();
rollback;
