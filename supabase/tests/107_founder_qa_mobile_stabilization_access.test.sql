begin;

select no_plan();

insert into auth.users (id, email)
values
  ('f2100000-0000-4000-8000-000000000001', 'qa-creator@planets.invalid'),
  ('f2100000-0000-4000-8000-000000000002', 'qa-cocreator@planets.invalid'),
  ('f2100000-0000-4000-8000-000000000003', 'qa-coorganizer@planets.invalid'),
  ('f2100000-0000-4000-8000-000000000004', 'qa-requester@planets.invalid'),
  ('f2100000-0000-4000-8000-000000000005', 'qa-participant@planets.invalid'),
  ('f2100000-0000-4000-8000-000000000006', 'qa-former-requester@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f2100000-0000-4000-8000-000000000001', 'QA Creator'),
  ('f2100000-0000-4000-8000-000000000002', 'QA Co-creator'),
  ('f2100000-0000-4000-8000-000000000003', 'QA Co-organizer'),
  ('f2100000-0000-4000-8000-000000000004', 'QA Requester'),
  ('f2100000-0000-4000-8000-000000000005', 'QA Participant'),
  ('f2100000-0000-4000-8000-000000000006', 'QA Former Requester');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  event_timezone,
  published_at
)
values (
  'f2200000-0000-4000-8000-000000000001',
  'f2100000-0000-4000-8000-000000000001',
  'published',
  'Founder QA Project',
  statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days',
  'Europe/Rome',
  statement_timestamp() - interval '1 day'
);

insert into storage.objects (bucket_id, name, owner_id, metadata)
select
  'profile-photos',
  profile.id::text || '/f2ff0000-0000-4000-8000-000000000001.webp',
  profile.id::text,
  '{"mimetype":"image/webp","size":64}'::jsonb
from public.profiles as profile
where profile.id between
  'f2100000-0000-4000-8000-000000000001'::uuid
  and 'f2100000-0000-4000-8000-000000000006'::uuid;

insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/f2ff0000-0000-4000-8000-000000000001.webp',
  'interactions'
from public.profiles as profile
where profile.id between
  'f2100000-0000-4000-8000-000000000001'::uuid
  and 'f2100000-0000-4000-8000-000000000006'::uuid;

insert into storage.objects (bucket_id, name, owner_id, metadata)
values (
  'profile-photos',
  'f2100000-0000-4000-8000-000000000004/f2ff0000-0000-4000-8000-000000000099.webp',
  'f2100000-0000-4000-8000-000000000004',
  '{"mimetype":"image/webp","size":64}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.qa_cocreator_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f2100000-0000-4000-8000-000000000001',
      'f2200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  ),
  true
);
select set_config(
  'test.qa_coorganizer_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f2100000-0000-4000-8000-000000000001',
      'f2200000-0000-4000-8000-000000000001',
      'co_organizer'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.qa_cocreator_id',
  public.accept_project_delegate_invitation(
    'f2100000-0000-4000-8000-000000000002',
    current_setting('test.qa_cocreator_token')
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.qa_coorganizer_id',
  public.accept_project_delegate_invitation(
    'f2100000-0000-4000-8000-000000000003',
    current_setting('test.qa_coorganizer_token')
  )::text,
  true
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  (
    'f2300000-0000-4000-8000-000000000001',
    'f2200000-0000-4000-8000-000000000001',
    'f2100000-0000-4000-8000-000000000004',
    'pending',
    'Pending founder QA request',
    statement_timestamp(),
    null,
    null
  ),
  (
    'f2300000-0000-4000-8000-000000000002',
    'f2200000-0000-4000-8000-000000000001',
    'f2100000-0000-4000-8000-000000000005',
    'accepted',
    'Accepted founder QA request',
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '1 hour',
    'f2100000-0000-4000-8000-000000000001'
  ),
  (
    'f2300000-0000-4000-8000-000000000003',
    'f2200000-0000-4000-8000-000000000001',
    'f2100000-0000-4000-8000-000000000006',
    'rejected',
    'Rejected founder QA request',
    statement_timestamp() - interval '3 hours',
    statement_timestamp() - interval '1 hour',
    'f2100000-0000-4000-8000-000000000001'
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'f2400000-0000-4000-8000-000000000001',
  'f2200000-0000-4000-8000-000000000001',
  'f2100000-0000-4000-8000-000000000005',
  'f2300000-0000-4000-8000-000000000002',
  statement_timestamp() - interval '1 hour'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000004'
    )
  ),
  1::bigint,
  'the Creator sees a pending requester interactions photo'
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000004'
    )
  ),
  1::bigint,
  'an active Co-creator sees a pending requester interactions photo'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000005'
    )
  ),
  1::bigint,
  'a current manager sees a current participant interactions photo'
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000004'
    )
  ),
  1::bigint,
  'an active Co-organizer sees a pending requester interactions photo'
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000004',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'a pending requester sees the immutable Creator photo'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'a requester does not gain access to every manager photo'
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000001',
  true
);
select public.revoke_project_delegate(
  'f2100000-0000-4000-8000-000000000001',
  current_setting('test.qa_coorganizer_id')::uuid
);

select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'a revoked delegate immediately loses requester photo access'
);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'f2100000-0000-4000-8000-000000000004/f2ff0000-0000-4000-8000-000000000001.webp'
  ),
  0::bigint,
  'the revoked delegate cannot read the canonical Storage object'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'f2100000-0000-4000-8000-000000000004/f2ff0000-0000-4000-8000-000000000099.webp'
  ),
  0::bigint,
  'a stale guessed Storage object remains denied'
);

reset role;
update public.project_join_requests
set
  status = 'withdrawn',
  resolved_at = statement_timestamp(),
  resolved_by_profile_id = 'f2100000-0000-4000-8000-000000000004'
where id = 'f2300000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f2100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'a withdrawn request leaves no historical photo visibility'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'f2100000-0000-4000-8000-000000000006'
    )
  ),
  0::bigint,
  'a rejected request leaves no historical photo visibility'
);

select * from finish();

rollback;
