-- Synthetic transaction-only regression, NOT real OTP/Auth evidence and NOT an
-- account-deletion workflow. No FKs/triggers/audit rows are disabled or removed.
-- Real own/staff RPCs read known content before scoped fixture erasure and report
-- the exact retained content afterward; legacy/template shapes stay restricted.
begin;
select no_plan();
create function pg_temp.fixture_id(n integer) returns uuid language sql immutable as $$
  select ('d1450000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.fixture_time() returns timestamptz language sql immutable as $$
  select '2026-10-14 10:00:00+00'::timestamptz;
$$;
insert into auth.users(id, email)
select pg_temp.fixture_id(n), 'contact-erasure-' || n || '@planets.invalid' from generate_series(1, 4) n;
insert into public.profiles(id, display_name)
select pg_temp.fixture_id(n), 'Synthetic erasure person ' || n from generate_series(1, 4) n;
insert into private.moderation_staff_roles(profile_id, staff_role) values (pg_temp.fixture_id(4), 'moderator');
insert into private.community_groups(id, name, description, group_kind, volunteering_focus, publication_state, original_actor_id)
select pg_temp.fixture_id(200 + n), 'Erasure Group ' || n, 'Synthetic transaction-only contact origin.',
  'informal', false, 'published', pg_temp.fixture_id(case n when 1 then 2 when 2 then 1 else 4 end)
from generate_series(1, 5) n;
insert into private.community_group_managers(group_id, profile_id, appointed_by_actor_id)
select id, original_actor_id, original_actor_id from private.community_groups
where id between pg_temp.fixture_id(201) and pg_temp.fixture_id(205);
insert into private.group_memberships(id, group_id, profile_id, admitted_by, joined_at)
select pg_temp.fixture_id(700 + g * 10 + actor), pg_temp.fixture_id(200 + g),
  pg_temp.fixture_id(actor), pg_temp.fixture_id(4), pg_temp.fixture_time()
from generate_series(4, 5) g cross join generate_series(1, 2) actor;

insert into private.member_contact_pairs(id, group_id, low_profile_id, high_profile_id, created_at, last_ordinal)
values (pg_temp.fixture_id(501), pg_temp.fixture_id(204), pg_temp.fixture_id(1), pg_temp.fixture_id(2), pg_temp.fixture_time(), 1),
  (pg_temp.fixture_id(506), pg_temp.fixture_id(205), pg_temp.fixture_id(1), pg_temp.fixture_id(2), pg_temp.fixture_time(), 0);
insert into private.member_contact_requests(
  id, pair_id, sender_profile_id, recipient_profile_id, group_name, sender_display_name,
  recipient_display_name, note, status, created_at, activity_at, expires_at, resolved_at, resolved_by
)
values (pg_temp.fixture_id(101), pg_temp.fixture_id(501), pg_temp.fixture_id(2), pg_temp.fixture_id(1),
  'Erasure Group 4', 'Synthetic erasure person 2', 'Synthetic erasure person 1',
  'Known personal note before erasure.', 'accepted', pg_temp.fixture_time(), pg_temp.fixture_time(),
  clock_timestamp() + interval '7 days', pg_temp.fixture_time(), pg_temp.fixture_id(1)),
  (pg_temp.fixture_id(104), pg_temp.fixture_id(506), pg_temp.fixture_id(2), pg_temp.fixture_id(1),
  'Erasure Group 5', 'Synthetic erasure person 2', 'Synthetic erasure person 1',
  'Unseen personal note must stay unavailable.', 'pending', pg_temp.fixture_time(), pg_temp.fixture_time(),
  clock_timestamp() + interval '7 days', null, null);
insert into private.member_contact_episodes(id, pair_id, request_id, accepted_at, first_ordinal)
values (pg_temp.fixture_id(401), pg_temp.fixture_id(501), pg_temp.fixture_id(101), pg_temp.fixture_time(), 1);
insert into private.member_contact_messages(id, pair_id, episode_id, sender_profile_id, sender_display_name, body, ordinal, created_at)
values (pg_temp.fixture_id(302), pg_temp.fixture_id(501), pg_temp.fixture_id(401), pg_temp.fixture_id(2),
  'Synthetic erasure person 2', 'Known personal message before erasure.', 1, pg_temp.fixture_time() + interval '1 minute');

insert into private.group_contact_requests(
  id, source_group_id, target_group_id, submitter_id, purpose, title, note, status,
  created_at, expires_at, resolved_at, resolved_by
)
values (pg_temp.fixture_id(102), pg_temp.fixture_id(201), pg_temp.fixture_id(202), pg_temp.fixture_id(2),
  'collaboration', 'Known invitation', 'Known representative note before erasure.', 'pending',
  pg_temp.fixture_time(), clock_timestamp() + interval '7 days', null, null),
  (pg_temp.fixture_id(105), pg_temp.fixture_id(201), pg_temp.fixture_id(202), pg_temp.fixture_id(2),
  'collaboration', 'Conversation source', 'Accepted source for historical messages.', 'accepted',
  pg_temp.fixture_time(), clock_timestamp() + interval '7 days', pg_temp.fixture_time(), pg_temp.fixture_id(1));
insert into private.group_contact_conversations(id, request_id, title, summary, created_at, last_ordinal)
values (pg_temp.fixture_id(502), pg_temp.fixture_id(105), 'Historical representative room',
  'Synthetic message evidence context.', pg_temp.fixture_time(), 1);
insert into private.group_contact_admissions(id, conversation_id, profile_id, group_id, admitted_at)
values (pg_temp.fixture_id(601), pg_temp.fixture_id(502), pg_temp.fixture_id(1), pg_temp.fixture_id(202), pg_temp.fixture_time()),
  (pg_temp.fixture_id(602), pg_temp.fixture_id(502), pg_temp.fixture_id(2), pg_temp.fixture_id(201), pg_temp.fixture_time());
insert into private.group_contact_messages(
  id, conversation_id, admission_id, sender_profile_id, represented_group_id, group_name_at_send, body, ordinal, created_at
)
values (pg_temp.fixture_id(301), pg_temp.fixture_id(502), pg_temp.fixture_id(602), pg_temp.fixture_id(2),
  pg_temp.fixture_id(201), 'Erasure Group 1', 'Known representative message before erasure.', 1,
  pg_temp.fixture_time() + interval '1 minute');
insert into private.group_coordination_proposals(id, source_chat_id, initiator_id, title, note, created_at, activity_at, expires_at)
values (pg_temp.fixture_id(103), pg_temp.fixture_id(502), pg_temp.fixture_id(2), 'Known coordination',
  'Known coordination note before erasure.', pg_temp.fixture_time(), pg_temp.fixture_time(), clock_timestamp() + interval '7 days');
insert into private.group_coordination_seats(id, proposal_id, group_id, source_admission_id, profile_id, claimed_at)
values (pg_temp.fixture_id(801), pg_temp.fixture_id(103), pg_temp.fixture_id(202), pg_temp.fixture_id(601), pg_temp.fixture_id(1), pg_temp.fixture_time()),
  (pg_temp.fixture_id(802), pg_temp.fixture_id(103), pg_temp.fixture_id(201), pg_temp.fixture_id(602), pg_temp.fixture_id(2), pg_temp.fixture_time()),
  (pg_temp.fixture_id(803), pg_temp.fixture_id(103), pg_temp.fixture_id(203), null, null, null);

create temporary table expected_evidence(kind text primary key, target_id uuid, body text, context_kind text, context_id uuid);
insert into expected_evidence values
  ('member_contact_request', pg_temp.fixture_id(101), 'Known personal note before erasure.', null, null),
  ('member_contact_message', pg_temp.fixture_id(302), 'Known personal message before erasure.', 'member_contact_chat', pg_temp.fixture_id(501)),
  ('group_contact_request', pg_temp.fixture_id(102), 'Known representative note before erasure.', null, null),
  ('group_contact_message', pg_temp.fixture_id(301), 'Known representative message before erasure.', null, null),
  ('group_coordination_proposal', pg_temp.fixture_id(103), 'Known coordination note before erasure.', null, null);
create temporary table report_results(kind text primary key, report_id uuid, case_id uuid);
create temporary table official_label_control(target_id uuid primary key, case_id uuid);
insert into official_label_control(target_id)
select id from private.proposal_templates where starter_key = 'repair';
grant select on expected_evidence to authenticated;
grant all on report_results, official_label_control to authenticated;
grant execute on function pg_temp.fixture_id(integer), pg_temp.fixture_time() to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(1)::text, true);
select is(public.get_own_member_contact_request(pg_temp.fixture_id(1), pg_temp.fixture_id(101)) ->> 'request_message',
  'Known personal note before erasure.', 'recipient deliberately reads the personal note before erasure');
select is(public.get_own_member_contact_feed(pg_temp.fixture_id(1), pg_temp.fixture_id(501)) -> 'items' -> 0 ->> 'body',
  'Known personal message before erasure.', 'recipient reads authorized personal history before erasure');
select is(public.get_own_group_contact_request(pg_temp.fixture_id(1), pg_temp.fixture_id(102)) ->> 'request_message',
  'Known representative note before erasure.', 'recipient deliberately reads the representative note before erasure');
select is(public.get_own_group_contact_feed(pg_temp.fixture_id(1), pg_temp.fixture_id(502)) -> 'items' -> 0 ->> 'body',
  'Known representative message before erasure.', 'admitted representative reads the historical message before erasure');
select is(public.get_own_group_coordination_proposal(pg_temp.fixture_id(1), pg_temp.fixture_id(103)) ->> 'request_message',
  'Known coordination note before erasure.', 'named seat deliberately reads the coordination invitation before erasure');
reset role;

-- Erase only this dedicated synthetic identity, after checking its exact email.
select is((select email from auth.users where id = pg_temp.fixture_id(2)), 'contact-erasure-2@planets.invalid'::text,
  'the erasure target is this transaction synthetic fixture');
delete from public.profiles where id = pg_temp.fixture_id(2)
  and exists(select 1 from auth.users where id = pg_temp.fixture_id(2) and email = 'contact-erasure-2@planets.invalid');
delete from auth.users where id = pg_temp.fixture_id(2) and email = 'contact-erasure-2@planets.invalid';
select ok(not exists(select 1 from public.profiles where id = pg_temp.fixture_id(2))
  and not exists(select 1 from auth.users where id = pg_temp.fixture_id(2)), 'scoped synthetic subject is erased');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(1)::text, true);
select is(public.get_own_member_contact_conversation(pg_temp.fixture_id(1), pg_temp.fixture_id(501)) ->> 'is_read_only',
  'true', 'report eligibility does not revive personal sending after erasure');
insert into report_results
select e.kind, report.report_id, report.case_id from expected_evidence e
cross join lateral public.submit_moderation_report(pg_temp.fixture_id(1), e.target_id, 'spam',
  'Synthetic known evidence after scoped erasure.', e.kind, e.target_id, e.context_kind, e.context_id) report;
select is((select count(*) from report_results), 5::bigint, 'all five exact contact kinds report successfully after erasure');
update official_label_control control set case_id = (
  select report.case_id from public.submit_moderation_report(pg_temp.fixture_id(1), pg_temp.fixture_id(920),
    'other', 'Synthetic official-template label regression.', 'proposal_template', control.target_id) report
);
select throws_ok($$select public.submit_moderation_report(pg_temp.fixture_id(1), pg_temp.fixture_id(910), 'spam',
  'Synthetic unseen content remains unavailable.', 'member_contact_request', pg_temp.fixture_id(104))$$,
  '42501', null, 'null-subject support does not authorize an unseen personal note');
select throws_ok($$select public.submit_moderation_report(pg_temp.fixture_id(1), pg_temp.fixture_id(911), 'spam',
  'Synthetic wrong context remains unavailable.', 'member_contact_message', pg_temp.fixture_id(302),
  'member_contact_chat', pg_temp.fixture_id(506))$$,
  '42501', null, 'null-subject support does not authorize a mismatched message context');
select throws_ok($$select public.get_moderation_case_group_contact(pg_temp.fixture_id(1),
  (select case_id from report_results where kind = 'member_contact_message'))$$,
  '42501', null, 'reporting does not give an ordinary reporter staff evidence access');
select throws_ok($$select public.list_moderation_cases(pg_temp.fixture_id(1))$$,
  '42501', null, 'subject-label correction does not grant ordinary access to the staff queue');
select throws_ok($$select public.get_moderation_case_detail(pg_temp.fixture_id(1),
  (select case_id from report_results where kind = 'member_contact_message'))$$,
  '42501', null, 'subject-label correction does not grant ordinary access to staff detail');
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(3)::text, true);
select throws_ok($$select public.submit_moderation_report(pg_temp.fixture_id(3), pg_temp.fixture_id(912), 'spam',
  'Synthetic outsider report remains unavailable.', 'group_contact_message', pg_temp.fixture_id(301))$$,
  '42501', null, 'erasure does not give an outsider historical representative evidence');
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(4)::text, true);
select is(queue.subject_display_name, 'Deleted account', r.kind || ' staff queue does not attribute erased content to the organization')
from report_results r left join public.list_moderation_cases(pg_temp.fixture_id(4), null, 50) queue
  on queue.case_id = r.case_id order by r.kind;
select is((select detail.subject_display_name from public.get_moderation_case_detail(pg_temp.fixture_id(4), r.case_id) detail),
  'Deleted account', r.kind || ' staff detail identifies an erased subject without an invented account')
from report_results r order by r.kind;
select is((select queue.subject_display_name from public.list_moderation_cases(pg_temp.fixture_id(4), null, 50) queue
  where queue.case_id = (select case_id from official_label_control)), 'Planets Community Official',
  'actual official-template report retains its organization label in the staff queue');
select is((select detail.subject_display_name from public.get_moderation_case_detail(pg_temp.fixture_id(4),
  (select case_id from official_label_control)) detail), 'Planets Community Official',
  'actual official-template report retains its organization label in staff detail');
select is(public.get_moderation_case_group_contact(pg_temp.fixture_id(4), r.case_id) ->> 'body', e.body,
  e.kind || ' staff evidence preserves exactly the known body')
from report_results r join expected_evidence e using(kind) order by e.kind;
select is(public.get_moderation_case_group_contact(pg_temp.fixture_id(4), r.case_id) ->> 'target_id', e.target_id::text,
  e.kind || ' staff evidence preserves the exact typed target')
from report_results r join expected_evidence e using(kind) order by e.kind;
select is(public.get_moderation_case_group_contact(pg_temp.fixture_id(4), case_id) ->> 'human_id', pg_temp.fixture_id(2)::text,
  kind || ' evidence retains immutable author provenance without a live account')
from report_results order by kind;
reset role;
select ok(c.subject_profile_id is null and c.template_source_proposal_id is null and c.template_report_content_version is null,
  r.kind || ' case has a null live subject and no invented template provenance')
from report_results r join private.moderation_cases c on c.id = r.case_id order by r.kind;
select is((select confdeltype::text from pg_constraint where conrelid = 'private.moderation_cases'::regclass
  and conname = 'moderation_cases_subject_profile_id_fkey'), 'r', 'existing moderation subject FK still restricts erasure');

-- Trusted direct inserts test the unchanged legacy/template CHECK branches.
-- An official template has no source/human; a community template requires both.
insert into public.proposals(id, creator_profile_id, lifecycle_state, title)
values (pg_temp.fixture_id(901), pg_temp.fixture_id(1), 'draft', 'Synthetic template source');
insert into private.proposal_templates(id, source_proposal_id, original_creator_profile_id, linked_at)
values (pg_temp.fixture_id(902), pg_temp.fixture_id(901), pg_temp.fixture_id(1), pg_temp.fixture_time());
select lives_ok($$insert into private.moderation_cases(subject_profile_id, target_kind, target_profile_id)
  values(pg_temp.fixture_id(3), 'profile', pg_temp.fixture_id(3))$$, 'legacy profile case still accepts a live subject');
select throws_ok($$insert into private.moderation_cases(target_kind, target_profile_id)
  values('profile', pg_temp.fixture_id(3))$$, '23514', null, 'legacy non-template case still rejects a null subject');
select lives_ok($$insert into private.moderation_cases(target_kind, target_proposal_template_id, template_report_content_version)
  select 'proposal_template', id, 'tw01:' || repeat('a', 64) from private.proposal_templates where starter_key = 'repair'$$,
  'official template still accepts organization provenance without a live subject');
select lives_ok($$insert into private.moderation_cases(subject_profile_id, target_kind, target_proposal_template_id,
  template_source_proposal_id, template_report_content_version)
  values(pg_temp.fixture_id(1), 'proposal_template', pg_temp.fixture_id(902), pg_temp.fixture_id(901), 'tw01:' || repeat('a', 64))$$,
  'community template still accepts matched source and live-human provenance');
select throws_ok($$insert into private.moderation_cases(subject_profile_id, target_kind, target_proposal_template_id, template_report_content_version)
  select pg_temp.fixture_id(1), 'proposal_template', id, 'tw01:' || repeat('a', 64) from private.proposal_templates where starter_key = 'repair'$$,
  '23514', null, 'official template cannot acquire an invented human subject');
select throws_ok($$insert into private.moderation_cases(target_kind, target_proposal_template_id, template_source_proposal_id, template_report_content_version)
  values('proposal_template', pg_temp.fixture_id(902), pg_temp.fixture_id(901), 'tw01:' || repeat('a', 64))$$,
  '23514', null, 'community template source cannot lose its live-human provenance');
select throws_ok($$insert into private.moderation_cases(target_kind, target_proposal_template_id, template_report_content_version)
  select 'proposal_template', id, 'invalid-version' from private.proposal_templates where starter_key = 'repair'$$,
  '23514', null, 'template content-version format remains enforced');
select throws_ok($$insert into private.moderation_cases(target_kind, target_proposal_template_id)
  select 'proposal_template', id from private.proposal_templates where starter_key = 'repair'$$,
  '23514', null, 'template content-version remains required');
select throws_ok($$insert into private.moderation_cases(target_kind, target_member_contact_request_id, template_report_content_version)
  values('member_contact_request', pg_temp.fixture_id(101), 'tw01:' || repeat('a', 64))$$,
  '23514', null, 'erased-subject contact case cannot carry template content provenance');
select throws_ok($$insert into private.moderation_cases(target_kind, target_member_contact_request_id, template_source_proposal_id)
  values('member_contact_request', pg_temp.fixture_id(101), pg_temp.fixture_id(901))$$,
  '23514', null, 'erased-subject contact case cannot carry template source provenance');
select throws_ok($$insert into private.moderation_cases(target_kind) values('member_contact_request')$$,
  '23514', null, 'erased-subject case still requires its exact typed target');
select throws_ok($$insert into private.moderation_cases(target_kind, target_member_contact_message_id)
  values('member_contact_message', pg_temp.fixture_id(302))$$,
  '23514', null, 'erased-subject message case still requires its exact context');
select throws_ok($$insert into private.moderation_cases(target_kind, target_member_contact_request_id, target_group_contact_request_id)
  values('member_contact_request', pg_temp.fixture_id(101), pg_temp.fixture_id(102))$$,
  '23514', null, 'erased-subject case still rejects mixed domain targets');
select * from finish();
rollback;
