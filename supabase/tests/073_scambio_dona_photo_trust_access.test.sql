begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b4000000-0000-4000-8000-000000000001', 'resource-trust-owner@planets.invalid'),
  ('b4000000-0000-4000-8000-000000000002', 'resource-trust-public-owner@planets.invalid'),
  ('b4000000-0000-4000-8000-000000000003', 'resource-trust-requester-a@planets.invalid'),
  ('b4000000-0000-4000-8000-000000000004', 'resource-trust-requester-b@planets.invalid'),
  ('b4000000-0000-4000-8000-000000000005', 'resource-trust-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b4000000-0000-4000-8000-000000000001', 'Resource Trust Owner'),
  ('b4000000-0000-4000-8000-000000000002', 'Public Photo Owner'),
  ('b4000000-0000-4000-8000-000000000003', 'Resource Requester A'),
  ('b4000000-0000-4000-8000-000000000004', 'Resource Requester B'),
  ('b4000000-0000-4000-8000-000000000005', 'Unrelated Resource Viewer');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.resource_listing_id',
  public.create_resource_listing_draft(
    'b4000000-0000-4000-8000-000000000001',
    'exchange',
    'Shared tile cutter',
    'A complete Resource listing used for contextual photo trust tests.',
    'IT',
    'Trento',
    'TN',
    'Trento'
  )::text,
  true
);
select lives_ok(
  $$
    select public.update_own_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.resource_listing_id')::uuid,
      'exchange',
      'Shared tile cutter updated',
      'A draft remains editable before the owner has a profile photo.',
      'IT',
      'Trento',
      'TN',
      'Trento'
    )
  $$,
  'Resource listing drafts remain editable without a profile photo'
);
select throws_ok(
  $$
    select public.publish_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.resource_listing_id')::uuid
    )
  $$,
  'PT422',
  'A current profile photo is required for this trust-sensitive action.',
  'a valid Resource listing cannot publish without a canonical owner photo'
);

reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata)
values
  (
    'profile-photos',
    'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000001.webp',
    'b4000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  ),
  (
    'profile-photos',
    'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000002.webp',
    'b4000000-0000-4000-8000-000000000001',
    '{"mimetype":"image/webp","size":64}'::jsonb
  );
insert into public.profile_photos (profile_id, object_path, audience)
values (
  'b4000000-0000-4000-8000-000000000001',
  'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000001.webp',
  'interactions'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.resource_listing_id')::uuid
    )
  $$,
  'an interactions photo satisfies Resource listing publication'
);

reset role;
insert into public.resource_listings (
  id,
  owner_profile_id,
  listing_mode,
  lifecycle_state,
  title,
  description,
  country_code,
  locality,
  public_location_label
)
values (
  'b4200000-0000-4000-8000-000000000001',
  'b4000000-0000-4000-8000-000000000001',
  'donate',
  'draft',
  'Private draft',
  'This listing is not publicly visible.',
  'IT',
  'Trento',
  'Trento'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select results_eq(
  $$
    select profile_id, object_path
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      current_setting('test.resource_listing_id')::uuid
    )
  $$,
  $$
    values (
      'b4000000-0000-4000-8000-000000000001'::uuid,
      'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000001.webp'::text
    )
  $$,
  'anonymous public detail resolves the current contextual owner photo'
);
select is(
  (
    select count(*)
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      'b4200000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'a draft listing leaks no contextual owner photo to anonymous callers'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'public listing ownership does not broaden generic interactions-photo access'
);
select set_config('storage.operation', 'object.get_authenticated', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000001.webp'
  ),
  1::bigint,
  'the canonical owner object downloads through public listing context'
);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
      and name =
        'b4000000-0000-4000-8000-000000000001/b4100000-0000-4000-8000-000000000002.webp'
  ),
  0::bigint,
  'a replaced owner object remains denied'
);
select set_config('storage.operation', 'object.list', true);
select is(
  (
    select count(*)
    from storage.objects
    where bucket_id = 'profile-photos'
  ),
  0::bigint,
  'Resource listing context does not expose bucket listing'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000005',
  true
);
select is(
  (
    select count(*)
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      current_setting('test.resource_listing_id')::uuid
    )
  ),
  1::bigint,
  'an authenticated unrelated viewer receives the same public listing context'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'b4000000-0000-4000-8000-000000000003',
      current_setting('test.resource_listing_id')::uuid,
      'I can coordinate locally.'
    )
  $$,
  'PT422',
  'A current profile photo is required for this trust-sensitive action.',
  'a new Resource request cannot be sent without a canonical requester photo'
);

reset role;
insert into public.profile_photos (profile_id, object_path, audience)
values
  (
    'b4000000-0000-4000-8000-000000000003',
    'b4000000-0000-4000-8000-000000000003/b4100000-0000-4000-8000-000000000003.webp',
    'interactions'
  ),
  (
    'b4000000-0000-4000-8000-000000000004',
    'b4000000-0000-4000-8000-000000000004/b4100000-0000-4000-8000-000000000004.webp',
    'interactions'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.resource_request_id',
  public.request_resource_listing(
    'b4000000-0000-4000-8000-000000000003',
    current_setting('test.resource_listing_id')::uuid,
    'I can coordinate locally.'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'pending Resource request authorizes owner-to-requester interactions photo access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'pending Resource request alone grants no reverse generic interaction access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000005',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'an unrelated viewer receives no interactions requester photo'
);

-- Rejection, withdrawal, and listing closure each revoke the directional
-- pending relationship. These are separate attempts so no terminal episode is
-- rewritten to exercise another transition.
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.rejected_request_id',
  public.request_resource_listing(
    'b4000000-0000-4000-8000-000000000004',
    current_setting('test.resource_listing_id')::uuid,
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.reject_resource_listing_request(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.rejected_request_id')::uuid
    )
  $$,
  'the owner rejects a separate pending request'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'rejection revokes owner-to-requester photo access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.withdrawn_request_id',
  public.request_resource_listing(
    'b4000000-0000-4000-8000-000000000004',
    current_setting('test.resource_listing_id')::uuid,
    null
  )::text,
  true
);
select lives_ok(
  $$
    select public.withdraw_resource_listing_request(
      'b4000000-0000-4000-8000-000000000004',
      current_setting('test.withdrawn_request_id')::uuid
    )
  $$,
  'the requester withdraws a separate pending request'
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'withdrawal revokes owner-to-requester photo access'
);

select set_config(
  'test.closing_listing_id',
  public.create_resource_listing_draft(
    'b4000000-0000-4000-8000-000000000001',
    'donate',
    'Closing pending relationship',
    'A separate listing proves pending closure revokes photo access.',
    'IT',
    'Trento',
    null,
    'Trento'
  )::text,
  true
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.closing_listing_id')::uuid
    )
  $$,
  'the owner publishes a separate listing for pending closure'
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.closed_request_id',
  public.request_resource_listing(
    'b4000000-0000-4000-8000-000000000004',
    current_setting('test.closing_listing_id')::uuid,
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.closing_listing_id')::uuid
    )
  $$,
  'listing closure transitions a separate pending request'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'listing_closed revokes owner-to-requester photo access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.accept_resource_listing_request(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.resource_request_id')::uuid
    )
  $$,
  'the owner canonically accepts the pending request'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'accepted open coordination retains owner-to-requester access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'accepted open coordination authorizes requester-to-owner access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'b4000000-0000-4000-8000-000000000001',
      current_setting('test.resource_listing_id')::uuid
    )
  $$,
  'the accepted listing can close without closing coordination'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'listing closure does not prematurely revoke accepted/open access'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (
    select count(*)
    from public.get_resource_listing_owner_profile_photo_for_viewer(
      current_setting('test.resource_listing_id')::uuid
    )
  ),
  0::bigint,
  'a closed listing no longer exposes public contextual owner metadata'
);

reset role;
select set_config(
  'test.resource_agreement_id',
  (
    select agreement.id::text
    from public.resource_exchange_agreements as agreement
    where agreement.request_id = current_setting('test.resource_request_id')::uuid
  ),
  true
);

-- A second accepted/open episode proves revocation is relationship-composed:
-- closing one episode must not erase access still justified by another.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.secondary_listing_id',
  public.create_resource_listing_draft(
    'b4000000-0000-4000-8000-000000000001',
    'exchange',
    'Second accepted relationship',
    'A separate episode proves Resource photo authorization composes.',
    'IT',
    'Trento',
    null,
    'Trento'
  )::text,
  true
);
select public.publish_resource_listing(
  'b4000000-0000-4000-8000-000000000001',
  current_setting('test.secondary_listing_id')::uuid
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.secondary_request_id',
  public.request_resource_listing(
    'b4000000-0000-4000-8000-000000000003',
    current_setting('test.secondary_listing_id')::uuid,
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'b4000000-0000-4000-8000-000000000001',
  current_setting('test.secondary_request_id')::uuid
);
reset role;
select set_config(
  'test.secondary_agreement_id',
  (
    select agreement.id::text
    from public.resource_exchange_agreements as agreement
    where agreement.request_id =
      current_setting('test.secondary_request_id')::uuid
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.cancel_resource_exchange_agreement(
      'b4000000-0000-4000-8000-000000000003',
      current_setting('test.resource_agreement_id')::uuid
    )
  $$,
  'a counterparty canonically closes accepted coordination'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'closing one coordination preserves access from another accepted/open relationship'
);
select lives_ok(
  $$
    select public.cancel_resource_exchange_agreement(
      'b4000000-0000-4000-8000-000000000003',
      current_setting('test.secondary_agreement_id')::uuid
    )
  $$,
  'the requester closes the second accepted coordination'
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'closing the last qualifying coordination ends requester-to-owner access'
);

select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_profile_photo_for_viewer(
      'b4000000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'closing the last qualifying coordination ends owner-to-requester Scambio access'
);

-- A second owner proves that public photos satisfy publication and that the
-- already-published path stays idempotent after later photo removal.
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.public_photo_listing_id',
  public.create_resource_listing_draft(
    'b4000000-0000-4000-8000-000000000002',
    'donate',
    'Public-photo listing',
    'A complete listing used to prove both photo audiences satisfy the gate.',
    'IT',
    'Trento',
    null,
    'Trento'
  )::text,
  true
);
reset role;
insert into public.profile_photos (profile_id, object_path, audience)
values (
  'b4000000-0000-4000-8000-000000000002',
  'b4000000-0000-4000-8000-000000000002/b4100000-0000-4000-8000-000000000005.webp',
  'public'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'b4000000-0000-4000-8000-000000000002',
      current_setting('test.public_photo_listing_id')::uuid
    )
  $$,
  'a public photo satisfies Resource listing publication'
);
reset role;
delete from public.profile_photos
where profile_id = 'b4000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b4000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'b4000000-0000-4000-8000-000000000002',
      current_setting('test.public_photo_listing_id')::uuid
    )
  $$,
  'photo removal does not break the already-published idempotent no-op'
);

select * from finish();

rollback;
