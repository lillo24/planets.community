begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('c1000000-0000-4000-8000-000000000001', 'cover-owner-a@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000002', 'cover-owner-b@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('c1000000-0000-4000-8000-000000000001', 'Cover Owner A'),
  ('c1000000-0000-4000-8000-000000000002', 'Cover Owner B');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.cover_proposal_id',
  public.create_proposal_draft(
    'c1000000-0000-4000-8000-000000000001',
    'Cover Proposal',
    'A complete proposal used to verify optional cover media.',
    'People collaborate locally while cover access remains lifecycle-aware.',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '2 days 2 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'TN',
    'Trento',
    'Private meeting point',
    'participants',
    array[]::uuid[],
    array[]::text[]
  )::text,
  true
);
select set_config(
  'test.cover_tavolo_id',
  public.create_recurring_activity_draft(
    'c1000000-0000-4000-8000-000000000001',
    'Cover Tavolo',
    'A complete Tavolo used to verify shared Project cover media.',
    'People meet weekly for a local collaborative activity.',
    'Community',
    'IT',
    'Trento',
    'TN',
    'Trento',
    'Private recurring meeting point',
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
select set_config(
  'test.cover_resource_id',
  public.create_resource_listing_draft(
    'c1000000-0000-4000-8000-000000000001',
    'donate',
    'Covered tile cutter',
    'A complete listing used to verify optional Resource cover media.',
    'IT',
    'Trento',
    'TN',
    'Trento'
  )::text,
  true
);

select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select set_config(
  'test.cover_other_resource_id',
  public.create_resource_listing_draft(
    'c1000000-0000-4000-8000-000000000002',
    'exchange',
    'Other covered tool',
    'A second owner listing used to verify tenant isolation.',
    'IT',
    'Trento',
    'TN',
    'Trento'
  )::text,
  true
);

reset role;
update public.projects
set registration_capacity = 12
where id in (
  current_setting('test.cover_proposal_id')::uuid,
  current_setting('test.cover_tavolo_id')::uuid
);

insert into public.profile_photos (profile_id, object_path, audience)
values (
  'c1000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001/c1100000-0000-4000-8000-000000000001.webp',
  'interactions'
);

-- Storage API behavior is also exercised through the local HTTP verifier. These
-- transaction-local rows isolate canonical commit and RLS behavior in pgTAP.
insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'cover-images',
    'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000001.webp',
    'c1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'cover-images',
    'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp',
    'c1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'cover-images',
    'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000003.webp',
    'c1000000-0000-4000-8000-000000000002',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'cover-images',
    'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_tavolo_id') || '/c1200000-0000-4000-8000-000000000004.webp',
    'c1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'cover-images',
    'c1000000-0000-4000-8000-000000000001/resources/' || current_setting('test.cover_resource_id') || '/c1200000-0000-4000-8000-000000000005.webp',
    'c1000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );

set local role anon;
select throws_ok(
  $$select public.get_own_project_cover('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_proposal_id')::uuid)$$,
  '42501',
  'permission denied for function get_own_project_cover',
  'anonymous callers cannot read owner cover metadata'
);
select is(
  (select count(*) from storage.objects where bucket_id = 'cover-images'),
  0::bigint,
  'draft cover objects are private to anonymous callers'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select is(
  (
    select count(*)
    from public.get_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid
    )
  ),
  0::bigint,
  'an editable parent with no canonical cover returns an empty owner read'
);
select throws_ok(
  $$select * from public.project_covers$$,
  '42501',
  'permission denied for table project_covers',
  'authenticated clients cannot bypass the Project cover RPC boundary'
);
select throws_ok(
  $$
    select public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_tavolo_id') || '/c1200000-0000-4000-8000-000000000004.webp'
    )
  $$,
  '22023',
  'The cover object path is invalid for the expected Project.',
  'a same-owner path bound to another Project is rejected'
);
select throws_ok(
  $$
    select public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000099.webp'
    )
  $$,
  '55000',
  'The uploaded cover object is unavailable.',
  'a valid-looking missing object is rejected'
);
select throws_ok(
  $$
    select public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000003.webp'
    )
  $$,
  '42501',
  'The uploaded cover object is not owned by the expected profile.',
  'canonical commit rejects an exact-path object owned by another account'
);
select throws_ok(
  $$
    select public.set_own_resource_listing_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_other_resource_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/resources/' || current_setting('test.cover_other_resource_id') || '/c1200000-0000-4000-8000-000000000006.webp'
    )
  $$,
  '42501',
  'The current user does not own this Resource listing.',
  'an owner cannot attach a cover to another account parent'
);

select results_eq(
  $$
    select current_object_path, previous_object_path
    from public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000001.webp'
    )
  $$,
  $$
    values (
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000001.webp',
      null::text
    )
  $$,
  'the first Project commit returns the canonical path and no prior version'
);
select results_eq(
  $$
    select current_object_path, previous_object_path
    from public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp'
    )
  $$,
  $$
    values (
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp',
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000001.webp'
    )
  $$,
  'replacement atomically returns the prior Project object for separate API cleanup'
);
select is(
  (
    select previous_object_path
    from public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp'
    )
  ),
  null::text,
  'recommitting the current Project path never marks it for deletion'
);
select lives_ok(
  $$
    select public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_tavolo_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_tavolo_id') || '/c1200000-0000-4000-8000-000000000004.webp'
    )
  $$,
  'the shared Project cover API supports Tavoli'
);
select lives_ok(
  $$
    select public.set_own_resource_listing_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_resource_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/resources/' || current_setting('test.cover_resource_id') || '/c1200000-0000-4000-8000-000000000005.webp'
    )
  $$,
  'the Resource canonical commit accepts its exact owned object'
);

-- A cover remains optional: each complete parent publishes through its existing
-- trust gate, independently of whether cover metadata is present.
select lives_ok(
  $$select public.publish_proposal('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_proposal_id')::uuid)$$,
  'a Proposal with a cover publishes through the unchanged lifecycle RPC'
);
select lives_ok(
  $$select public.publish_recurring_activity('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_tavolo_id')::uuid)$$,
  'a Tavolo with a cover publishes through the unchanged lifecycle RPC'
);
select lives_ok(
  $$select public.publish_resource_listing('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_resource_id')::uuid)$$,
  'a Resource listing with a cover publishes through the unchanged lifecycle RPC'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (
    select cover_object_path
    from public.get_public_proposal(current_setting('test.cover_proposal_id')::uuid)
  ),
  'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp',
  'public Proposal detail exposes only the nullable canonical object path'
);
select is(
  (
    select cover_object_path
    from public.get_public_recurring_activity(
      current_setting('test.cover_tavolo_id')::uuid,
      12,
      statement_timestamp()
    )
  ),
  'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_tavolo_id') || '/c1200000-0000-4000-8000-000000000004.webp',
  'public Tavolo detail exposes its shared Project canonical path'
);
select is(
  (
    select cover_object_path
    from public.get_public_resource_listing(current_setting('test.cover_resource_id')::uuid)
  ),
  'c1000000-0000-4000-8000-000000000001/resources/' || current_setting('test.cover_resource_id') || '/c1200000-0000-4000-8000-000000000005.webp',
  'public Resource detail exposes only the nullable canonical object path'
);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (select count(*) from storage.objects where bucket_id = 'cover-images'),
  3::bigint,
  'anonymous exact-download context sees only the three current public canonical covers'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'cover-images'
      and name like '%c1200000-0000-4000-8000-000000000001.webp'
  ),
  0::bigint,
  'a replaced immutable version is not publicly readable'
);
select set_config('storage.operation', 'object.list', true);
select is(
  (select count(*) from storage.objects where bucket_id = 'cover-images'),
  0::bigint,
  'public canonical download access never grants bucket listing'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select is(
  public.clear_own_project_cover(
    'c1000000-0000-4000-8000-000000000001',
    current_setting('test.cover_proposal_id')::uuid
  ),
  'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000002.webp',
  'clear removes canonical metadata and returns the object for separate API deletion'
);
select is(
  public.clear_own_project_cover(
    'c1000000-0000-4000-8000-000000000001',
    current_setting('test.cover_proposal_id')::uuid
  ),
  null::text,
  'clearing an already-empty editable cover is idempotent'
);

reset role;
set local role anon;
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'cover-images'
      and name like '%c1200000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'cleared metadata immediately revokes public object access'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.cancel_proposal('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_proposal_id')::uuid)$$,
  'the Proposal can enter its existing terminal state'
);
select lives_ok(
  $$select public.end_recurring_activity('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_tavolo_id')::uuid)$$,
  'the Tavolo can enter its existing terminal state'
);
select lives_ok(
  $$select public.close_resource_listing('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_resource_id')::uuid)$$,
  'the Resource listing can enter its existing terminal state'
);
select throws_ok(
  $$
    select public.set_own_project_cover(
      'c1000000-0000-4000-8000-000000000001',
      current_setting('test.cover_proposal_id')::uuid,
      'c1000000-0000-4000-8000-000000000001/projects/' || current_setting('test.cover_proposal_id') || '/c1200000-0000-4000-8000-000000000001.webp'
    )
  $$,
  '55000',
  'This Project cover can no longer be edited.',
  'cancelled Proposal covers cannot be attached or replaced'
);
select throws_ok(
  $$select public.clear_own_project_cover('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_tavolo_id')::uuid)$$,
  '55000',
  'This Project cover can no longer be edited.',
  'ended Tavolo covers cannot be cleared'
);
select throws_ok(
  $$select public.clear_own_resource_listing_cover('c1000000-0000-4000-8000-000000000001', current_setting('test.cover_resource_id')::uuid)$$,
  '55000',
  'This Resource listing cover can no longer be edited.',
  'closed Resource covers cannot be cleared'
);

select * from finish();
rollback;
