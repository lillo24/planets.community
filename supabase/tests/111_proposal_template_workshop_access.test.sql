begin;
select no_plan();

insert into auth.users (id,email) values
  ('e1000000-0000-4000-8000-000000000001','tw01-owner@planets.invalid'),
  ('e1000000-0000-4000-8000-000000000002','tw01-cocreator@planets.invalid'),
  ('e1000000-0000-4000-8000-000000000003','tw01-participant@planets.invalid'),
  ('e1000000-0000-4000-8000-000000000004','tw01-unrelated@planets.invalid');
insert into public.profiles (id,display_name)
select id, 'TW01 ' || right(id::text,1) from auth.users where id::text like 'e1000000-%';
select set_config('test.tw_skill', (select id::text from public.skills order by id limit 1), true);

-- Keep test invocations on each existing structural overload. This helper adds
-- no authority: it runs as the calling role and calls canonical RPCs only.
create function pg_temp.tw_edit(p_actor uuid, p_title text, p_overload integer default 0)
returns uuid language plpgsql security invoker as $$
begin
  if p_overload = 1 then
    return public.update_own_proposal(p_actor,current_setting('test.tw_source')::uuid,
      p_title,'Published summary','Published reusable description',
      current_setting('test.tw_start')::timestamptz,current_setting('test.tw_end')::timestamptz,
      'Europe/Rome','IT','Trento','TN','Trento','MEETING_SECRET','public',
      array[current_setting('test.tw_skill')::uuid],array['useful'],9);
  elsif p_overload = 2 then
    return public.update_own_proposal(p_actor,current_setting('test.tw_source')::uuid,
      p_title,'Published summary','Published reusable description',
      current_setting('test.tw_start')::timestamptz,current_setting('test.tw_end')::timestamptz,
      'Europe/Rome','IT','Trento','TN','Trento','MEETING_SECRET','public',
      array[current_setting('test.tw_skill')::uuid],array['useful'],10,true);
  end if;
  return public.update_own_proposal(p_actor,current_setting('test.tw_source')::uuid,
    p_title,'Published summary','Published reusable description',
    current_setting('test.tw_start')::timestamptz,current_setting('test.tw_end')::timestamptz,
    'Europe/Rome','IT','Trento','TN','Trento','MEETING_SECRET','public',
    array[current_setting('test.tw_skill')::uuid],array['required']);
end;
$$;
grant execute on function pg_temp.tw_edit(uuid,text,integer) to authenticated;
select set_config('test.tw_start',(statement_timestamp()+interval '2 days')::text,true);
select set_config('test.tw_end',(statement_timestamp()+interval '2 days 2 hours')::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select set_config('test.tw_source',public.create_proposal_draft(
  'e1000000-0000-4000-8000-000000000001','Saved Bozza','Saved summary','BOZZA_PRIVATE',
  current_setting('test.tw_start')::timestamptz,current_setting('test.tw_end')::timestamptz,
  'Europe/Rome','IT','Trento','TN','Trento','MEETING_SECRET','public',
  array[current_setting('test.tw_skill')::uuid],array['required'])::text,true);
select lives_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000001','Latest saved Bozza')$$,
  'private draft save retains existing behavior');
reset role;
select is((select count(*) from private.proposal_templates where source_proposal_id=current_setting('test.tw_source')::uuid),
  0::bigint,'draft save establishes no template');
-- Distinctive retained draft content; publication captures the actual last save.
update public.proposals set description='BOZZA_PRIVATE' where id=current_setting('test.tw_source')::uuid;
update public.projects set registration_capacity=8 where id=current_setting('test.tw_source')::uuid;
set local role authenticated;
select throws_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid)$$,
  'PT422',null,'publication still requires a canonical photo');
reset role;
select is((select count(*) from private.proposal_templates),0::bigint,'failed photo publication leaves no identity');
insert into public.profile_photos(profile_id,object_path,audience)
select id,id::text || '/e2000000-0000-4000-8000-000000000001.webp','interactions'
from public.profiles where id::text like 'e1000000%';
update public.projects set registration_capacity=null where id=current_setting('test.tw_source')::uuid;
set local role authenticated;
select throws_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid)$$,
  '22023',null,'publication still requires configured capacity');
reset role;
select is((select count(*) from private.proposal_template_baselines),0::bigint,'failed publication leaves no successful baseline');
update public.projects set registration_capacity=8 where id=current_setting('test.tw_source')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000004',current_setting('test.tw_source')::uuid)$$,
  '42501',null,'unrelated publication remains denied');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid)$$,
  'first publication succeeds');
reset role;
select set_config('test.tw_template',(select id::text from private.proposal_templates where source_proposal_id=current_setting('test.tw_source')::uuid),true);
select is((select count(*) from private.proposal_templates),1::bigint,'first publication synchronously creates exactly one identity');
select is((select description from private.proposal_template_baselines), 'BOZZA_PRIVATE','baseline captures the last persisted draft');
select is((select title from private.proposal_template_baselines),'Latest saved Bozza','baseline is latest saved text, not earliest idea');
select is((select skill_selections->0->>'importance' from private.proposal_template_baselines),'required','saved draft selections are retained');
select set_config('test.tw_baseline',(select to_jsonb(b)::text from private.proposal_template_baselines as b),true);
select set_config('test.tw_version',private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),true);
set local role authenticated;
select lives_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid)$$,'publication retry succeeds');
select is((select count(*) from public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_template')::uuid)),1::bigint,'original Creator can read own baseline');
select throws_ok($$select public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000004',current_setting('test.tw_template')::uuid)$$,'42501',null,'wrong expected identity cannot read baseline');
reset role;
select is((select count(*) from private.audit_events where action='proposal.published' and target_id=current_setting('test.tw_source')::uuid),1::bigint,'retry creates no duplicate audit event');
select is((select count(*) from private.outbox_events where event_type='proposal.published' and payload->>'proposal_id'=current_setting('test.tw_source')),1::bigint,'retry creates no duplicate outbox event');
select is((select count(*) from private.proposal_templates),1::bigint,'retry creates no second identity');
select is((select to_jsonb(b)::text from private.proposal_template_baselines as b),current_setting('test.tw_baseline'),'retry does not overwrite baseline');
set local role anon;
select is((select count(*) from public.list_public_proposal_templates()),0::bigint,'publication alone does not expose the template');
select is((select count(*) from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),0::bigint,'exact ID cannot bypass Completed');
select throws_ok($$select public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_template')::uuid)$$,'42501',null,'anonymous baseline access is denied');
reset role;

-- Canonical delegation, not a fabricated authority row.
set local role authenticated;
select set_config('test.tw_invite',(select invite_token from public.create_project_delegate_invitation(
  'e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid,'co_creator')),true);
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
select set_config('test.tw_delegate',public.accept_project_delegate_invitation('e1000000-0000-4000-8000-000000000002',current_setting('test.tw_invite'))::text,true);
select throws_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000002',current_setting('test.tw_source')::uuid)$$,'42501',null,'Co-creator still cannot publish');
select throws_ok($$select public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000002',current_setting('test.tw_template')::uuid)$$,'42501',null,'Co-creator has no original private Bozza access');
select lives_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000002','Co-creator latest',1)$$,'Co-creator legacy capacity overload edits published content');
reset role;
select isnt(private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),current_setting('test.tw_version'),'Co-creator text/skill/capacity changes change version');
select set_config('test.tw_version',private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),true);
set local role authenticated;
select lives_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000002','Co-creator latest',1)$$,'identical edit succeeds');
reset role;
select is(private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),current_setting('test.tw_version'),'identical content preserves token despite timestamps/events');
set local role authenticated;
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000001','Final reusable %_ idea',2)$$,'Creator new organizer-capacity overload updates the same source');
select set_config('test.tw_need',public.create_project_resource_need('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid,'Reusable tools','Reusable tool details')::text,true);
reset role;
select set_config('test.tw_version',private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),true);
set local role authenticated;
select lives_ok($$select public.update_project_resource_need('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_need')::uuid,'Updated tools','Updated details')$$,'source need update uses existing authority');
reset role;
select isnt(private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),current_setting('test.tw_version'),'need text update changes reusable token');
select set_config('test.tw_version',private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),true);
set local role authenticated;
select lives_ok($$select public.close_project_resource_need('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_need')::uuid)$$,'source need can close before cutoff');
reset role;
select is(jsonb_array_length(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)->'resource_blueprints'),0,'closed need is absent, without a fulfillment assertion');
select isnt(private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),current_setting('test.tw_version'),'closing need changes version');
select is((select to_jsonb(b)::text from private.proposal_template_baselines as b),current_setting('test.tw_baseline'),'published changes never overwrite original baseline');

-- Capacity policy/headcounts, meeting/workspace, and attribution are not copied.
select set_config('test.tw_version',private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),true);
update public.projects set count_organizers_toward_capacity=false where id=current_setting('test.tw_source')::uuid;
update public.proposal_meeting_details set exact_meeting_text='NEW_MEETING_SECRET' where proposal_id=current_setting('test.tw_source')::uuid;
insert into public.project_shared_workspaces(project_id,workspace_url)
values (current_setting('test.tw_source')::uuid,'https://example.invalid/WORKSPACE_SECRET');
select is(private.proposal_template_content_version(private.proposal_template_reusable_content(current_setting('test.tw_source')::uuid)),current_setting('test.tw_version'),'operational logistics and organizer policy do not change copied content');
set local role authenticated;
select lives_ok($$select public.revoke_project_delegate('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_delegate')::uuid)$$,'Creator revokes delegate');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
select throws_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000002','Unauthorized overwrite')$$,'42501',null,'revoked delegate cannot edit reusable source');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000003',true);
reset role;
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
values ('e5000000-0000-4000-8000-000000000003',current_setting('test.tw_source')::uuid,'e1000000-0000-4000-8000-000000000003','accepted',now()-interval '2 days',now()-interval '1 day','e1000000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
values ('e6000000-0000-4000-8000-000000000003',current_setting('test.tw_source')::uuid,'e1000000-0000-4000-8000-000000000003','e5000000-0000-4000-8000-000000000003',now()-interval '1 day');
set local role authenticated;
select throws_ok($$select public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000003',current_setting('test.tw_template')::uuid)$$,'42501',null,'other profile receives no baseline');
select throws_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000003','Participant overwrite')$$,'42501',null,'participant cannot edit source through template internals');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select set_config('test.tw_invite',(select invite_token from public.create_project_delegate_invitation(
  'e1000000-0000-4000-8000-000000000001',current_setting('test.tw_source')::uuid,'co_organizer')),true);
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
select public.accept_project_delegate_invitation('e1000000-0000-4000-8000-000000000002',current_setting('test.tw_invite'));
select throws_ok($$select public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000002',current_setting('test.tw_template')::uuid)$$,'42501',null,'Co-organizer has no private Bozza access');
select throws_ok($$select pg_temp.tw_edit('e1000000-0000-4000-8000-000000000002','Co-organizer overwrite')$$,'42501',null,'Co-organizer cannot structurally edit source');
reset role;

-- Trusted historical fixture with more than one public blueprint page.
insert into public.project_resource_needs(id,project_id,title,details)
select ('e3000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,current_setting('test.tw_source')::uuid,
  'Blueprint ' || n,'Reusable only' from generate_series(1,55) as n;
update public.proposals set starts_at=statement_timestamp()-interval '26 hours',ends_at=statement_timestamp()-interval '24 hours' where id=current_setting('test.tw_source')::uuid;
select ok(private.is_proposal_template_publicly_usable(current_setting('test.tw_template')::uuid,
  (select ends_at+interval '24 hours' from public.proposals where id=current_setting('test.tw_source')::uuid)),
  'eligible at exact canonical Completed boundary');
select ok(not private.is_proposal_template_publicly_usable(current_setting('test.tw_template')::uuid,
  (select ends_at+interval '24 hours'-interval '1 microsecond' from public.proposals where id=current_setting('test.tw_source')::uuid)),
  'not eligible one microsecond before Completed');
select set_config('test.tw_public_version',(select content_version from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),true);
set local role anon;
select is((select count(*) from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),1::bigint,'Completed detail is deliberately anonymous');
select is((select resource_blueprint_count from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),55,'detail states complete blueprint count');
select is((select count(*) from public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,current_setting('test.tw_public_version'),50)),50::bigint,'first blueprint page is bounded');
select is((select count(*) from public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,current_setting('test.tw_public_version'),50,'e3000000-0000-4000-8000-000000000050')),5::bigint,'second page contains all remaining blueprints');
select is((select array_agg(key order by key) from public.get_public_proposal_template(current_setting('test.tw_template')::uuid) as detail
  cross join lateral jsonb_object_keys(to_jsonb(detail)) as key),
  array['content_version','cover_object_path','creator_display_name','description','duration_seconds','original_creator_profile_id','registration_capacity_recommendation','resource_blueprint_count','skills','source_proposal_id','summary','template_id','title'],
  'public detail schema is an explicit reusable allow-list');
select ok((select to_jsonb(detail)::text not like '%BOZZA_PRIVATE%' and to_jsonb(detail)::text not like '%MEETING_SECRET%'
  and to_jsonb(detail)::text not like '%WORKSPACE_SECRET%'
  from public.get_public_proposal_template(current_setting('test.tw_template')::uuid) as detail),'private draft/meeting marker values are absent');
select is((select count(*) from public.list_public_proposal_templates(p_query=>'%_')),1::bigint,'query treats wildcard-looking text literally');
select is((select count(*) from public.list_public_proposal_templates(p_query=>'unmatched search')),0::bigint,'valid unmatched query is a legitimate empty result');
select is((select count(*) from public.list_public_proposal_templates(p_skill_ids=>array[current_setting('test.tw_skill')::uuid])),1::bigint,'controlled skill filter finds eligible source');
select throws_ok($$select public.list_public_proposal_templates(0)$$,'22023',null,'zero page limit is rejected');
select throws_ok($$select public.list_public_proposal_templates(51)$$,'22023',null,'unbounded catalog limit is rejected');
select throws_ok($$select public.list_public_proposal_templates(null)$$,'22023',null,'null limit is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_cursor_id=>gen_random_uuid())$$,'22023',null,'partial cursor is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_cursor_linked_at=>'infinity',p_cursor_id=>gen_random_uuid())$$,'22023',null,'non-finite cursor is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_query=>repeat('x',121))$$,'22023',null,'long search is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_skill_ids=>array[null]::uuid[])$$,'22023',null,'null skill is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_skill_ids=>array['ffffffff-ffff-4fff-8fff-ffffffffffff']::uuid[])$$,'22023',null,'unknown skill is rejected');
select throws_ok($$select public.list_public_proposal_templates(p_skill_ids=>array_fill(current_setting('test.tw_skill')::uuid,array[51]))$$,'22023',null,'oversized filter array is rejected');
select throws_ok($$select public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,'invalid')$$,'22023',null,'blueprint version is validated');
select throws_ok($$select public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,current_setting('test.tw_public_version'),51)$$,'22023',null,'blueprint bound is validated');
select throws_ok($$select public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,'tw01:' || repeat('0',64))$$,'PT409',null,'different version is explicit conflict, never a mixed page');
select is((select count(*) from public.get_public_proposal_template('ffffffff-ffff-4fff-8fff-ffffffffffff')),0::bigint,'unknown detail has privacy-safe zero rows');
reset role;

insert into public.profile_field_visibility(profile_id,field_key,audience)
values ('e1000000-0000-4000-8000-000000000001','display_name','private')
on conflict(profile_id,field_key) do update set audience=excluded.audience;
select is((select creator_display_name from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),null::text,'name privacy is live, without contextual group permission');
select is((select content_version from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),current_setting('test.tw_public_version'),'attribution privacy is separate from copied-content version');
update private.proposal_templates set removed_at=statement_timestamp() where id=current_setting('test.tw_template')::uuid;
set local role anon;
select is((select count(*) from public.list_public_proposal_templates()),0::bigint,'removed content is absent from catalog');
select is((select count(*) from public.get_public_proposal_template(current_setting('test.tw_template')::uuid)),0::bigint,'exact ID cannot bypass removal');
select is((select count(*) from public.list_public_proposal_template_resource_blueprints(current_setting('test.tw_template')::uuid,current_setting('test.tw_public_version'))),0::bigint,'blueprints share removal gate');
reset role;
select throws_ok($$update private.proposal_templates set original_creator_profile_id='e1000000-0000-4000-8000-000000000004'$$,'55000',null,'even trusted identity reassignment is rejected');
select throws_ok($$update private.proposal_template_baselines set description='Overwritten'$$,'55000',null,'baseline is immutable');

-- Trusted legacy insert models records with no retained publication draft.
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
values ('e4000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','published','Legacy source',
  statement_timestamp()-interval '3 days',statement_timestamp()-interval '2 days',statement_timestamp()-interval '4 days');
select set_config('test.tw_legacy',(select id::text from private.proposal_templates where source_proposal_id='e4000000-0000-4000-8000-000000000001'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.get_own_proposal_template_baseline('e1000000-0000-4000-8000-000000000001',current_setting('test.tw_legacy')::uuid)),0::bigint,'legacy baseline absence is honest');
select lives_ok($$select public.publish_proposal('e1000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001')$$,'legacy retry preserves existing publication');
reset role;
update public.proposals set lifecycle_state='cancelled',cancelled_at=statement_timestamp() where id='e4000000-0000-4000-8000-000000000001';
select is((select count(*) from public.get_public_proposal_template(current_setting('test.tw_legacy')::uuid)),0::bigint,'cancelled historical source is never usable');
select is((select count(*) from private.proposal_templates where source_proposal_id='e4000000-0000-4000-8000-000000000001'),1::bigint,'cancellation retains internal identity only');

select * from finish();
rollback;
