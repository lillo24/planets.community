begin;
select no_plan();
insert into auth.users(id,email) values
 ('fa020000-0000-4000-8000-000000000001','idea-owner@planets.invalid'),
 ('fa020000-0000-4000-8000-000000000002','idea-member@planets.invalid'),
 ('fa020000-0000-4000-8000-000000000003','idea-outsider@planets.invalid');
insert into public.profiles(id,display_name)
 select id,'Synthetic Idea actor' from auth.users where id::text like 'fa020000-%';
insert into public.profile_photos(profile_id,object_path,audience)
 select id,id::text||'/00000000-0000-4000-8000-000000000001.webp','interactions'
 from public.profiles where id::text like 'fa020000-%';

create function pg_temp.idea_draft(explanation text default 'Organize something useful together.')
returns uuid language sql as $$
 select public.create_proposal_draft(auth.uid(),'IDEA01A test',explanation,null,
 null,null,null,null,null,null,null,null,'participants',array[]::uuid[],array[]::text[],null,false)
$$;
create function pg_temp.idea_edit(item uuid,fields jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.proposals%rowtype; c public.projects%rowtype;
begin
 select * into p from public.proposals where id=item;
 select * into c from public.projects where id=item;
 return public.update_own_proposal(auth.uid(),item,
  case when fields?'title' then fields->>'title' else p.title end,
  case when fields?'summary' then fields->>'summary' else p.summary end,
  case when fields?'description' then fields->>'description' else p.description end,
  case when fields?'starts_at' then (fields->>'starts_at')::timestamptz else p.starts_at end,
  case when fields?'ends_at' then (fields->>'ends_at')::timestamptz else p.ends_at end,
  case when fields?'event_timezone' then fields->>'event_timezone' else p.event_timezone end,
  case when fields?'country_code' then fields->>'country_code' else p.country_code end,
  case when fields?'locality' then fields->>'locality' else p.locality end,
  case when fields?'administrative_area' then fields->>'administrative_area' else p.administrative_area end,
  case when fields?'public_location_label' then fields->>'public_location_label' else p.public_location_label end,
  case when fields?'exact_meeting_text' then fields->>'exact_meeting_text' else null end,
  coalesce(fields->>'exact_location_visibility','participants'),
  array[]::uuid[],array[]::text[],
  case when fields?'registration_capacity' then (fields->>'registration_capacity')::integer else c.registration_capacity end,
  c.count_organizers_toward_capacity);
end;
$$;
grant execute on function pg_temp.idea_draft(text),pg_temp.idea_edit(uuid,jsonb) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select set_config('test.idea',pg_temp.idea_draft()::text,true);
select is((select count(*) from public.get_public_proposal_v2(current_setting('test.idea')::uuid)),0::bigint,'a saved draft stays private');
select throws_ok($$select public.publish_proposal('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'22023',null,'ordinary Defined publication still requires logistics');
select set_config('test.short',pg_temp.idea_draft('x')::text,true);
select throws_ok($$select public.publish_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.short')::uuid)$$,'PT422',null,'Idea needs readable explanation');
select lives_ok($$select public.publish_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'publish Idea without any fabricated logistics/capacity');
select lives_ok($$select public.publish_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'Idea publication retry is idempotent');
select results_eq($$select definition_phase,derived_status,starts_at,ends_at,event_timezone,country_code,locality,exact_meeting_text,exact_location_restricted from public.get_public_proposal_v2(current_setting('test.idea')::uuid)$$,
 $$values ('idea'::text,null::text,null::timestamptz,null::timestamptz,null::text,null::text,null::text,null::text,false)$$,'versioned detail honestly preserves absence');
select is((select registration_capacity from public.list_public_project_capacity_statuses(array[current_setting('test.idea')::uuid])),null::integer,'public capacity remains undecided');
select is((select count(*) from public.get_public_proposal(current_setting('test.idea')::uuid)),0::bigint,'old direct detail hides Idea');
select is((select count(*) from public.list_public_proposals() where proposal_id=current_setting('test.idea')::uuid),0::bigint,'old List excludes Idea');
select is((select count(*) from public.list_own_proposals('fa020000-0000-4000-8000-000000000001') where proposal_id=current_setting('test.idea')::uuid),0::bigint,'old own List excludes Idea');
select is((select count(*) from public.get_own_proposal('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)),0::bigint,'old own detail excludes Idea');
select is((select count(*) from public.list_own_proposals_v2('fa020000-0000-4000-8000-000000000001') where proposal_id=current_setting('test.idea')::uuid),1::bigint,'new own List includes Idea');
select is((select definition_phase from public.get_own_proposal_v2('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)),'idea','new owner detail is phase-aware');
select throws_ok($$select public.publish_proposal('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'55000',null,'ordinary publish never silently promotes');
select throws_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"event_timezone":"Not/AZone"}')$$,'22023',null,'invalid optional timezone rejected');
select throws_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"starts_at":"infinity"}')$$,'22023',null,'infinite tentative date rejected');
select throws_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"country_code":"ITA"}')$$,'22023',null,'optional country bounds retained');
select throws_ok($$select public.promote_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'PT422',null,'promotion rejects missing planning fields atomically');
select is((select definition_phase from public.get_public_proposal_v2(current_setting('test.idea')::uuid)),'idea','failed promotion preserves public Idea');
select ok((public.get_proposal_promotion_requirements('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)->'missing_fields') ?& array['description','starts_at','ends_at','event_timezone','country_code','locality','public_location_label','registration_capacity'],'preview lists actual missing requirements');

select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.publish_proposal_idea('fa020000-0000-4000-8000-000000000003',current_setting('test.idea')::uuid)$$,'42501',null,'outsider cannot publish owner draft');
select throws_ok($$select public.promote_proposal_idea('fa020000-0000-4000-8000-000000000003',current_setting('test.idea')::uuid)$$,'42501',null,'outsider cannot promote');
select throws_ok($$select public.get_proposal_promotion_requirements('fa020000-0000-4000-8000-000000000003',current_setting('test.idea')::uuid)$$,'42501',null,'outsider cannot read manager preview');
select throws_ok($$select public.promote_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'42501',null,'expected identity mismatch denied');
select throws_ok($$select * from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000003',current_setting('test.idea')::uuid)$$,'42501',null,'nullable fields grant no protected access');

select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000002',true);
select set_config('test.request',public.request_to_join_project('fa020000-0000-4000-8000-000000000002',current_setting('test.idea')::uuid,null)::text,true);
select is((select count(*) from public.list_own_pending_requested_proposals('fa020000-0000-4000-8000-000000000002')),0::bigint,'old requested-first reader remains strict');
select is((select count(*) from public.list_own_pending_requested_proposals_v2('fa020000-0000-4000-8000-000000000002')),1::bigint,'new requested-first reader retains Idea request');
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.accept_project_join_request('fa020000-0000-4000-8000-000000000001',current_setting('test.request')::uuid)$$,'normal admission with undecided capacity');
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.get_own_project_group_chat('fa020000-0000-4000-8000-000000000002',current_setting('test.idea')::uuid)),1::bigint,'Idea admission creates canonical chat');
select is((select count(*) from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000002',current_setting('test.idea')::uuid) where exact_meeting_text is null),1::bigint,'admitted participant can read successful null meeting row');

select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,jsonb_build_object('starts_at',statement_timestamp()-interval '5 days','ends_at',statement_timestamp()-interval '4 days'))$$,'past tentative dates do not freeze public Idea edits');
select is((select derived_status from public.get_public_proposal_v2(current_setting('test.idea')::uuid)),null::text,'past tentative Idea never derives Completed');
select is((select count(*) from public.list_public_proposals_v2(p_definition_phase=>'idea') where proposal_id=current_setting('test.idea')::uuid),1::bigint,'past tentative Idea remains in public Idea List');
reset role;
select ok(private.project_allows_delegate_collaboration(current_setting('test.idea')::uuid),'past tentative Idea retains delegate collaboration');
select ok(private.project_has_live_coverage_lifecycle(current_setting('test.idea')::uuid),'past tentative Idea retains live coverage');
select ok(private.project_accepts_participant_invitations(current_setting('test.idea')::uuid),'past tentative Idea retains manager-link eligibility');
select ok(private.is_project_cover_editable(current_setting('test.idea')::uuid,'fa020000-0000-4000-8000-000000000001'),'past tentative Idea retains cover editing');
select lives_ok($$select * from private.lock_project_for_resource_need_mutation(current_setting('test.idea')::uuid)$$,'past tentative Idea retains resource need editing');
select lives_ok($$select * from private.lock_project_for_membership_commitment_mutation(current_setting('test.idea')::uuid)$$,'past tentative Idea retains membership commitments');
set local role authenticated;
select lives_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"registration_capacity":1}')$$,'finite cap can be configured using real current usage');
select throws_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"registration_capacity":0}')$$,'22023',null,'invalid finite capacity rejected');
select lives_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"registration_capacity":null}')$$,'explicit undecided capacity allowed only during Idea phase');

reset role;
select is((select count(*) from private.proposal_templates where source_proposal_id=current_setting('test.idea')::uuid),1::bigint,'one template identity at first Idea publication');
select ok(not private.is_proposal_template_publicly_usable((select id from private.proposal_templates where source_proposal_id=current_setting('test.idea')::uuid),statement_timestamp()),'past tentative Idea is never a usable Completed template');
select is((select count(*) from private.audit_events where action='proposal.published' and target_id=current_setting('test.idea')::uuid),1::bigint,'publication retry has one audit');
select is((select count(*) from private.outbox_events where event_type='proposal.published' and payload->>'proposal_id'=current_setting('test.idea')),1::bigint,'publication retry has one outbox event');
select is((select payload->>'actor_id' from private.outbox_events where event_type='proposal.published' and payload->>'proposal_id'=current_setting('test.idea')),'fa020000-0000-4000-8000-000000000001','Idea publication preserves the established actor_id consumer contract');
select throws_ok($$select private.lock_project_for_actual_contribution_mutation(current_setting('test.idea')::uuid)$$,'55000',null,'tentative past Idea cannot gain completion-only writes');
select set_config('test.published_at',(select published_at::text from public.proposals where id=current_setting('test.idea')::uuid),true);
select set_config('test.chat',(select id::text from public.project_group_chats where project_id=current_setting('test.idea')::uuid),true);
select set_config('test.template',(select id::text from private.proposal_templates where source_proposal_id=current_setting('test.idea')::uuid),true);

set local role authenticated;
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,jsonb_build_object('description','A complete planned activity.','starts_at',statement_timestamp()+interval '3 days','ends_at',statement_timestamp()+interval '5 days','event_timezone','Europe/Rome','country_code','IT','locality','Trento','public_location_label','Trento','registration_capacity',3))$$,'Idea retains supplied multi-day planning values');
select is((public.get_proposal_promotion_requirements('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)->>'can_promote')::boolean,true,'complete Idea preview is promotable');
select lives_ok($$select public.promote_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'explicit atomic promotion');
select lives_ok($$select public.promote_proposal_idea('fa020000-0000-4000-8000-000000000001',current_setting('test.idea')::uuid)$$,'promotion retry is idempotent');
select is((select definition_phase from public.get_public_proposal_v2(current_setting('test.idea')::uuid)),'defined','promotion enters Defined');
select is((select count(*) from public.get_public_proposal(current_setting('test.idea')::uuid)),1::bigint,'promoted complete payload becomes compatible with legacy detail');
select is((select ends_at-starts_at from public.get_public_proposal(current_setting('test.idea')::uuid)),interval '2 days','multi-day interval is preserved');
select throws_ok($$select pg_temp.idea_edit(current_setting('test.idea')::uuid,'{"registration_capacity":null}')$$,'22023',null,'Defined cannot clear finite capacity');
reset role;
select is((select published_at from public.proposals where id=current_setting('test.idea')::uuid),current_setting('test.published_at')::timestamptz,'promotion preserves original published timestamp');
select is((select id::text from private.proposal_templates where source_proposal_id=current_setting('test.idea')::uuid),current_setting('test.template'),'promotion preserves template identity');
select is((select id::text from public.project_group_chats where project_id=current_setting('test.idea')::uuid),current_setting('test.chat'),'promotion preserves chat identity');
select is((select count(*) from public.project_memberships where project_id=current_setting('test.idea')::uuid and left_at is null and removed_at is null),1::bigint,'promotion preserves current membership');
select is((select count(*) from private.audit_events where action='proposal.promoted' and target_id=current_setting('test.idea')::uuid),1::bigint,'promotion retry has one audit');
select throws_ok($$update public.proposals set definition_phase='idea' where id=current_setting('test.idea')::uuid$$,'55000',null,'reverse phase transition forbidden even to direct trusted writer');
set local role anon;
select is((select count(*) from public.list_public_proposals_v2(p_definition_phase=>'idea') where proposal_id=current_setting('test.idea')::uuid),0::bigint,'promoted Project leaves Idea-only filter');
select is((select count(*) from public.list_public_proposals_v2(p_definition_phase=>'defined') where proposal_id=current_setting('test.idea')::uuid),1::bigint,'Defined filter includes promotion');
select throws_ok($$select * from public.list_public_proposals_v2(p_definition_phase=>'unknown')$$,'22023',null,'unknown phase rejected');
select throws_ok($$select * from public.list_public_proposals_v2(p_limit=>51)$$,'22023',null,'page bound retained');
select throws_ok($$select * from public.list_public_proposals_v2(p_cursor_id=>'fa020000-0000-4000-8000-000000000001')$$,'22023',null,'half cursor rejected');
select throws_ok($$select * from public.list_public_proposals_v2(p_reference_time=>'infinity')$$,'22023',null,'nonfinite snapshot reference rejected');
select throws_ok($$select public.publish_proposal_idea(null,null)$$,'42501',null,'anonymous publication denied');
select throws_ok($$select * from public.proposal_meeting_details$$,'42501',null,'private meeting storage remains protected');
select * from finish();
rollback;
