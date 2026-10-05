begin;
select no_plan();
-- Explicit integration reruns may have earlier verifier events in this stack.
-- Drain through the same worker, never by fabricating/deleting receipts.
do $$
declare batch integer; processed integer;
begin
  for batch in 1..20 loop
    select processed_count into processed from public.process_push_outbox_batch(100);
    exit when processed = 0;
  end loop;
end;
$$;

-- Setup only. Authority, request, membership and departure transitions use APIs.
insert into auth.users (id, email) values
  ('fb050000-0000-4000-8000-000000000001', 'pi05-notification-owner@planets.invalid'),
  ('fb050000-0000-4000-8000-000000000002', 'pi05-notification-manager@planets.invalid'),
  ('fb050000-0000-4000-8000-000000000003', 'pi05-notification-approved@planets.invalid'),
  ('fb050000-0000-4000-8000-000000000004', 'pi05-notification-rejected@planets.invalid');
insert into public.profiles (id, display_name)
select id, 'Synthetic notification actor' from auth.users where email like 'pi05-notification-%@planets.invalid';
insert into public.profile_photos (profile_id, object_path, audience)
select id, id::text || '/fb050000-0000-4000-8000-000000000010.webp', 'interactions'
from public.profiles where id in ('fb050000-0000-4000-8000-000000000001', 'fb050000-0000-4000-8000-000000000002', 'fb050000-0000-4000-8000-000000000003', 'fb050000-0000-4000-8000-000000000004');
insert into public.proposals (id, creator_profile_id, lifecycle_state, title, starts_at, ends_at, published_at)
values ('fb050000-0000-4000-8000-000000000011', 'fb050000-0000-4000-8000-000000000001', 'published', 'PI05 notification Proposal', now()+interval '1 day', now()+interval '2 days', now());
insert into public.recurring_activities (id, creator_profile_id, lifecycle_state, title, published_at)
values ('fb050000-0000-4000-8000-000000000012', 'fb050000-0000-4000-8000-000000000001', 'published', 'PI05 notification Tavolo', now());
create temporary table pi05_actor_cases (project_id uuid, token text, delegate_id uuid, accepted_request uuid, rejected_request uuid, membership_id uuid);
insert into pi05_actor_cases (project_id) values ('fb050000-0000-4000-8000-000000000011'), ('fb050000-0000-4000-8000-000000000012');
grant select, update on pi05_actor_cases to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000001', true);
update pi05_actor_cases fixture set token = (select invite_token from public.create_project_delegate_invitation('fb050000-0000-4000-8000-000000000001', fixture.project_id));
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000002', true);
update pi05_actor_cases set delegate_id = public.accept_project_delegate_invitation('fb050000-0000-4000-8000-000000000002', token);
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000003', true);
select public.set_own_notification_preference('fb050000-0000-4000-8000-000000000003', 'participation', true, true);
update pi05_actor_cases set accepted_request = public.request_to_join_project('fb050000-0000-4000-8000-000000000003', project_id, null);
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000004', true);
select public.set_own_notification_preference('fb050000-0000-4000-8000-000000000004', 'participation', true, true);
update pi05_actor_cases set rejected_request = public.request_to_join_project('fb050000-0000-4000-8000-000000000004', project_id, null);
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000002', true);
update pi05_actor_cases set membership_id = public.accept_project_join_request_as_manager('fb050000-0000-4000-8000-000000000002', accepted_request);
select public.reject_project_join_request_as_manager('fb050000-0000-4000-8000-000000000002', rejected_request) from pi05_actor_cases;
select public.remove_project_member_as_manager('fb050000-0000-4000-8000-000000000002', membership_id) from pi05_actor_cases;
select set_config('request.jwt.claim.sub', 'fb050000-0000-4000-8000-000000000001', true);
select public.revoke_project_delegate('fb050000-0000-4000-8000-000000000001', delegate_id) from pi05_actor_cases;
reset role;
select is((select count(*) from private.outbox_events event cross join lateral private.resolve_participation_notification_event(event.id) resolved
  where event.payload->>'project_id' in (select project_id::text from pi05_actor_cases)
  and event.event_type in ('project.join_request_accepted','project.join_request_rejected','project.participant_removed')
  and resolved.actor_profile_id = 'fb050000-0000-4000-8000-000000000002'), 6::bigint,
  'both kinds retain the real decision/removal actor after authority revocation');
select lives_ok($$select * from public.process_notification_outbox_batch(100)$$, 'delegate decisions do not poison the in-app projector');
select is((select count(*) from public.notifications where project_id in (select project_id from pi05_actor_cases)
  and notification_kind in ('participation_request_accepted','participation_request_rejected','participant_removed')
  and actor_profile_id='fb050000-0000-4000-8000-000000000002'), 6::bigint, 'projected in-app attribution is the historical manager');
select lives_ok($$select * from public.process_push_outbox_batch(100)$$, 'the shared actor correction also permits push projection');
select is((select count(*) from private.push_delivery_jobs where project_id in (select project_id from pi05_actor_cases)
  and notification_kind in ('participation_request_accepted','participation_request_rejected','participant_removed')
  and actor_profile_id='fb050000-0000-4000-8000-000000000002'), 6::bigint, 'push retains the same canonical manager attribution');
select lives_ok($$select * from public.process_notification_outbox_batch(100)$$, 'repeated projection remains idempotent');
select is((select count(*) from public.notifications where project_id in (select project_id from pi05_actor_cases)
  and notification_kind in ('participation_request_accepted','participation_request_rejected','participant_removed')), 6::bigint, 'no duplicate decision notifications');
insert into private.outbox_events (id, event_type, payload)
select 'fb050000-0000-4000-8000-000000000020', event_type, payload || jsonb_build_object('actor_profile_id','fb050000-0000-4000-8000-000000000001')
from private.outbox_events where event_type='project.join_request_rejected' and payload->>'project_id'='fb050000-0000-4000-8000-000000000011';
select throws_ok($$select * from private.resolve_participation_notification_event('fb050000-0000-4000-8000-000000000020')$$, '55000', null, 'forged Creator attribution fails canonical manager validation');
select ok(not has_function_privilege('authenticated', 'private.resolve_participation_notification_event(uuid)', 'execute'), 'the resolver stays outside client grants');
select * from finish();
rollback;
