begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'profile-photo-a@planets.invalid'),
  ('a1000000-0000-4000-8000-000000000002', 'profile-photo-b@planets.invalid'),
  ('a1000000-0000-4000-8000-000000000003', 'profile-photo-c@planets.invalid');

insert into public.profiles (id)
values
  ('a1000000-0000-4000-8000-000000000001'),
  ('a1000000-0000-4000-8000-000000000002'),
  ('a1000000-0000-4000-8000-000000000003');

-- Storage API behavior is verified by the real local integration. These
-- transaction-local metadata rows isolate the RPC's exact existence/owner
-- checks without treating direct SQL as an application object-write path.
insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'profile-photos',
    'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp',
    'a1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000002.webp',
    'a1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000003.webp',
    'a1000000-0000-4000-8000-000000000002',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'a1000000-0000-4000-8000-000000000003/33000000-0000-4000-8000-000000000001.webp',
    'a1000000-0000-4000-8000-000000000003',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );

set local role anon;

select throws_ok(
  $$select public.get_own_profile_photo('a1000000-0000-4000-8000-000000000001')$$,
  '42501',
  'permission denied for function get_own_profile_photo',
  'anonymous callers cannot read owner photo metadata'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
  ),
  0::bigint,
  'anonymous callers cannot see private profile-photo objects'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select count(*)
    from public.get_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'an owner with no canonical photo receives an empty owner read'
);
select throws_ok(
  $$
    select public.get_own_profile_photo(
      'a1000000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected profile.',
  'expected-profile binding rejects cross-account owner reads'
);
select throws_ok(
  $$select * from public.profile_photos$$,
  '42501',
  'permission denied for table profile_photos',
  'authenticated clients cannot bypass the RPC-only metadata boundary'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp',
      'friends'
    )
  $$,
  '22023',
  'Profile photo audience must be public or interactions.',
  'unsupported photo audiences are rejected'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/nested/11000000-0000-4000-8000-000000000001.webp',
      'interactions'
    )
  $$,
  '22023',
  'Profile photo object path is invalid for the expected profile.',
  'nested object paths are rejected'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/avatar.webp',
      'interactions'
    )
  $$,
  '22023',
  'Profile photo object path is invalid for the expected profile.',
  'mutable avatar filenames are rejected'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000002/22000000-0000-4000-8000-000000000001.webp',
      'interactions'
    )
  $$,
  '22023',
  'Profile photo object path is invalid for the expected profile.',
  'another profile prefix is rejected before Storage lookup'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000099.webp',
      'interactions'
    )
  $$,
  '55000',
  'The uploaded profile photo object is unavailable.',
  'a valid-looking but missing Storage object is rejected'
);
select throws_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000003.webp',
      'interactions'
    )
  $$,
  '42501',
  'The uploaded profile photo object is not owned by the expected profile.',
  'canonical commit rejects an exact-path object owned by another user'
);

select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
  ),
  2::bigint,
  'Storage SELECT exposes only user A owner-bound paths'
);
select lives_ok(
  $$
    update storage.objects
    set name = 'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000009.webp'
    where bucket_id = 'profile-photos'
      and name = 'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp'
  $$,
  'no UPDATE policy leaves immutable owner paths unchanged rather than writable'
);

select results_eq(
  $$
    select current_object_path, previous_object_path, audience
    from public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp',
      'interactions'
    )
  $$,
  $$
    values (
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp'::text,
      null::text,
      'interactions'::text
    )
  $$,
  'the first canonical commit stores the private-default audience with no prior path'
);
select results_eq(
  $$
    select profile_id, object_path, audience
    from public.get_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    values (
      'a1000000-0000-4000-8000-000000000001'::uuid,
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp'::text,
      'interactions'::text
    )
  $$,
  'the owner read returns only canonical object-path metadata'
);

reset role;
select set_config(
  'test.profile_photo_created_at',
  (
    select created_at::text
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.profile_photo_updated_at',
  (
    select updated_at::text
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  true
);
select pg_sleep(0.002);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select audience
    from public.set_own_profile_photo_audience(
      'a1000000-0000-4000-8000-000000000001',
      'public'
    )
  $$,
  $$values ('public'::text)$$,
  'the owner can change only the photo audience'
);

reset role;
select is(
  (
    select created_at
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  current_setting('test.profile_photo_created_at')::timestamptz,
  'audience changes preserve the canonical creation time'
);
select ok(
  (
    select updated_at > current_setting('test.profile_photo_updated_at')::timestamptz
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  'audience changes advance updated_at'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select current_object_path, previous_object_path, audience
    from public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000002.webp',
      'public'
    )
  $$,
  $$
    values (
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000002.webp'::text,
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001.webp'::text,
      'public'::text
    )
  $$,
  'replacement atomically returns the prior object path for API cleanup'
);
select results_eq(
  $$
    select previous_object_path
    from public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000002.webp',
      'interactions'
    )
  $$,
  $$values (null::text)$$,
  'recommitting the same path never asks the caller to delete the current object'
);
select is(
  public.clear_own_profile_photo(
    'a1000000-0000-4000-8000-000000000001'
  ),
  'a1000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000002.webp',
  'clear returns the current object path for separate Storage API deletion'
);
select is(
  public.clear_own_profile_photo(
    'a1000000-0000-4000-8000-000000000001'
  ),
  null::text,
  'clearing an already-empty canonical photo is idempotent'
);

reset role;
select is(
  (
    select count(*)
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'clear removes canonical metadata immediately'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name like 'a1000000-0000-4000-8000-000000000001/%'
  ),
  3::bigint,
  'metadata replacement and clear never delete Storage objects with SQL'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.set_own_profile_photo(
      'a1000000-0000-4000-8000-000000000003',
      'a1000000-0000-4000-8000-000000000003/33000000-0000-4000-8000-000000000001.webp',
      'interactions'
    )
  $$,
  'a separate profile can commit its own Storage object'
);

reset role;
delete from public.profiles
where id = 'a1000000-0000-4000-8000-000000000003';
select is(
  (
    select count(*)
    from public.profile_photos
    where profile_id = 'a1000000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'profile deletion cascades canonical photo metadata'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name = 'a1000000-0000-4000-8000-000000000003/33000000-0000-4000-8000-000000000001.webp'
  ),
  1::bigint,
  'profile deletion leaves physical-object cleanup to the Storage API worker boundary'
);

select * from finish();

rollback;
