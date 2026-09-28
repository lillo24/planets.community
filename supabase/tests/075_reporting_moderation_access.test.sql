begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a9000000-0000-4000-8000-000000000001', 'reporter@planets.invalid'),
  ('a9000000-0000-4000-8000-000000000002', 'subject@planets.invalid'),
  ('a9000000-0000-4000-8000-000000000003', 'ordinary@planets.invalid'),
  ('a9000000-0000-4000-8000-000000000004', 'moderator@planets.invalid'),
  ('a9000000-0000-4000-8000-000000000005', 'admin@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a9000000-0000-4000-8000-000000000001', 'Reporter Profile'),
  ('a9000000-0000-4000-8000-000000000002', 'Subject Profile'),
  ('a9000000-0000-4000-8000-000000000003', 'Ordinary Profile'),
  ('a9000000-0000-4000-8000-000000000004', 'Moderator Profile'),
  ('a9000000-0000-4000-8000-000000000005', 'Admin Profile');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at
)
values (
  'a9010000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000002',
  'published',
  'Moderation project',
  statement_timestamp() + interval '1 hour',
  statement_timestamp() + interval '2 hours',
  statement_timestamp()
);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values (
  'a9020000-0000-4000-8000-000000000001',
  'a9010000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000001',
  'accepted',
  statement_timestamp() - interval '2 minutes',
  statement_timestamp() - interval '1 minute',
  'a9000000-0000-4000-8000-000000000002'
);

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'a9030000-0000-4000-8000-000000000001',
  'a9010000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000001',
  'a9020000-0000-4000-8000-000000000001',
  statement_timestamp() - interval '1 minute'
);

insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
select
  'a9040000-0000-4000-8000-000000000001',
  chat.id,
  'a9000000-0000-4000-8000-000000000002',
  'Private Project message evidence.',
  statement_timestamp()
from public.project_group_chats as chat
where chat.project_id = 'a9010000-0000-4000-8000-000000000001';

insert into public.resource_listings (
  id,
  owner_profile_id,
  listing_mode,
  lifecycle_state,
  title,
  description,
  country_code,
  locality,
  public_location_label,
  published_at
)
values (
  'a9050000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000002',
  'exchange',
  'published',
  'Moderation resource listing',
  'A listing used to prove counterparty-derived moderation context.',
  'IT',
  'Trento',
  'Trento',
  statement_timestamp()
);

insert into public.resource_listing_requests (
  id,
  listing_id,
  requester_profile_id,
  status,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values (
  'a9060000-0000-4000-8000-000000000001',
  'a9050000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000001',
  'accepted',
  statement_timestamp() - interval '2 minutes',
  statement_timestamp() - interval '1 minute',
  'a9000000-0000-4000-8000-000000000002'
);

insert into public.resource_request_chats (
  id,
  request_id,
  activated_at
)
values (
  'a9070000-0000-4000-8000-000000000001',
  'a9060000-0000-4000-8000-000000000001',
  statement_timestamp() - interval '1 minute'
);

insert into public.resource_request_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body
)
values (
  'a9080000-0000-4000-8000-000000000001',
  'a9070000-0000-4000-8000-000000000001',
  'a9000000-0000-4000-8000-000000000002',
  'Private Resource message evidence.'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000001',
      'harassment_abuse',
      'A sufficiently detailed report explanation.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  '42501',
  null,
  'anonymous callers cannot submit a report'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000002',
      'other',
      '   ',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  '22023',
  'The report explanation must contain between 10 and 4,000 characters.',
  'blank explanations are rejected canonically'
);
select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000003',
      'other',
      repeat('x', 4001),
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  '22023',
  'The report explanation must contain between 10 and 4,000 characters.',
  'oversized explanations are rejected canonically'
);

select set_config(
  'test.project_report_id',
  (
    select report.report_id::text
    from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000010',
      'harassment_abuse',
      'The Project message crossed a clear boundary.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    ) as report
  ),
  true
);

select is(
  (
    select report.report_id::text
    from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000010',
      'harassment_abuse',
      'The Project message crossed a clear boundary.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    ) as report
  ),
  current_setting('test.project_report_id'),
  'an accidental retry returns the original report identity'
);

select lives_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000011',
      'other',
      'A later separate incident remains independently reportable.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  'the same target may be reported later with a fresh incident key'
);

select lives_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000012',
      'fraud_scam',
      'This Resource exchange message requires manual review.',
      'resource_chat_message',
      'a9080000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  'a canonical Resource counterparty can report an accessible chat message'
);

select lives_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000013',
      'safety_concern',
      'This concerns our shared Project association.',
      'profile',
      'a9000000-0000-4000-8000-000000000002',
      'project',
      'a9010000-0000-4000-8000-000000000001'
    )
  $$,
  'a historical Project association supports a group-context profile report'
);

select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000014',
      'other',
      'A self-report should never create a case.',
      'profile',
      'a9000000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  '22023',
  'A profile cannot report itself.',
  'self-reporting is rejected'
);

select is(
  (
    select count(*)
    from public.list_own_moderation_reports(
      'a9000000-0000-4000-8000-000000000001',
      20,
      null,
      null
    )
  ),
  4::bigint,
  'the reporter reads only their four distinct reports'
);

select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000003',
      'a9100000-0000-4000-8000-000000000020',
      'other',
      'This caller cannot read the private Project message.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000001',
      null,
      null
    )
  $$,
  '42501',
  'The report target is unavailable.',
  'an unauthorized private-message target fails closed'
);
select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'a9000000-0000-4000-8000-000000000003',
      'a9100000-0000-4000-8000-000000000021',
      'other',
      'This missing private message is equally unavailable.',
      'project_chat_message',
      'a9040000-0000-4000-8000-000000000099',
      null,
      null
    )
  $$,
  '42501',
  'The report target is unavailable.',
  'a missing private-message target has the same failure shape'
);
select is(
  (
    select count(*)
    from public.list_own_moderation_reports(
      'a9000000-0000-4000-8000-000000000003',
      20,
      null,
      null
    )
  ),
  0::bigint,
  'an ordinary user cannot read another reporter records'
);
select is(
  (
    select count(*)
    from public.get_own_moderation_staff_access(
      'a9000000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'ordinary authentication does not imply staff authorization'
);
select throws_ok(
  $$
    select * from public.list_moderation_cases(
      'a9000000-0000-4000-8000-000000000003',
      null,
      25,
      null,
      null
    )
  $$,
  '42501',
  'Moderation staff access is required.',
  'an ordinary user cannot read the staff queue'
);

reset role;
select set_config(
  'test.project_case_id',
  (
    select report.case_id::text
    from private.moderation_reports as report
    where report.id = current_setting('test.project_report_id')::uuid
  ),
  true
);
insert into private.moderation_staff_roles (profile_id, staff_role)
values
  ('a9000000-0000-4000-8000-000000000004', 'moderator'),
  ('a9000000-0000-4000-8000-000000000005', 'admin');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000004',
  true
);
select results_eq(
  $$
    select staff_role
    from public.get_own_moderation_staff_access(
      'a9000000-0000-4000-8000-000000000004'
    )
  $$,
  $$values ('moderator'::text)$$,
  'an active moderator receives canonical staff authorization'
);
select is(
  (
    select count(*)
    from public.list_moderation_cases(
      'a9000000-0000-4000-8000-000000000004',
      'received',
      25,
      null,
      null
    )
  ),
  4::bigint,
  'the moderator queue returns the received cases'
);
select is(
  (
    select detail.explanation
    from public.get_moderation_case_detail(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid
    ) as detail
  ),
  'The Project message crossed a clear boundary.',
  'staff detail includes the original evidence through the narrow boundary'
);

select lives_ok(
  $$
    select * from public.add_moderation_case_note(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      'Private staff-only note text.'
    )
  $$,
  'a moderator can append one private internal note'
);

select results_eq(
  $$
    select transition.state, transition.state_version
    from public.transition_moderation_case(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      0,
      'under_review'
    ) as transition
  $$,
  $$values ('under_review'::text, 1::bigint)$$,
  'a moderator starts review with a versioned transition'
);
select results_eq(
  $$
    select transition.state, transition.state_version
    from public.transition_moderation_case(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      0,
      'under_review'
    ) as transition
  $$,
  $$values ('under_review'::text, 1::bigint)$$,
  'repeating an achieved transition is idempotent'
);
select results_eq(
  $$
    select transition.state, transition.state_version
    from public.transition_moderation_case(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      1,
      'completed'
    ) as transition
  $$,
  $$values ('completed'::text, 2::bigint)$$,
  'a moderator completes review without any enforcement mutation'
);
select throws_ok(
  $$
    select * from public.transition_moderation_case(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      1,
      'under_review'
    )
  $$,
  'PT409',
  'The moderation case changed before this action completed.',
  'a stale concurrent reviewer cannot overwrite canonical state'
);
select results_eq(
  $$
    select transition.state, transition.state_version
    from public.transition_moderation_case(
      'a9000000-0000-4000-8000-000000000004',
      current_setting('test.project_case_id')::uuid,
      2,
      'under_review'
    ) as transition
  $$,
  $$values ('under_review'::text, 3::bigint)$$,
  'reopening a completed review is explicit and audited'
);

reset role;
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action like 'moderation.%'
      and (
        event.metadata::text like '%Project message crossed%'
        or event.metadata::text like '%staff-only note text%'
      )
  ),
  0::bigint,
  'report and note bodies never enter generic audit metadata'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type like 'moderation.%'
  ),
  0::bigint,
  '09A1 emits no moderation evidence or enforcement outbox event'
);
select is(
  (
    select moderation_case.subject_profile_id
    from private.moderation_cases as moderation_case
    join private.moderation_reports as report
      on report.case_id = moderation_case.id
    where report.category = 'fraud_scam'
  ),
  'a9000000-0000-4000-8000-000000000002'::uuid,
  'the Resource message subject is derived from its canonical sender'
);
select ok(
  exists (
    select 1
    from private.moderation_cases as moderation_case
    where moderation_case.target_kind = 'resource_chat_message'
      and moderation_case.resource_listing_context_id =
        'a9050000-0000-4000-8000-000000000001'
      and moderation_case.resource_request_context_id =
        'a9060000-0000-4000-8000-000000000001'
      and moderation_case.resource_chat_context_id =
        'a9070000-0000-4000-8000-000000000001'
  ),
  'Scambio-Dona evidence retains listing, request, and chat episode context'
);
select ok(
  exists (
    select 1
    from private.moderation_cases as moderation_case
    where moderation_case.target_kind = 'profile'
      and moderation_case.project_context_id =
        'a9010000-0000-4000-8000-000000000001'
  ),
  'group evidence retains the canonical Project context for 09A2'
);

update private.moderation_staff_roles
set
  is_active = false,
  deactivated_at = statement_timestamp()
where profile_id = 'a9000000-0000-4000-8000-000000000004';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select * from public.list_moderation_cases(
      'a9000000-0000-4000-8000-000000000004',
      null,
      25,
      null,
      null
    )
  $$,
  '42501',
  'Moderation staff access is required.',
  'revoking staff status denies the next canonical operation'
);

select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000005',
  true
);
select results_eq(
  $$
    select staff_role
    from public.get_own_moderation_staff_access(
      'a9000000-0000-4000-8000-000000000005'
    )
  $$,
  $$values ('admin'::text)$$,
  'an active admin has the same 09A1 review authorization'
);
select is(
  (
    select count(*)
    from public.list_moderation_cases(
      'a9000000-0000-4000-8000-000000000005',
      null,
      25,
      null,
      null
    )
  ),
  4::bigint,
  'an admin can inspect the review queue'
);

select set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_moderation_reports(
      'a9000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
  ),
  0::bigint,
  'the reported person cannot discover reports or case status'
);

select * from finish();

rollback;
