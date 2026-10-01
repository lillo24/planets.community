begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a3000000-0000-4000-8000-000000000001', 'photo-viewer-organizer@planets.invalid'),
  ('a3000000-0000-4000-8000-000000000002', 'photo-viewer-subject@planets.invalid'),
  ('a3000000-0000-4000-8000-000000000003', 'photo-viewer-unrelated@planets.invalid'),
  ('a3000000-0000-4000-8000-000000000004', 'photo-viewer-peer@planets.invalid');

insert into public.profiles (id)
values
  ('a3000000-0000-4000-8000-000000000001'),
  ('a3000000-0000-4000-8000-000000000002'),
  ('a3000000-0000-4000-8000-000000000003'),
  ('a3000000-0000-4000-8000-000000000004');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  ends_at,
  published_at
)
values
  (
    'a3100000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'published',
    now() + interval '1 day',
    now()
  ),
  (
    'a3100000-0000-4000-8000-000000000003',
    'a3000000-0000-4000-8000-000000000001',
    'published',
    now() + interval '1 day',
    now()
  );

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  published_at
)
values (
    'a3100000-0000-4000-8000-000000000002',
    'a3000000-0000-4000-8000-000000000001',
    'published',
    now()
  );

insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'profile-photos',
    'a3000000-0000-4000-8000-000000000001/a3200000-0000-4000-8000-000000000001.webp',
    'a3000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp',
    'a3000000-0000-4000-8000-000000000002',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000003.webp',
    'a3000000-0000-4000-8000-000000000002',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a3000000-0000-4000-8000-000000000003/a3200000-0000-4000-8000-000000000004.webp',
    'a3000000-0000-4000-8000-000000000003',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );

select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'a missing canonical photo returns no exact viewer row'
);

insert into public.profile_photos (profile_id, object_path, audience)
values
  (
    'a3000000-0000-4000-8000-000000000002',
    'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp',
    'public'
  ),
  (
    'a3000000-0000-4000-8000-000000000003',
    'a3000000-0000-4000-8000-000000000003/a3200000-0000-4000-8000-000000000004.webp',
    'public'
  ),
  (
    'a3000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001/a3200000-0000-4000-8000-000000000001.webp',
    'interactions'
  );

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('storage.operation', 'object.get_authenticated', true);
select results_eq(
  $$
    select profile_id, object_path
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  $$,
  $$
    values (
      'a3000000-0000-4000-8000-000000000002'::uuid,
      'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'::text
    )
  $$,
  'anonymous viewers receive exact canonical public metadata'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'
  ),
  1::bigint,
  'anonymous exact-object reads can select the canonical public object'
);
select set_config('storage.operation', 'object.list', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
  ),
  0::bigint,
  'public viewer access does not create an anonymous bucket directory'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000004',
  true
);
select results_eq(
  $$
    select profile_id
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  $$,
  $$values ('a3000000-0000-4000-8000-000000000002'::uuid)$$,
  'an unrelated authenticated viewer receives public metadata'
);

reset role;
update public.profile_photos
set audience = 'interactions'
where profile_id = 'a3000000-0000-4000-8000-000000000002';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'anonymous viewers cannot see interactions metadata'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'anonymous viewers cannot read an interactions object by guessed path'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'an unrelated authenticated viewer cannot infer interactions metadata'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'an unrelated authenticated viewer cannot use a guessed canonical path'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'the owner always retains access through the reusable viewer boundary'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'an organizer has no access before a qualifying relationship'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status
)
values (
  'a3300000-0000-4000-8000-000000000001',
  'a3100000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000002',
  'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select profile_id
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  $$,
  $$values ('a3000000-0000-4000-8000-000000000002'::uuid)$$,
  'a Proposal organizer can see a pending requester interactions photo'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'
  ),
  1::bigint,
  'the pending-request organizer can read the canonical Storage object'
);
select results_eq(
  $$
    select profile_id
    from public.list_profile_photos_for_viewer(
      array[
        'a3000000-0000-4000-8000-000000000003'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  $$
    values
      ('a3000000-0000-4000-8000-000000000002'::uuid),
      ('a3000000-0000-4000-8000-000000000003'::uuid)
  $$,
  'the batch RPC deduplicates and orders authorized rows by profile_id'
);
select throws_ok(
  $$select * from public.list_profile_photos_for_viewer(array[]::uuid[])$$,
  '22023',
  'Profile photo viewer batches require between 1 and 50 target IDs.',
  'empty viewer batches are rejected'
);
select throws_ok(
  $$
    select *
    from public.list_profile_photos_for_viewer(
      array_fill(
        'a3000000-0000-4000-8000-000000000002'::uuid,
        array[51]
      )
    )
  $$,
  '22023',
  'Profile photo viewer batches require between 1 and 50 target IDs.',
  'viewer batches larger than 50 are rejected before deduplication'
);
select throws_ok(
  $$
    select *
    from public.list_profile_photos_for_viewer(
      array[null::uuid]
    )
  $$,
  '22023',
  'Profile photo viewer batches cannot contain null target IDs.',
  'viewer batches reject null UUIDs'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status
)
values (
  'a3300000-0000-4000-8000-000000000002',
  'a3100000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000002',
  'pending'
);
update public.project_join_requests
set
  status = 'rejected',
  resolved_at = now(),
  resolved_by_profile_id = 'a3000000-0000-4000-8000-000000000001'
where id = 'a3300000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'another qualifying Tavolo request preserves access after Proposal rejection'
);

reset role;
update public.project_join_requests
set
  status = 'withdrawn',
  resolved_at = now(),
  resolved_by_profile_id = 'a3000000-0000-4000-8000-000000000002'
where id = 'a3300000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'rejected and withdrawn requests leave no historical photo access'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  resolved_at,
  resolved_by_profile_id
)
values (
  'a3300000-0000-4000-8000-000000000003',
  'a3100000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000002',
  'accepted',
  now(),
  'a3000000-0000-4000-8000-000000000001'
);
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'a3400000-0000-4000-8000-000000000001',
  'a3100000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000002',
  'a3300000-0000-4000-8000-000000000003',
  now()
);
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  resolved_at,
  resolved_by_profile_id
)
values (
  'a3300000-0000-4000-8000-000000000004',
  'a3100000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000004',
  'accepted',
  now(),
  'a3000000-0000-4000-8000-000000000001'
);
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'a3400000-0000-4000-8000-000000000002',
  'a3100000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000004',
  'a3300000-0000-4000-8000-000000000004',
  now()
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'the organizer keeps access for a current participant'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000004',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'a current co-participant gains no interactions photo access'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'a current participant can see the immutable Creator photo'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status
)
values (
  'a3300000-0000-4000-8000-000000000005',
  'a3100000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000002',
  'pending'
);
update public.project_memberships
set left_at = now()
where id = 'a3400000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'another pending Project preserves access after a membership is left'
);

reset role;
update public.project_join_requests
set
  status = 'rejected',
  resolved_at = now(),
  resolved_by_profile_id = 'a3000000-0000-4000-8000-000000000001'
where id = 'a3300000-0000-4000-8000-000000000005';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'leaving plus ending the last pending relation revokes access'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  resolved_at,
  resolved_by_profile_id
)
values (
  'a3300000-0000-4000-8000-000000000006',
  'a3100000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000002',
  'accepted',
  now(),
  'a3000000-0000-4000-8000-000000000001'
);
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  removed_at,
  removed_by_profile_id
)
values (
  'a3400000-0000-4000-8000-000000000003',
  'a3100000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000002',
  'a3300000-0000-4000-8000-000000000006',
  now() - interval '1 minute',
  now(),
  'a3000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'a removed membership grants no historical interactions access'
);

reset role;
update public.profile_photos
set
  object_path =
    'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000003.webp',
  audience = 'public'
where profile_id = 'a3000000-0000-4000-8000-000000000002';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'an old still-present object loses cross-user access after replacement'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000003.webp'
  ),
  1::bigint,
  'the replacement canonical public object is immediately readable'
);

reset role;
update public.profile_photos
set audience = 'interactions'
where profile_id = 'a3000000-0000-4000-8000-000000000002';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'a3000000-0000-4000-8000-000000000002/a3200000-0000-4000-8000-000000000003.webp'
  ),
  0::bigint,
  'public-to-interactions revokes unauthorized Storage reads without re-upload'
);

reset role;
delete from public.profile_photos
where profile_id = 'a3000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'a3000000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'removing canonical metadata leaves no viewer row even for the owner'
);

select * from finish();

rollback;
