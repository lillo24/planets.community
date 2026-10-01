begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a9100000-0000-4000-8000-000000000001', 'blocking-a@planets.invalid'),
  ('a9100000-0000-4000-8000-000000000002', 'blocking-b@planets.invalid'),
  ('a9100000-0000-4000-8000-000000000003', 'blocking-witness@planets.invalid'),
  ('a9100000-0000-4000-8000-000000000004', 'blocking-moderator@planets.invalid'),
  ('a9100000-0000-4000-8000-000000000005', 'blocking-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a9100000-0000-4000-8000-000000000001', 'Blocking A'),
  ('a9100000-0000-4000-8000-000000000002', 'Blocking B'),
  ('a9100000-0000-4000-8000-000000000003', 'Blocking Witness'),
  ('a9100000-0000-4000-8000-000000000004', 'Blocking Moderator'),
  ('a9100000-0000-4000-8000-000000000005', null);

insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'profile-photos',
    'a9100000-0000-4000-8000-000000000001/a9700000-0000-4000-8000-000000000001.webp',
    'a9100000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a9100000-0000-4000-8000-000000000002/a9700000-0000-4000-8000-000000000002.webp',
    'a9100000-0000-4000-8000-000000000002',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a9100000-0000-4000-8000-000000000003/a9700000-0000-4000-8000-000000000003.webp',
    'a9100000-0000-4000-8000-000000000003',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );

insert into public.profile_photos (profile_id, object_path, audience)
values
  (
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000001/a9700000-0000-4000-8000-000000000001.webp',
    'interactions'
  ),
  (
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000002/a9700000-0000-4000-8000-000000000002.webp',
    'interactions'
  ),
  (
    'a9100000-0000-4000-8000-000000000003',
    'a9100000-0000-4000-8000-000000000003/a9700000-0000-4000-8000-000000000003.webp',
    'interactions'
  );

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at
)
values
  (
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000001',
    'published',
    'A pending and accepted Project',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'a9200000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000002',
    'published',
    'B pending Project',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'a9200000-0000-4000-8000-000000000003',
    'a9100000-0000-4000-8000-000000000001',
    'published',
    'A blocked acceptance Project',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '1 day'
  );

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
values (
  'a9200000-0000-4000-8000-000000000001',
  'Shared courtyard after the block',
  'participants'
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
    'a9300000-0000-4000-8000-000000000001',
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002',
    'pending',
    statement_timestamp() - interval '3 hours',
    null,
    null
  ),
  (
    'a9300000-0000-4000-8000-000000000002',
    'a9200000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001',
    'pending',
    statement_timestamp() - interval '3 hours',
    null,
    null
  ),
  (
    'a9300000-0000-4000-8000-000000000003',
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002',
    'accepted',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    'a9100000-0000-4000-8000-000000000001'
  ),
  (
    'a9300000-0000-4000-8000-000000000004',
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000003',
    'accepted',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    'a9100000-0000-4000-8000-000000000001'
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values
  (
    'a9400000-0000-4000-8000-000000000001',
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002',
    'a9300000-0000-4000-8000-000000000003',
    statement_timestamp() - interval '2 days'
  ),
  (
    'a9400000-0000-4000-8000-000000000002',
    'a9200000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000003',
    'a9300000-0000-4000-8000-000000000004',
    statement_timestamp() - interval '2 days'
  );

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
values
  (
    'a9500000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'A pending resource',
    'The owner-side pending request is rejected by the block.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp() - interval '1 day'
  ),
  (
    'a9500000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000002',
    'exchange',
    'published',
    'B pending resource',
    'The requester-side pending request is withdrawn by the block.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp() - interval '1 day'
  ),
  (
    'a9500000-0000-4000-8000-000000000003',
    'a9100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Accepted coordination resource',
    'The accepted agreement and chat remain available after blocking.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp() - interval '1 day'
  ),
  (
    'a9500000-0000-4000-8000-000000000004',
    'a9100000-0000-4000-8000-000000000001',
    'donate',
    'published',
    'Blocked future resource',
    'A fresh request against this public listing is blocked.',
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
values
  (
    'a9600000-0000-4000-8000-000000000001',
    'a9500000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002',
    'pending',
    statement_timestamp() - interval '3 hours',
    null,
    null
  ),
  (
    'a9600000-0000-4000-8000-000000000002',
    'a9500000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001',
    'pending',
    statement_timestamp() - interval '3 hours',
    null,
    null
  ),
  (
    'a9600000-0000-4000-8000-000000000003',
    'a9500000-0000-4000-8000-000000000003',
    'a9100000-0000-4000-8000-000000000002',
    'accepted',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    'a9100000-0000-4000-8000-000000000001'
  );

select private.ensure_resource_exchange_agreement_for_request(
  'a9600000-0000-4000-8000-000000000003',
  'a9100000-0000-4000-8000-000000000001',
  null
);
select private.ensure_resource_request_chat_for_request(
  'a9600000-0000-4000-8000-000000000003',
  null
);

insert into private.moderation_staff_roles (profile_id, staff_role)
values ('a9100000-0000-4000-8000-000000000004', 'moderator');

select set_config(
  'test.blocking_project_chat_id',
  (
    select chat.id::text
    from public.project_group_chats as chat
    where chat.project_id = 'a9200000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.blocking_resource_chat_id',
  (
    select chat.id::text
    from public.resource_request_chats as chat
    where chat.request_id = 'a9600000-0000-4000-8000-000000000003'
  ),
  true
);
select set_config(
  'test.blocking_resource_agreement_id',
  (
    select agreement.id::text
    from public.resource_exchange_agreements as agreement
    where agreement.request_id = 'a9600000-0000-4000-8000-000000000003'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a9100000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'an accepted relationship exposes the interactions photo before blocking'
);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a9100000-0000-4000-8000-000000000001/a9700000-0000-4000-8000-000000000001.webp'
  ),
  1::bigint,
  'Storage authorization matches pre-block interactions-photo metadata access'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000005',
  true
);
select throws_ok(
  $$
    select public.block_user(
      'a9100000-0000-4000-8000-000000000005',
      'a9100000-0000-4000-8000-000000000001'
    )
  $$,
  '55000',
  'A complete profile is required to manage user blocks.',
  'an incomplete profile cannot create a block'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.block_user(
      'a9100000-0000-4000-8000-000000000002',
      'a9100000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected blocking profile.',
  'block operations reject expected-identity account switching'
);
select throws_ok(
  $$
    select public.block_user(
      'a9100000-0000-4000-8000-000000000001',
      'a9100000-0000-4000-8000-000000000001'
    )
  $$,
  '22023',
  'A profile cannot block itself.',
  'the public operation rejects self-blocking'
);
select throws_ok(
  $$
    select public.block_user(
      'a9100000-0000-4000-8000-000000000001',
      'a9990000-0000-4000-8000-000000000099'
    )
  $$,
  'P0002',
  'The target profile is unavailable.',
  'an unavailable target fails explicitly'
);

select set_config(
  'test.blocking_first_episode_id',
  public.block_user(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  )::text,
  true
);
select is(
  public.block_user(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  )::text,
  current_setting('test.blocking_first_episode_id'),
  'an active block retry is idempotent'
);

reset role;
select results_eq(
  $$
    select request.id, request.status, request.resolved_by_profile_id
    from public.project_join_requests as request
    where request.id in (
      'a9300000-0000-4000-8000-000000000001',
      'a9300000-0000-4000-8000-000000000002'
    )
    order by request.id
  $$,
  $$
    values
      (
        'a9300000-0000-4000-8000-000000000001'::uuid,
        'rejected'::text,
        'a9100000-0000-4000-8000-000000000001'::uuid
      ),
      (
        'a9300000-0000-4000-8000-000000000002'::uuid,
        'withdrawn'::text,
        'a9100000-0000-4000-8000-000000000001'::uuid
      )
  $$,
  'blocking closes pending Project requests with role-canonical terminal states'
);
select results_eq(
  $$
    select request.id, request.status, request.resolved_by_profile_id
    from public.resource_listing_requests as request
    where request.id in (
      'a9600000-0000-4000-8000-000000000001',
      'a9600000-0000-4000-8000-000000000002'
    )
    order by request.id
  $$,
  $$
    values
      (
        'a9600000-0000-4000-8000-000000000001'::uuid,
        'rejected'::text,
        'a9100000-0000-4000-8000-000000000001'::uuid
      ),
      (
        'a9600000-0000-4000-8000-000000000002'::uuid,
        'withdrawn'::text,
        'a9100000-0000-4000-8000-000000000001'::uuid
      )
  $$,
  'blocking closes pending Resource requests with role-canonical terminal states'
);
select is(
  (
    select count(*)
    from public.project_memberships
    where id = 'a9400000-0000-4000-8000-000000000001'
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'the accepted Project membership remains current'
);
select results_eq(
  $$
    select request.status, agreement.lifecycle_state, request.coordination_closed_at
    from public.resource_listing_requests as request
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = request.id
    where request.id = 'a9600000-0000-4000-8000-000000000003'
  $$,
  $$values ('accepted'::text, 'negotiating'::text, null::timestamptz)$$,
  'the accepted Resource agreement remains open and unchanged'
);
select is(
  private.has_active_directional_user_block(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  ),
  true,
  'the stored directional block is active'
);
select is(
  private.has_active_user_block_between(
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001'
  ),
  true,
  'the canonical barrier is symmetric'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'a9100000-0000-4000-8000-000000000002',
      'a9200000-0000-4000-8000-000000000003',
      null,
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  'PT409',
  'This interaction is unavailable.',
  'a requester cannot start a new Project interaction across either block direction'
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'a9100000-0000-4000-8000-000000000002',
      'a9500000-0000-4000-8000-000000000004',
      null
    )
  $$,
  'PT409',
  'This interaction is unavailable.',
  'a requester cannot start a new Resource interaction across either block direction'
);
select is(
  (
    select count(*)
    from public.list_own_blocked_profiles(
      'a9100000-0000-4000-8000-000000000002',
      50,
      null,
      null
    )
  ),
  0::bigint,
  'the blocked profile cannot enumerate an inbound block'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a9100000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'the interaction-only photo is revoked across the blocked pair'
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      'a9200000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'the contextual Project photo path respects the block barrier'
);
select is(
  (
    select count(*)
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      'a9500000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'the contextual Resource photo path respects the block barrier'
);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a9100000-0000-4000-8000-000000000001/a9700000-0000-4000-8000-000000000001.webp'
  ),
  0::bigint,
  'Storage authorization revokes the same interaction-only object'
);
select is(
  (
    select count(*)
    from public.get_own_project_group_chat(
      'a9100000-0000-4000-8000-000000000002',
      'a9200000-0000-4000-8000-000000000001'
    )
    where has_current_entitlement
  ),
  1::bigint,
  'the current member retains ordinary Project group-chat entitlement'
);
select is(
  (
    select count(*)
    from public.send_project_chat_message(
      'a9100000-0000-4000-8000-000000000002',
      current_setting('test.blocking_project_chat_id')::uuid,
      'B can still coordinate in the shared Project group.'
    )
  ),
  1::bigint,
  'the current member can still send a Project group message'
);
select is(
  (
    select count(*)
    from public.get_project_participant_meeting_details(
      'a9100000-0000-4000-8000-000000000002',
      'a9200000-0000-4000-8000-000000000001'
    )
    where exact_meeting_text = 'Shared courtyard after the block'
  ),
  1::bigint,
  'the current member retains protected meeting access'
);
select is(
  (
    select count(*)
    from public.get_resource_exchange_agreement(
      'a9100000-0000-4000-8000-000000000002',
      'a9600000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'the accepted requester retains agreement access'
);
select is(
  (
    select count(*)
    from public.send_resource_request_chat_message(
      'a9100000-0000-4000-8000-000000000002',
      current_setting('test.blocking_resource_chat_id')::uuid,
      'B can still coordinate the accepted exchange.'
    )
  ),
  1::bigint,
  'the accepted requester can still send a Resource chat message'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select blocked_profile_id, blocked_display_name
    from public.list_own_blocked_profiles(
      'a9100000-0000-4000-8000-000000000001',
      50,
      null,
      null
    )
  $$,
  $$
    values (
      'a9100000-0000-4000-8000-000000000002'::uuid,
      'Blocking B'::text
    )
  $$,
  'the blocker sees only their own active outbound block'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a9100000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'the photo owner retains access to their own interactions photo'
);
select is(
  (
    select count(*)
    from public.send_project_chat_message(
      'a9100000-0000-4000-8000-000000000001',
      current_setting('test.blocking_project_chat_id')::uuid,
      'A can still coordinate in the shared Project group.'
    )
  ),
  1::bigint,
  'the Project creator can still send a group message'
);
select is(
  (
    select count(*)
    from public.send_resource_request_chat_message(
      'a9100000-0000-4000-8000-000000000001',
      current_setting('test.blocking_resource_chat_id')::uuid,
      'A can still coordinate the accepted exchange.'
    )
  ),
  1::bigint,
  'the Resource owner can still send an accepted-coordination message'
);
select set_config(
  'test.blocking_resource_terms_id',
  public.propose_resource_exchange_terms(
    'a9100000-0000-4000-8000-000000000001',
    current_setting('test.blocking_resource_agreement_id')::uuid,
    null,
    null,
    'give',
    null,
    null,
    'none',
    null,
    null,
    null,
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.accept_resource_exchange_terms(
    'a9100000-0000-4000-8000-000000000002',
    current_setting('test.blocking_resource_agreement_id')::uuid,
    current_setting('test.blocking_resource_terms_id')::uuid
  ),
  current_setting('test.blocking_resource_terms_id')::uuid,
  'accepted Resource terms remain ordinarily actionable across the block'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select isnt(
  public.record_resource_exchange_milestone(
    'a9100000-0000-4000-8000-000000000001',
    current_setting('test.blocking_resource_agreement_id')::uuid,
    current_setting('test.blocking_resource_terms_id')::uuid,
    'owner_resource',
    'resource_provided'
  ),
  null::uuid,
  'accepted Resource milestones remain ordinarily actionable across the block'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status
)
values (
  'a9300000-0000-4000-8000-000000000005',
  'a9200000-0000-4000-8000-000000000003',
  'a9100000-0000-4000-8000-000000000002',
  'pending'
);
insert into public.resource_listing_requests (
  id,
  listing_id,
  requester_profile_id,
  status
)
values (
  'a9600000-0000-4000-8000-000000000004',
  'a9500000-0000-4000-8000-000000000004',
  'a9100000-0000-4000-8000-000000000002',
  'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'a9100000-0000-4000-8000-000000000001',
      'a9300000-0000-4000-8000-000000000005'
    )
  $$,
  'PT409',
  'This interaction is unavailable.',
  'Project acceptance cannot cross an active block'
);
select throws_ok(
  $$
    select public.accept_resource_listing_request(
      'a9100000-0000-4000-8000-000000000001',
      'a9600000-0000-4000-8000-000000000004'
    )
  $$,
  'PT409',
  'This interaction is unavailable.',
  'Resource acceptance cannot cross an active block'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.blocking_resource_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'a9100000-0000-4000-8000-000000000002',
      'a9800000-0000-4000-8000-000000000001',
      'harassment_abuse',
      'The accepted exchange needs independent staff review.',
      'profile',
      'a9100000-0000-4000-8000-000000000001',
      'resource_request',
      'a9600000-0000-4000-8000-000000000003'
    ) as receipt
  ),
  true
);
select is(
  (
    select count(*)
    from public.list_own_moderation_reports(
      'a9100000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
    where case_id = current_setting('test.blocking_resource_case_id')::uuid
  ),
  1::bigint,
  'own moderation report status remains readable across the block'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.blocking_group_case_id',
  (
    select receipt.case_id::text
    from public.submit_moderation_report(
      'a9100000-0000-4000-8000-000000000003',
      'a9800000-0000-4000-8000-000000000002',
      'harassment_abuse',
      'The conduct occurred in our shared Project.',
      'profile',
      'a9100000-0000-4000-8000-000000000002',
      'project',
      'a9200000-0000-4000-8000-000000000001'
    ) as receipt
  ),
  true
);

reset role;
select set_config(
  'test.blocking_counterstatement_request_id',
  (
    select request.id::text
    from private.moderation_evidence_requests as request
    where request.case_id =
      current_setting('test.blocking_resource_case_id')::uuid
      and request.request_kind = 'resource_counterstatement'
      and request.recipient_profile_id =
        'a9100000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.blocking_corroboration_request_id',
  (
    select request.id::text
    from private.moderation_evidence_requests as request
    where request.case_id = current_setting('test.blocking_group_case_id')::uuid
      and request.request_kind = 'group_corroboration'
      and request.recipient_profile_id =
        'a9100000-0000-4000-8000-000000000001'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.submit_resource_counterstatement(
      'a9100000-0000-4000-8000-000000000001',
      current_setting('test.blocking_counterstatement_request_id')::uuid,
      'a9800000-0000-4000-8000-000000000003',
      'My account of the accepted Resource exchange remains available.'
    )
  ),
  1::bigint,
  'an assigned Resource counterstatement remains submittable across the block'
);
select is(
  (
    select count(*)
    from public.submit_group_corroboration_response(
      'a9100000-0000-4000-8000-000000000001',
      current_setting('test.blocking_corroboration_request_id')::uuid,
      'a9800000-0000-4000-8000-000000000004',
      'unsure',
      'I did not witness the reported conduct directly.'
    )
  ),
  1::bigint,
  'an assigned group corroboration remains submittable across the block'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000004',
  true
);
select is(
  (
    select count(*)
    from public.list_moderation_cases(
      'a9100000-0000-4000-8000-000000000004',
      null,
      50,
      null,
      null
    )
    where case_id in (
      current_setting('test.blocking_resource_case_id')::uuid,
      current_setting('test.blocking_group_case_id')::uuid
    )
  ),
  2::bigint,
  'staff review remains independent of user blocking'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.blocking_reverse_episode_id',
  public.block_user(
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.unblock_user(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  )::text,
  current_setting('test.blocking_first_episode_id'),
  'unblock closes only the caller-owned direction'
);

reset role;
select is(
  private.has_active_directional_user_block(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  ),
  false,
  'the first direction is inactive after its owner unblocks'
);
select is(
  private.has_active_directional_user_block(
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001'
  ),
  true,
  'the independent reverse direction remains active'
);
select is(
  private.has_active_user_block_between(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  ),
  true,
  'one remaining direction keeps the symmetric barrier active'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.unblock_user(
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001'
  )::text,
  current_setting('test.blocking_reverse_episode_id'),
  'the reverse blocker can independently unblock'
);
select is(
  public.unblock_user(
    'a9100000-0000-4000-8000-000000000002',
    'a9100000-0000-4000-8000-000000000001'
  )::text,
  current_setting('test.blocking_reverse_episode_id'),
  'an already-unblocked retry is idempotent'
);

select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.blocking_second_episode_id',
  public.block_user(
    'a9100000-0000-4000-8000-000000000001',
    'a9100000-0000-4000-8000-000000000002'
  )::text,
  true
);
select isnt(
  current_setting('test.blocking_second_episode_id'),
  current_setting('test.blocking_first_episode_id'),
  're-blocking creates a distinct history episode'
);

reset role;
select is(
  (
    select count(*)
    from private.user_block_episodes
    where blocker_profile_id = 'a9100000-0000-4000-8000-000000000001'
      and blocked_profile_id = 'a9100000-0000-4000-8000-000000000002'
  ),
  2::bigint,
  'closed block history is preserved beside the new active episode'
);
select throws_ok(
  format(
    'update private.user_block_episodes set unblocked_at = null where id = %L',
    current_setting('test.blocking_first_episode_id')
  ),
  '55000',
  'A closed user block episode cannot be changed or reopened.',
  'closed block history cannot be reopened'
);
select throws_ok(
  format(
    'delete from private.user_block_episodes where id = %L',
    current_setting('test.blocking_first_episode_id')
  ),
  '55000',
  'User block history cannot be deleted.',
  'block history cannot be deleted'
);
select is(
  (
    select count(*)
    from public.project_join_requests
    where id in (
      'a9300000-0000-4000-8000-000000000001',
      'a9300000-0000-4000-8000-000000000002'
    )
      and status in ('rejected', 'withdrawn')
  ),
  2::bigint,
  'unblock and re-block never resurrect prior Project requests'
);
select is(
  (
    select count(*)
    from public.resource_listing_requests
    where id in (
      'a9600000-0000-4000-8000-000000000001',
      'a9600000-0000-4000-8000-000000000002'
    )
      and status in ('rejected', 'withdrawn')
  ),
  2::bigint,
  'unblock and re-block never resurrect prior Resource requests'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action in ('user.blocked', 'user.unblocked')
      and event.target_type = 'user_block_episode'
      and event.metadata ? 'blocker_profile_id'
      and event.metadata ? 'blocked_profile_id'
      and event.metadata - 'blocker_profile_id' - 'blocked_profile_id' = '{}'::jsonb
  ),
  5::bigint,
  'block audit events are identifier-only and record each real transition'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type like '%block%'
      or event.payload::text like '%blocked%'
      or event.payload::text like '%blocking%'
  ),
  0::bigint,
  'blocking creates no block-specific outbox or notification source event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_public_profile(
      'a9100000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'the blocked pair can still resolve public profile data'
);
select is(
  (
    select count(*)
    from public.get_public_proposal(
      'a9200000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'the blocked pair can still resolve public Project data'
);
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      'a9500000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'the blocked pair can still resolve public Resource data'
);

reset role;
update public.profile_photos
set audience = 'public'
where profile_id = 'a9100000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a9100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a9100000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'a public photo remains visible across an active block'
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      'a9200000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'the public contextual Project photo remains visible across a block'
);
select is(
  (
    select count(*)
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      'a9500000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'the public contextual Resource photo remains visible across a block'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select *
    from public.list_own_blocked_profiles(null, 50, null, null)
  $$,
  '42501',
  'permission denied for function list_own_blocked_profiles',
  'anonymous clients cannot call the outbound block read'
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      'a9200000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'anonymous public-context photo behavior remains available'
);

select * from finish();

rollback;
