begin;
select no_plan();

select ok((select relrowsecurity from pg_class where oid='private.profile_photo_thumbnails'::regclass), 'thumbnail metadata has RLS');
select ok(not has_table_privilege('authenticated','private.profile_photo_thumbnails','SELECT'), 'clients cannot read thumbnail metadata tables');
select ok(not has_function_privilege('anon','public.set_own_profile_photo_v2(uuid,text,text,text)','EXECUTE'), 'guests cannot commit thumbnails');
select ok(has_function_privilege('anon','public.get_profile_photo_for_viewer_v2(uuid)','EXECUTE'), 'exact public reads remain deliberate');
select ok(not has_function_privilege('service_role','public.set_own_profile_photo_v2(uuid,text,text,text)','EXECUTE'), 'no accidental service RPC grant');

insert into auth.users(id,email) values
 ('f8100000-0000-4000-8000-000000000001','img01-owner@planets.invalid');
insert into public.profiles(id) values ('f8100000-0000-4000-8000-000000000001');
insert into storage.objects(bucket_id,name,owner_id,metadata)
select 'profile-photos', 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-'||lpad(n::text,12,'0')||'.webp',
 'f8100000-0000-4000-8000-000000000001', jsonb_build_object('mimetype','image/webp','size',case when n=3 then 32769 else 64 end)
from generate_series(1,4) n;

set local role authenticated;
select set_config('request.jwt.claim.sub','f8100000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.set_own_profile_photo_v2('f8100000-0000-4000-8000-000000000001',
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000001.webp','public',
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000003.webp')$$,
 '22023','The uploaded thumbnail must be owner-owned WebP of at most 32768 bytes.','oversized thumbnail cannot commit');
select lives_ok($$select public.set_own_profile_photo_v2('f8100000-0000-4000-8000-000000000001',
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000001.webp','public',
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000002.webp')$$,'owner commits a pair atomically');
select is((select thumbnail_object_path from public.get_own_profile_photo_v2('f8100000-0000-4000-8000-000000000001')),
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000002.webp','owner sees the bound small path');

reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((select count(*) from public.get_profile_photo_for_viewer_v2('f8100000-0000-4000-8000-000000000001')),1::bigint,'public exact v2 read succeeds');
select ok(public.can_read_profile_photo_thumbnail_object('f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000002.webp'),'public small authorization follows current full');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','f8100000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.set_own_profile_photo('f8100000-0000-4000-8000-000000000001',
 'f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000004.webp','public')$$,'old-client photo replacement remains valid');
select is((select thumbnail_object_path from public.get_own_profile_photo_v2('f8100000-0000-4000-8000-000000000001')),null::text,'old-client replacement cannot retain an unrelated thumbnail');
reset role;
select is((select count(*) from private.profile_photo_thumbnails where profile_id='f8100000-0000-4000-8000-000000000001'),0::bigint,'replaced thumbnail metadata is removed');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select ok(not public.can_read_profile_photo_thumbnail_object('f8100000-0000-4000-8000-000000000001/f8200000-0000-4000-8000-000000000002.webp'),'old small bytes are no longer authorized');
select * from finish();
rollback;
