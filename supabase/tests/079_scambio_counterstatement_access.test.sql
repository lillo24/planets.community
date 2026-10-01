begin;

select no_plan();

insert into auth.users (id, email)
values
  ('c9000000-0000-4000-8000-000000000001', 'owner-09a2b@planets.invalid'),
  ('c9000000-0000-4000-8000-000000000002', 'requester-09a2b@planets.invalid'),
  ('c9000000-0000-4000-8000-000000000003', 'outsider-09a2b@planets.invalid'),
  ('c9000000-0000-4000-8000-000000000004', 'moderator-09a2b@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('c9000000-0000-4000-8000-000000000001', 'Resource Owner'),
  ('c9000000-0000-4000-8000-000000000002', 'Resource Requester'),
  ('c9000000-0000-4000-8000-000000000003', 'Unrelated Viewer'),
  ('c9000000-0000-4000-8000-000000000004', 'Resource Moderator');

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
  'c9010000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000001',
  'exchange',
  'published',
  'Counterstatement test resource',
  'A public Resource listing used for private moderation evidence tests.',
  'IT',
  'Trento',
  'Trento',
  statement_timestamp() - interval '1 day'
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
  'c9020000-0000-4000-8000-000000000001',
  'c9010000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000002',
  'accepted',
  statement_timestamp() - interval '2 hours',
  statement_timestamp() - interval '1 hour',
  'c9000000-0000-4000-8000-000000000001'
);

insert into public.resource_request_chats (id, request_id, activated_at)
values (
  'c9030000-0000-4000-8000-000000000001',
  'c9020000-0000-4000-8000-000000000001',
  statement_timestamp() - interval '1 hour'
);

insert into public.resource_request_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body
)
values (
  'c9040000-0000-4000-8000-000000000001',
  'c9030000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000001',
  'Private Resource message used only as a typed report target.'
);

insert into private.moderation_staff_roles (profile_id, staff_role)
values ('c9000000-0000-4000-8000-000000000004', 'moderator');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select * from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000003',
      'c9100000-0000-4000-8000-000000000001',
      'other',
      'This invalid context does not make me a Resource counterparty.',
      'profile',
      'c9000000-0000-4000-8000-000000000001',
      'resource_request',
      'c9020000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The report target is unavailable.',
  'a non-counterparty cannot manufacture a Resource counterstatement context'
);

select set_config(
  'test.listing_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000003',
      'c9100000-0000-4000-8000-000000000002',
      'spam',
      'This public listing report concerns only the listing content.',
      'resource_listing',
      'c9010000-0000-4000-8000-000000000001',
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
    where request.case_id = current_setting('test.listing_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
  ),
  0::bigint,
  'a generic public listing report creates no counterparty statement request'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.request_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000001',
      'c9100000-0000-4000-8000-000000000010',
      'harassment_abuse',
      'The requester conduct during this exchange needs staff review.',
      'resource_request',
      'c9020000-0000-4000-8000-000000000001',
      null,
      null
    ) as receipt
  ),
  true
);
select is(
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000001',
      'c9100000-0000-4000-8000-000000000010',
      'harassment_abuse',
      'The requester conduct during this exchange needs staff review.',
      'resource_request',
      'c9020000-0000-4000-8000-000000000001',
      null,
      null
    ) as receipt
  ),
  current_setting('test.request_case_id'),
  'an exact report retry returns the original case'
);
reset role;

select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.request_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
      and request.recipient_profile_id =
        'c9000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'an owner report creates exactly one request for the canonical requester'
);
select set_config(
  'test.counterstatement_request_id',
  (
    select request.id::text
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.request_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.profile_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000002',
      'c9100000-0000-4000-8000-000000000011',
      'other',
      'The owner conduct in our canonical Resource request needs review.',
      'profile',
      'c9000000-0000-4000-8000-000000000001',
      'resource_request',
      'c9020000-0000-4000-8000-000000000001'
    ) as receipt
  ),
  true
);
select set_config(
  'test.reverse_request_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000002',
      'c9100000-0000-4000-8000-000000000012',
      'fraud_scam',
      'The owner handling of this Resource request needs staff review.',
      'resource_request',
      'c9020000-0000-4000-8000-000000000001',
      null,
      null
    ) as receipt
  ),
  true
);
select set_config(
  'test.chat_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'c9000000-0000-4000-8000-000000000002',
      'c9100000-0000-4000-8000-000000000013',
      'inappropriate_content_conduct',
      'The owner message in our private Resource conversation crossed a boundary.',
      'resource_chat_message',
      'c9040000-0000-4000-8000-000000000001',
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
    where request.case_id in (
      current_setting('test.profile_case_id')::uuid,
      current_setting('test.reverse_request_case_id')::uuid,
      current_setting('test.chat_case_id')::uuid
    )
      and request.request_kind = 'resource_counterstatement'
      and request.recipient_profile_id =
        'c9000000-0000-4000-8000-000000000001'
  ),
  3::bigint,
  'profile-context, reverse request, and Resource message reports each invite the canonical reported owner'
);

select set_config(
  'test.profile_request_id',
  (
    select request.id::text
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.profile_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
  ),
  true
);

with inserted as (
  insert into private.moderation_evidence_requests (
    case_id,
    request_kind,
    recipient_profile_id,
    created_at
  )
  values (
    current_setting('test.request_case_id')::uuid,
    'group_corroboration',
    'c9000000-0000-4000-8000-000000000002',
    statement_timestamp() - interval '1 minute'
  )
  returning id
)
select set_config(
  'test.group_request_id',
  (select id::text from inserted),
  true
);

select throws_ok(
  format(
    'insert into private.moderation_counterstatements (evidence_request_id, responder_profile_id, client_submission_id, statement) values (%L, %L, %L, %L)',
    current_setting('test.group_request_id'),
    'c9000000-0000-4000-8000-000000000002',
    'c9110000-0000-4000-8000-000000000001',
    'This must not attach to a group corroboration request.'
  ),
  '23503',
  null,
  'a counterstatement cannot attach to a group corroboration request'
);
select throws_ok(
  format(
    'insert into private.moderation_evidence_responses (evidence_request_id, responder_profile_id, client_submission_id, choice) values (%L, %L, %L, %L)',
    current_setting('test.counterstatement_request_id'),
    'c9000000-0000-4000-8000-000000000002',
    'c9110000-0000-4000-8000-000000000002',
    'agree'
  ),
  '23503',
  null,
  'a group corroboration response cannot attach to a counterstatement request'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select request.request_kind
    from public.list_own_moderation_evidence_requests(
      'c9000000-0000-4000-8000-000000000002',
      true,
      2
    ) as request
  $$,
  $$
    values
      ('group_corroboration'::text),
      ('resource_counterstatement'::text)
  $$,
  'the unified pending list deterministically includes both evidence kinds oldest first'
);
select is(
  (
    select detail.explanation
    from public.get_own_resource_counterstatement_request(
      'c9000000-0000-4000-8000-000000000002',
      current_setting('test.counterstatement_request_id')::uuid
    ) as detail
  ),
  'The requester conduct during this exchange needs staff review.',
  'the assigned subject can read the original accusation without a reporter identity field'
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, %L)',
    'c9000000-0000-4000-8000-000000000002',
    current_setting('test.counterstatement_request_id'),
    'c9110000-0000-4000-8000-000000000003',
    '   '
  ),
  '22023',
  'The counterparty statement must contain between 10 and 4,000 characters.',
  'blank statements are rejected canonically'
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, repeat(%L, 4001))',
    'c9000000-0000-4000-8000-000000000002',
    current_setting('test.counterstatement_request_id'),
    'c9110000-0000-4000-8000-000000000004',
    'x'
  ),
  '22023',
  'The counterparty statement must contain between 10 and 4,000 characters.',
  'oversized statements are rejected canonically'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'c9000000-0000-4000-8000-000000000001',
      'c9010000-0000-4000-8000-000000000001'
    )
  $$,
  'later listing closure succeeds independently of moderation evidence'
);
reset role;

select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.id =
      current_setting('test.counterstatement_request_id')::uuid
  ),
  1::bigint,
  'later Resource lifecycle changes do not rewrite the invitation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.counterstatement_id',
  (
    select response.counterstatement_id::text
    from public.submit_resource_counterstatement(
      'c9000000-0000-4000-8000-000000000002',
      current_setting('test.counterstatement_request_id')::uuid,
      'c9110000-0000-4000-8000-000000000010',
      '  My private version provides relevant context for staff review.  '
    ) as response
  ),
  true
);
select is(
  (
    select response.counterstatement_id::text
    from public.submit_resource_counterstatement(
      'c9000000-0000-4000-8000-000000000002',
      current_setting('test.counterstatement_request_id')::uuid,
      'c9110000-0000-4000-8000-000000000010',
      'My private version provides relevant context for staff review.'
    ) as response
  ),
  current_setting('test.counterstatement_id'),
  'an exact canonical retry returns the first immutable statement'
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, %L)',
    'c9000000-0000-4000-8000-000000000002',
    current_setting('test.counterstatement_request_id'),
    'c9110000-0000-4000-8000-000000000011',
    'A conflicting later statement must never overwrite the first one.'
  ),
  'PT409',
  'A final counterparty statement has already been submitted.',
  'a conflicting second statement cannot rewrite evidence'
);
reset role;

select is(
  (
    select counterstatement.statement
    from private.moderation_counterstatements as counterstatement
    where counterstatement.id = current_setting('test.counterstatement_id')::uuid
  ),
  'My private version provides relevant context for staff review.',
  'the stored statement is canonical and trimmed'
);
select is(
  (
    select moderation_case.state
    from private.moderation_cases as moderation_case
    where moderation_case.id = current_setting('test.request_case_id')::uuid
  ),
  'received',
  'statement submission does not change moderation state'
);
select results_eq(
  $$
    select request.status, listing.lifecycle_state, message.body
    from public.resource_listing_requests as request
    join public.resource_listings as listing on listing.id = request.listing_id
    join public.resource_request_chats as chat on chat.request_id = request.id
    join public.resource_request_chat_messages as message
      on message.chat_id = chat.id
    where request.id = 'c9020000-0000-4000-8000-000000000001'
  $$,
  $$
    values (
      'accepted'::text,
      'closed'::text,
      'Private Resource message used only as a typed report target.'::text
    )
  $$,
  'moderation evidence submission mutates no Resource request or conversation state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_own_resource_counterstatement_request(
      'c9000000-0000-4000-8000-000000000001',
      current_setting('test.counterstatement_request_id')::uuid
    )
  ),
  0::bigint,
  'the reporter cannot read the counterstatement request or statement'
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, %L)',
    'c9000000-0000-4000-8000-000000000001',
    current_setting('test.counterstatement_request_id'),
    'c9110000-0000-4000-8000-000000000012',
    'The reporter must not gain a reply path into this evidence flow.'
  ),
  '42501',
  'The counterparty statement request is unavailable.',
  'the reporter cannot submit against the subject request'
);
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_own_resource_counterstatement_request(
      'c9000000-0000-4000-8000-000000000003',
      current_setting('test.counterstatement_request_id')::uuid
    )
  ),
  0::bigint,
  'an unrelated user cannot discover a guessed request through detail'
);

select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000004',
  true
);
select results_eq(
  $$
    select
      evidence.recipient_profile_id,
      evidence.recipient_display_name,
      evidence.statement,
      evidence.submitted_at is not null
    from public.get_moderation_case_counterstatement(
      'c9000000-0000-4000-8000-000000000004',
      current_setting('test.request_case_id')::uuid
    ) as evidence
  $$,
  $$
    values (
      'c9000000-0000-4000-8000-000000000002'::uuid,
      'Resource Requester'::text,
      'My private version provides relevant context for staff review.'::text,
      true
    )
  $$,
  'staff sees the assigned identity and submitted private statement'
);

select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 0, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.profile_case_id'),
    'under_review'
  ),
  'staff can begin review while a statement is pending'
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 1, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.profile_case_id'),
    'completed'
  ),
  'staff can complete a case without waiting for a statement'
);

select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.list_own_moderation_evidence_requests(
      'c9000000-0000-4000-8000-000000000001',
      true,
      50
    ) as request
    where request.request_id =
      current_setting('test.profile_request_id')::uuid
  ),
  0::bigint,
  'completion hides the unanswered statement from pending reads'
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, %L)',
    'c9000000-0000-4000-8000-000000000001',
    current_setting('test.profile_request_id'),
    'c9110000-0000-4000-8000-000000000020',
    'This statement arrives only after the case was already completed.'
  ),
  'PT409',
  'The moderation case is already completed.',
  'a completed case rejects new evidence'
);

select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000004',
  true
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 2, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.profile_case_id'),
    'under_review'
  ),
  'staff can reopen the unanswered case'
);
reset role;

select is(
  (
    select count(*)
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.profile_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
  ),
  1::bigint,
  'reopening restores the original unanswered request without resnapshotting'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000004',
  true
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 0, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.request_case_id'),
    'under_review'
  ),
  'staff can begin review after a statement was submitted'
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 1, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.request_case_id'),
    'completed'
  ),
  'staff can complete a case after a statement was submitted'
);
select lives_ok(
  format(
    'select * from public.transition_moderation_case(%L, %L, 2, %L)',
    'c9000000-0000-4000-8000-000000000004',
    current_setting('test.request_case_id'),
    'under_review'
  ),
  'staff can reopen a case with an immutable statement'
);

select set_config(
  'request.jwt.claim.sub',
  'c9000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  format(
    'select * from public.submit_resource_counterstatement(%L, %L, %L, %L)',
    'c9000000-0000-4000-8000-000000000002',
    current_setting('test.counterstatement_request_id'),
    'c9110000-0000-4000-8000-000000000021',
    'Reopening must not create a second opportunity to rewrite evidence.'
  ),
  'PT409',
  'A final counterparty statement has already been submitted.',
  'reopening never permits a second statement after submission'
);
reset role;

select is(
  (
    select count(*)
    from private.moderation_counterstatements as counterstatement
    join private.moderation_evidence_requests as request
      on request.id = counterstatement.evidence_request_id
    where request.case_id = current_setting('test.request_case_id')::uuid
  ),
  1::bigint,
  'the case retains exactly one final counterstatement after reopen'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action like 'moderation.resource_counterstatement%'
      and (
        event.metadata::text like '%private version%'
        or event.metadata::text like '%reporter_profile_id%'
        or event.metadata::text like '%recipient_profile_id%'
      )
  ),
  0::bigint,
  'generic audit metadata contains no statement body or party mapping'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type like 'moderation.resource_counterstatement%'
      or event.payload::text like '%private version%'
  ),
  0::bigint,
  'counterstatement evidence is never emitted through the outbox'
);

select * from finish();

rollback;
