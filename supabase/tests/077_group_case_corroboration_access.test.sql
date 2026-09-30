begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b9000000-0000-4000-8000-000000000001', 'reporter-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000002', 'subject-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000003', 'creator-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000004', 'invitee-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000005', 'former-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000006', 'later-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000007', 'moderator-09a2a@planets.invalid'),
  ('b9000000-0000-4000-8000-000000000008', 'outsider-09a2a@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b9000000-0000-4000-8000-000000000001', 'Corroboration Reporter'),
  ('b9000000-0000-4000-8000-000000000002', 'Corroboration Subject'),
  ('b9000000-0000-4000-8000-000000000003', 'Project Creator'),
  ('b9000000-0000-4000-8000-000000000004', 'Current Member'),
  ('b9000000-0000-4000-8000-000000000005', 'Former Member'),
  ('b9000000-0000-4000-8000-000000000006', 'Later Member'),
  ('b9000000-0000-4000-8000-000000000007', 'Corroboration Moderator'),
  ('b9000000-0000-4000-8000-000000000008', 'Unrelated Person');

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
  'b9010000-0000-4000-8000-000000000001',
  'b9000000-0000-4000-8000-000000000003',
  'published',
  'Corroboration project',
  statement_timestamp() - interval '1 day',
  statement_timestamp() + interval '30 days',
  statement_timestamp() - interval '2 days'
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
values
  (
    'b9020000-0000-4000-8000-000000000001',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000001',
    'accepted',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '9 days',
    'b9000000-0000-4000-8000-000000000003'
  ),
  (
    'b9020000-0000-4000-8000-000000000002',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000002',
    'accepted',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '9 days',
    'b9000000-0000-4000-8000-000000000003'
  ),
  (
    'b9020000-0000-4000-8000-000000000004',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000004',
    'accepted',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '9 days',
    'b9000000-0000-4000-8000-000000000003'
  ),
  (
    'b9020000-0000-4000-8000-000000000005',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000005',
    'accepted',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '9 days',
    'b9000000-0000-4000-8000-000000000003'
  ),
  (
    'b9020000-0000-4000-8000-000000000006',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000006',
    'accepted',
    statement_timestamp(),
    statement_timestamp(),
    'b9000000-0000-4000-8000-000000000003'
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at
)
values
  (
    'b9030000-0000-4000-8000-000000000001',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000001',
    'b9020000-0000-4000-8000-000000000001',
    statement_timestamp() - interval '9 days',
    null
  ),
  (
    'b9030000-0000-4000-8000-000000000002',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000002',
    'b9020000-0000-4000-8000-000000000002',
    statement_timestamp() - interval '9 days',
    null
  ),
  (
    'b9030000-0000-4000-8000-000000000004',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000004',
    'b9020000-0000-4000-8000-000000000004',
    statement_timestamp() - interval '9 days',
    null
  ),
  (
    'b9030000-0000-4000-8000-000000000005',
    'b9010000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000005',
    'b9020000-0000-4000-8000-000000000005',
    statement_timestamp() - interval '9 days',
    statement_timestamp() - interval '1 day'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.corroboration_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'b9000000-0000-4000-8000-000000000001',
      'b9100000-0000-4000-8000-000000000001',
      'harassment_abuse',
      'The reported conduct occurred during our shared Project activity.',
      'profile',
      'b9000000-0000-4000-8000-000000000002',
      'project',
      'b9010000-0000-4000-8000-000000000001'
    ) as receipt
  ),
  true
);

reset role;
select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
  ),
  2::bigint,
  'the snapshot invites only the creator and active uninvolved member'
);
select results_eq(
  $$
    select request.recipient_profile_id
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
    order by request.recipient_profile_id
  $$,
  $$
    values
      ('b9000000-0000-4000-8000-000000000003'::uuid),
      ('b9000000-0000-4000-8000-000000000004'::uuid)
  $$,
  'reporter, subject, and already-ended former members are excluded'
);

set local role authenticated;
select is(
  (
    select count(*)
    from public.submit_moderation_report(
      'b9000000-0000-4000-8000-000000000001',
      'b9100000-0000-4000-8000-000000000001',
      'harassment_abuse',
      'The reported conduct occurred during our shared Project activity.',
      'profile',
      'b9000000-0000-4000-8000-000000000002',
      'project',
      'b9010000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'the original report retry remains successful'
);
reset role;
select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
  ),
  2::bigint,
  'an original report retry creates no duplicate invitation'
);

set local role authenticated;
select set_config(
  'test.project_only_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'b9000000-0000-4000-8000-000000000001',
      'b9100000-0000-4000-8000-000000000002',
      'other',
      'This concerns the Project generally, not one person conduct incident.',
      'project',
      'b9010000-0000-4000-8000-000000000001',
      null,
      null
    ) as receipt
  ),
  true
);
reset role;
select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.project_only_case_id')::uuid
  ),
  0::bigint,
  'a generic Project content report does not trigger corroboration'
);

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'b9030000-0000-4000-8000-000000000006',
  'b9010000-0000-4000-8000-000000000001',
  'b9000000-0000-4000-8000-000000000006',
  'b9020000-0000-4000-8000-000000000006',
  statement_timestamp()
);
update public.project_memberships
set left_at = statement_timestamp()
where id = 'b9030000-0000-4000-8000-000000000004';

select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
  ),
  2::bigint,
  'later joins and leaves do not rewrite the snapshotted cohort'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.list_own_group_corroboration_requests(
      'b9000000-0000-4000-8000-000000000003',
      true,
      20,
      null,
      null
    )
  ),
  1::bigint,
  'the assigned creator can read the own pending summary'
);
select set_config(
  'test.creator_request_id',
  (
    select own_request.request_id::text
    from public.list_own_group_corroboration_requests(
      'b9000000-0000-4000-8000-000000000003',
      true,
      20,
      null,
      null
    ) as own_request
  ),
  true
);
select is(
  (
    select detail.explanation
    from public.get_own_group_corroboration_request(
      'b9000000-0000-4000-8000-000000000003',
      current_setting('test.creator_request_id')::uuid
    ) as detail
  ),
  'The reported conduct occurred during our shared Project activity.',
  'the invitee sees the original wording through the assigned detail'
);

select set_config(
  'test.response_id',
  (
    select response.response_id::text
    from public.submit_group_corroboration_response(
      'b9000000-0000-4000-8000-000000000003',
      current_setting('test.creator_request_id')::uuid,
      'b9110000-0000-4000-8000-000000000001',
      'agree',
      '  I was present for part of the activity.  '
    ) as response
  ),
  true
);
select is(
  (
    select response.response_id::text
    from public.submit_group_corroboration_response(
      'b9000000-0000-4000-8000-000000000003',
      current_setting('test.creator_request_id')::uuid,
      'b9110000-0000-4000-8000-000000000001',
      'agree',
      'I was present for part of the activity.'
    ) as response
  ),
  current_setting('test.response_id'),
  'an exact canonical retry returns the first response'
);
select throws_ok(
  format(
    'select * from public.submit_group_corroboration_response(%L, %L, %L, %L, %L)',
    'b9000000-0000-4000-8000-000000000003',
    current_setting('test.creator_request_id'),
    'b9110000-0000-4000-8000-000000000002',
    'disagree',
    'A second conclusion must not overwrite the final answer.'
  ),
  'PT409',
  'A final response has already been submitted for this request.',
  'a conflicting second response cannot rewrite evidence'
);

select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_own_group_corroboration_request(
      'b9000000-0000-4000-8000-000000000002',
      current_setting('test.creator_request_id')::uuid
    )
  ),
  0::bigint,
  'the reported subject cannot read another recipient request'
);

reset role;
insert into private.moderation_staff_roles (profile_id, staff_role)
values ('b9000000-0000-4000-8000-000000000007', 'moderator');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000007',
  true
);
select results_eq(
  $$
    select
      evidence.invited_count,
      evidence.responded_count,
      evidence.pending_count,
      evidence.agree_count,
      evidence.disagree_count,
      evidence.unsure_count
    from public.get_moderation_case_corroboration(
      'b9000000-0000-4000-8000-000000000007',
      current_setting('test.corroboration_case_id')::uuid
    ) as evidence
  $$,
  $$values (2::bigint, 1::bigint, 1::bigint, 1::bigint, 0::bigint, 0::bigint)$$,
  'staff sees evidence counts without an automated verdict'
);
select is(
  (
    select evidence.responses -> 0 ->> 'responder_profile_id'
    from public.get_moderation_case_corroboration(
      'b9000000-0000-4000-8000-000000000007',
      current_setting('test.corroboration_case_id')::uuid
    ) as evidence
  ),
  'b9000000-0000-4000-8000-000000000003',
  'staff evidence retains responder identity'
);

select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 0, %L)',
    'b9000000-0000-4000-8000-000000000007',
    current_setting('test.corroboration_case_id'),
    'under_review'
  ),
  'staff can begin review'
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 1, %L)',
    'b9000000-0000-4000-8000-000000000007',
    current_setting('test.corroboration_case_id'),
    'completed'
  ),
  'staff can complete review'
);

select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000004',
  true
);
select is(
  (
    select count(*)
    from public.list_own_group_corroboration_requests(
      'b9000000-0000-4000-8000-000000000004',
      true,
      20,
      null,
      null
    )
  ),
  0::bigint,
  'completion hides unanswered requests from ordinary pending reads'
);
reset role;
select set_config(
  'test.member_request_id',
  (
    select request.id::text
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
      and request.recipient_profile_id =
        'b9000000-0000-4000-8000-000000000004'
  ),
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  format(
    'select * from public.submit_group_corroboration_response(%L, %L, %L, %L, null)',
    'b9000000-0000-4000-8000-000000000004',
    current_setting('test.member_request_id'),
    'b9110000-0000-4000-8000-000000000004',
    'unsure'
  ),
  'PT409',
  'The moderation case is already completed.',
  'completion rejects a new response'
);

select set_config(
  'request.jwt.claim.sub',
  'b9000000-0000-4000-8000-000000000007',
  true
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 2, %L)',
    'b9000000-0000-4000-8000-000000000007',
    current_setting('test.corroboration_case_id'),
    'under_review'
  ),
  'staff can reopen the case'
);

reset role;
select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.corroboration_case_id')::uuid
  ),
  2::bigint,
  'reopening reuses the original cohort instead of resnapshotting membership'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action like 'moderation.group_corroboration%'
      and (
        event.metadata::text like '%agree%'
        or event.metadata::text like '%present for part%'
        or event.metadata::text like '%recipient_profile_id%'
      )
  ),
  0::bigint,
  'generic audit metadata contains no choice, explanation, or recipient mapping'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type like 'moderation.group_corroboration%'
  ),
  0::bigint,
  'corroboration evidence is not emitted to outbox delivery'
);

select * from finish();

rollback;
