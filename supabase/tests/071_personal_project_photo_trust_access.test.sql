begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a4000000-0000-4000-8000-000000000001', 'trust-creator@planets.invalid'),
  ('a4000000-0000-4000-8000-000000000002', 'trust-requester-a@planets.invalid'),
  ('a4000000-0000-4000-8000-000000000003', 'trust-requester-b@planets.invalid'),
  ('a4000000-0000-4000-8000-000000000004', 'trust-unrelated@planets.invalid'),
  ('a4000000-0000-4000-8000-000000000005', 'trust-legacy@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a4000000-0000-4000-8000-000000000001', 'Trust Creator'),
  ('a4000000-0000-4000-8000-000000000002', 'Trust Requester A'),
  ('a4000000-0000-4000-8000-000000000003', 'Trust Requester B'),
  ('a4000000-0000-4000-8000-000000000004', 'Unrelated Viewer'),
  ('a4000000-0000-4000-8000-000000000005', 'Legacy Organizer');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.trust_proposal_id',
  public.create_proposal_draft(
    'a4000000-0000-4000-8000-000000000001',
    'Trust Proposal',
    'A complete proposal used to verify contextual trust.',
    'People collaborate in person on one focused local activity.',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '2 days 2 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'Povo',
    'Trento · Povo',
    'Private courtyard entrance',
    'participants',
    array[]::uuid[],
    array[]::text[]
  )::text,
  true
);
select set_config(
  'test.trust_draft_id',
  public.create_proposal_draft(
    'a4000000-0000-4000-8000-000000000001',
    'Private Draft',
    'A complete draft that is not publicly viewable.',
    'This complete content remains owner-only until publication.',
    statement_timestamp() + interval '3 days',
    statement_timestamp() + interval '3 days 2 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'Povo',
    'Trento · Povo',
    'Another private courtyard',
    'participants',
    array[]::uuid[],
    array[]::text[]
  )::text,
  true
);
select set_config(
  'test.trust_tavolo_id',
  public.create_recurring_activity_draft(
    'a4000000-0000-4000-8000-000000000001',
    'Trust Tavolo',
    'A recurring complete activity used for the trust gate.',
    'People meet weekly for a local collaborative discussion.',
    'Community',
    'IT',
    'Trento',
    'Povo',
    'Trento · Povo',
    'Private library room',
    'participants',
    'weekly',
    3,
    null,
    '19:00'::time,
    90,
    'Europe/Rome',
    current_date
  )::text,
  true
);

select lives_ok(
  $$
    select public.update_own_proposal(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_draft_id')::uuid,
      'Private Draft Updated',
      'A complete draft can still be edited without a photo.',
      'This content update proves draft editing remains photo-independent.',
      statement_timestamp() + interval '4 days',
      statement_timestamp() + interval '4 days 2 hours',
      'Europe/Rome',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo',
      'Updated private courtyard',
      'participants',
      array[]::uuid[],
      array[]::text[]
    )
  $$,
  'Proposal drafts remain editable without a profile photo'
);
select lives_ok(
  $$
    select public.update_own_recurring_activity(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_tavolo_id')::uuid,
      'Trust Tavolo Updated',
      'A recurring draft can still be edited without a photo.',
      'This complete update remains a draft until the trust gate passes.',
      'Community',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo',
      'Updated private library room',
      'participants',
      'weekly',
      3,
      null,
      '19:30'::time,
      90,
      'Europe/Rome',
      current_date
    )
  $$,
  'Tavolo drafts remain editable without a profile photo'
);

select throws_ok(
  $$
    select public.publish_proposal(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_proposal_id')::uuid
    )
  $$,
  'PT422',
  'A current profile photo is required for this trust-sensitive action.',
  'a valid Proposal cannot transition to published without a canonical photo'
);
select throws_ok(
  $$
    select public.publish_recurring_activity(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_tavolo_id')::uuid
    )
  $$,
  'PT422',
  'A current profile photo is required for this trust-sensitive action.',
  'a valid Tavolo cannot transition to published without a canonical photo'
);

reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'profile-photos',
    'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000001.webp',
    'a4000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000002.webp',
    'a4000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );
insert into public.profile_photos (profile_id, object_path, audience)
values (
  'a4000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000001.webp',
  'interactions'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_proposal(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_proposal_id')::uuid
    )
  $$,
  'an interactions photo satisfies Proposal publication'
);
reset role;
update public.profile_photos
set audience = 'public'
where profile_id = 'a4000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_recurring_activity(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_tavolo_id')::uuid
    )
  $$,
  'a public photo satisfies Tavolo publication'
);
reset role;
update public.profile_photos
set audience = 'interactions'
where profile_id = 'a4000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'a4000000-0000-4000-8000-000000000002',
      current_setting('test.trust_proposal_id')::uuid,
      'I would like to help.',
      array[]::uuid[],
      array[]::uuid[]
    )
  $$,
  'PT422',
  'A current profile photo is required for this trust-sensitive action.',
  'a new join request cannot be sent without a canonical requester photo'
);

reset role;
insert into public.profile_photos (profile_id, object_path, audience)
values
  (
    'a4000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002/a4100000-0000-4000-8000-000000000003.webp',
    'interactions'
  ),
  (
    'a4000000-0000-4000-8000-000000000003',
    'a4000000-0000-4000-8000-000000000003/a4100000-0000-4000-8000-000000000004.webp',
    'public'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.request_to_join_project(
      'a4000000-0000-4000-8000-000000000002',
      current_setting('test.trust_proposal_id')::uuid,
      'I would like to help.',
      array[]::uuid[],
      array[]::uuid[]
    )
  $$,
  'an interactions photo satisfies the join-request gate'
);
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.request_to_join_project(
      'a4000000-0000-4000-8000-000000000003',
      current_setting('test.trust_tavolo_id')::uuid,
      null,
      array[]::uuid[],
      array[]::uuid[]
    )
  $$,
  'a public photo also satisfies the join-request gate'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select results_eq(
  $$
    select profile_id, object_path
    from public.get_project_creator_profile_photo_for_viewer(
      current_setting('test.trust_proposal_id')::uuid
    )
  $$,
  $$
    values (
      'a4000000-0000-4000-8000-000000000001'::uuid,
      'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000001.webp'::text
    )
  $$,
  'anonymous viewers receive canonical organizer metadata through a public Proposal context'
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      current_setting('test.trust_tavolo_id')::uuid
    )
  ),
  1::bigint,
  'anonymous viewers also receive organizer metadata through a public Tavolo context'
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      current_setting('test.trust_draft_id')::uuid
    )
  ),
  0::bigint,
  'an owner-only draft context leaks no organizer metadata to anonymous callers'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a4000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'public Project ownership does not broaden the generic interactions-photo boundary'
);

select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000001.webp'
  ),
  1::bigint,
  'the canonical organizer object is downloadable in a public Project context'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a4000000-0000-4000-8000-000000000001/a4100000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'an old organizer object remains denied'
);
select set_config('storage.operation', 'object.list', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
  ),
  0::bigint,
  'Project-context delivery does not expose bucket listing'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_project_creator_profile_photo_for_viewer(
      current_setting('test.trust_draft_id')::uuid
    )
  ),
  1::bigint,
  'the organizer may resolve their own draft photo context'
);

reset role;
delete from public.profile_photos
where profile_id = 'a4000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_proposal(
      'a4000000-0000-4000-8000-000000000001',
      current_setting('test.trust_proposal_id')::uuid
    )
  $$,
  'removing a photo after publication does not break the idempotent published no-op'
);

reset role;
insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  starts_at,
  ends_at,
  published_at
)
values (
  'a4200000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000005',
  'published',
  statement_timestamp() + interval '1 day',
  statement_timestamp() + interval '1 day 2 hours',
  statement_timestamp()
);
select is(
  (
    select lifecycle_state
    from public.proposals
    where id = 'a4200000-0000-4000-8000-000000000001'
  ),
  'published',
  'legacy published Projects without a current photo remain canonical history'
);

select * from finish();

rollback;
