begin;
select no_plan();

insert into auth.users(id,email) values
  ('fc010000-0000-4000-8000-000000000001','modint-owner@planets.invalid'),
  ('fc010000-0000-4000-8000-000000000002','modint-staff@planets.invalid'),
  ('fc010000-0000-4000-8000-000000000003','modint-viewer@planets.invalid');
insert into public.profiles(id,display_name)
select id,'Synthetic MODINT01 person' from auth.users where id::text like 'fc010000-%';
insert into private.moderation_staff_roles(profile_id,staff_role)
values('fc010000-0000-4000-8000-000000000002','admin');
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
values('fc020000-0000-4000-8000-000000000001','fc010000-0000-4000-8000-000000000001',
  'published','MODINT01 proposal',now()+interval '1 day',now()+interval '2 days',now());
insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at)
values('fc020000-0000-4000-8000-000000000002','fc010000-0000-4000-8000-000000000001',
  'published','MODINT01 Tavolo',now());
update public.projects set registration_capacity=10 where id::text like 'fc020000-%';
create temp table modint_links(project_id uuid,invitation_id uuid,invite_token text,created_at timestamptz);
grant select,insert on modint_links to authenticated;
grant select on modint_links to anon;
set local role authenticated;
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
insert into modint_links select 'fc020000-0000-4000-8000-000000000001',*
from public.create_project_participant_invitation('fc010000-0000-4000-8000-000000000001','fc020000-0000-4000-8000-000000000001');
insert into modint_links select 'fc020000-0000-4000-8000-000000000002',*
from public.create_project_participant_invitation('fc010000-0000-4000-8000-000000000001','fc020000-0000-4000-8000-000000000002');
select results_eq($$select available from modint_links l cross join lateral
  public.get_project_participant_invitation_preview(l.invite_token) p order by l.project_id$$,
  $$values(true),(true)$$,'both published kinds initially previewable');
reset role;
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_project_id,project_context_id)
select project_id,'under_review','fc010000-0000-4000-8000-000000000001','project',project_id,project_id from modint_links;
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
create temp table modint_hides as select project_id,public.apply_moderation_consequence(
  'fc010000-0000-4000-8000-000000000002',project_id,'content_hide','Synthetic hidden content','Synthetic private note') as episode_id
from modint_links;

set local role anon;
select set_config('request.jwt.claim.sub','',true);
select results_eq($$select available,p.project_id,project_kind,project_title from modint_links l
  cross join lateral public.get_project_participant_invitation_preview(l.invite_token) p order by l.project_id$$,
  $$values(false,null::uuid,null::text,null::text),(false,null::uuid,null::text,null::text)$$,
  'anonymous hidden proposal/Tavolo previews disclose no title or identifier');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000003',true);
select results_eq($$select available,p.project_id,project_kind,project_title from modint_links l
  cross join lateral public.get_project_participant_invitation_preview(l.invite_token) p order by l.project_id$$,
  $$values(false,null::uuid,null::text,null::text),(false,null::uuid,null::text,null::text)$$,
  'authenticated hidden previews use the same canonical boundary');
select throws_ok($$select * from public.accept_project_participant_invitation('fc010000-0000-4000-8000-000000000003',
  (select invite_token from modint_links where project_id='fc020000-0000-4000-8000-000000000001'),gen_random_uuid())$$,
  'PT409','This interaction is unavailable.','hidden proposal denies fresh admission');
select throws_ok($$select * from public.accept_project_participant_invitation('fc010000-0000-4000-8000-000000000003',
  (select invite_token from modint_links where project_id='fc020000-0000-4000-8000-000000000002'),gen_random_uuid())$$,
  'PT409','This interaction is unavailable.','hidden Tavolo denies fresh admission');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
select is((select count(*) from modint_links l cross join lateral
  public.get_current_project_participant_invitation('fc010000-0000-4000-8000-000000000001',l.project_id)),2::bigint,
  'authorized private management retains current sharing history');
select throws_ok($$select * from public.regenerate_project_participant_invitation(
  'fc010000-0000-4000-8000-000000000001','fc020000-0000-4000-8000-000000000002')$$,
  'PT409','This Project is not accepting participant invitations.','hide cannot be bypassed by rotating a generation');
reset role;
select is((select count(*) from public.project_memberships where project_id::text like 'fc020000-%'),0::bigint,'denial creates no membership');
select is((select count(*) from private.project_participant_admissions where project_id::text like 'fc020000-%'),0::bigint,'denial creates no action receipt');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
select public.revoke_moderation_consequence('fc010000-0000-4000-8000-000000000002',episode_id,
  'Synthetic visible again','Synthetic private revoke note') from modint_hides;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select results_eq($$select available from modint_links l cross join lateral
  public.get_project_participant_invitation_preview(l.invite_token) p order by l.project_id$$,
  $$values(true),(true)$$,'unhide restores ordinary published visibility without rotating tokens');
reset role;
update public.recurring_activities set lifecycle_state='paused' where id='fc020000-0000-4000-8000-000000000002';
update public.proposals set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day'
where id='fc020000-0000-4000-8000-000000000001';
set local role anon;
select results_eq($$select available,p.project_id,project_kind,project_title from modint_links l
  cross join lateral public.get_project_participant_invitation_preview(l.invite_token) p order by l.project_id$$,
  $$values(false,null::uuid,null::text,null::text),(false,null::uuid,null::text,null::text)$$,
  'unhide does not reopen expired proposals or paused Tavoli');
reset role;
select * from finish();
rollback;
