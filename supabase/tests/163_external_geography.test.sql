begin;
select no_plan();
select is(public.list_external_activities_v3()->>'scope','external_activities','External scope is explicitly namespaced');
select is(public.list_external_activities_v3()->>'state','unconfigured','No implicit map source activation');
select ok(not has_table_privilege(r,'private.external_catalogue_cursor_key','SELECT,INSERT,UPDATE,DELETE'),r||' cannot obtain or rotate cursor key') from unnest(array['anon','authenticated','service_role']) r;
select ok(not has_function_privilege(r,'private.external_catalogue_cursor_signature(jsonb)','EXECUTE'),r||' cannot sign arbitrary cursors') from unnest(array['anon','authenticated','service_role']) r;
select ok(has_function_privilege(r,'public.list_external_activities_v3(text,text,text,text,date,date,integer,jsonb,jsonb,boolean)','EXECUTE'),r||' can read canonical public external geography') from unnest(array['anon','authenticated']) r;
select ok(exists(select 1 from pg_indexes where schemaname='private' and indexname='external_activities_geo_radius'),'Canonical geography GiST index exists');
select ok(exists(select 1 from pg_indexes where schemaname='private' and indexname='external_activities_geo_bounds'),'Bounds expression GiST index exists');
insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
 values('synthetic-geo-a','Synthetic geo A','https://geo.example.org',true,true,'Synthetic only','https://geo.example.org/license'),
 ('synthetic-geo-b','Synthetic geo B','https://geo.example.org',true,true,'Synthetic only','https://geo.example.org/license');
create function pg_temp.point(p_lat numeric,p_lon numeric,p_precision text default 'venue') returns jsonb language sql as $$
 select jsonb_build_object('latitude',p_lat,'longitude',p_lon,'precision',p_precision,'provenance_url','https://geo.example.org/data')
$$;
create function pg_temp.geo_record(p_id text,p_geometry jsonb,p_kind text default 'place') returns jsonb language sql as $$
 select jsonb_build_object('upstream_id',p_id,'kind',p_kind,'title',p_id,'description','Synthetic public source only',
  'canonical_url','https://geo.example.org/item','category','sports','discipline',case p_kind when 'course' then 'yoga' when 'event' then 'running' else 'basketball' end,
  'source_categories','[]'::jsonb,'status','scheduled','publishable',true,'geometry',p_geometry,
  'schedule',case when p_kind='course' then jsonb_build_object('season_start',(now() at time zone 'UTC')::date-1,'season_end',(now() at time zone 'UTC')::date+30,'timezone','UTC') end,
  'occurrences',case when p_kind='event' then jsonb_build_array(jsonb_build_object('kind','timed','start',now()+interval '1 day','end',null,'timezone','UTC')) else '[]'::jsonb end)
$$;
select set_config('test.geo_a',public.begin_external_activity_import('synthetic-geo-a')->>'run_id',true);
select lives_ok($$select public.finish_external_activity_import(current_setting('test.geo_a')::uuid,'success',jsonb_build_array(
 pg_temp.geo_record('center-one',pg_temp.point(46.0748,11.1217)),
 pg_temp.geo_record('center-two',pg_temp.point(46.0748,11.1217)),
 pg_temp.geo_record('locality',pg_temp.point(46.0748,11.1217,'locality')),
 pg_temp.geo_record('unmapped',null),
 pg_temp.geo_record('outside',pg_temp.point(46.4,11.1217)),
 pg_temp.geo_record('west-edge',pg_temp.point(46.0748,11.12)),
 pg_temp.geo_record('cancelled',pg_temp.point(46.0748,11.1217))||'{"status":"cancelled"}',
 pg_temp.geo_record('expired',pg_temp.point(46.0748,11.1217)),
 pg_temp.geo_record('unpublished',pg_temp.point(46.0748,11.1217))||'{"publishable":false}',
 pg_temp.geo_record('current-course',pg_temp.point(46.0748,11.1217),'course'),
 pg_temp.geo_record('future-event',pg_temp.point(46.0748,11.1217),'event')),11)$$,'Canonical import installs geometry for every supported kind');
select set_config('test.geo_b',public.begin_external_activity_import('synthetic-geo-b')->>'run_id',true);
select lives_ok($$select public.finish_external_activity_import(current_setting('test.geo_b')::uuid,'success',jsonb_build_array(pg_temp.geo_record('center-three',pg_temp.point(46.0748,11.1217))),1)$$,'Second source shares a coordinate but keeps distinct identity');
update private.external_activities set last_observed_at=now()-interval '31 days' where upstream_id='expired';
select is(jsonb_array_length(public.list_external_activities_v3()->'items'),9,'List retains the valid record without geometry');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true)->'items'),8,'Map is exactly the mapped eligible subset');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true,p_area=>'{"mode":"radius","latitude":46.0748,"longitude":11.1217,"radius_m":5000}')->'items'),7,'Geodesic radius excludes the published outside point');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true,p_area=>'{"mode":"bounds","south":46.07,"west":11.12,"north":46.08,"east":11.13}')->'items'),7,'Inclusive bounds include the west-edge point');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true,p_kind=>'place',p_discipline=>'basketball',p_query=>'center')->'items'),3,'Complete kind/discipline/literal query predicates apply before map paging');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true,p_from=>now()::date,p_to=>now()::date+3)->'items'),1,'Date scope excludes undated places and unknown next lessons');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true,p_kind=>'course')->'items'),1,'Current course with unknown next session follows the same catalogue policy');
select is((select (x->>'distance_m')::integer from jsonb_array_elements(public.list_external_activities_v3(p_map_only=>true,p_query=>'center-one',p_area=>'{"mode":"radius","latitude":46.0748,"longitude":11.1217,"radius_m":5000}')->'items') x),0,'Venue distance is from the explicit reference');
select is((select x->'distance_m' from jsonb_array_elements(public.list_external_activities_v3(p_map_only=>true,p_query=>'locality',p_area=>'{"mode":"radius","latitude":46.0748,"longitude":11.1217,"radius_m":5000}')->'items') x),'null'::jsonb,'Locality point is never given exact venue distance');
select is(jsonb_array_length(public.list_external_activities_v3(p_query=>'west-edge',p_area=>jsonb_build_object('mode','radius','latitude',46.0748,'longitude',11.1217,'radius_m',
 (select extensions.st_distance(published_point,extensions.st_setsrid(extensions.st_makepoint(11.1217,46.0748),4326)::extensions.geography) from private.external_activities where upstream_id='west-edge')))->'items'),1,'Radius includes a point exactly on its geodesic distance boundary');
select ok((select bool_and(x->>'map_identity'='external_activity:'||(x->>'id')) from jsonb_array_elements(public.list_external_activities_v3(p_map_only=>true)->'items') x),'Map identity cannot be routed as native identity');
select set_config('test.geo_cursor',(public.list_external_activities_v3(p_map_only=>true,p_limit=>1)->'next_cursor')::text,true);
select set_config('test.geo_first',public.list_external_activities_v3(p_map_only=>true,p_limit=>1)->'items'->0->>'id',true);
select set_config('test.geo_expired',((current_setting('test.geo_cursor')::jsonb-'signature')||jsonb_build_object('as_of',now()-interval '16 minutes'))::text,true);
select set_config('test.geo_expired',(current_setting('test.geo_expired')::jsonb||jsonb_build_object('signature',private.external_catalogue_cursor_signature(current_setting('test.geo_expired')::jsonb)))::text,true);
select throws_ok($$select public.list_external_activities_v3(p_map_only=>true,p_cursor=>current_setting('test.geo_expired')::jsonb)$$,'22023','Activity cursor requires refresh.','Even a valid signature cannot extend the 15-minute reference');
select isnt(public.list_external_activities_v3(p_map_only=>true,p_limit=>1,p_cursor=>current_setting('test.geo_cursor')::jsonb)->'items'->0->>'id',current_setting('test.geo_first'),'Identical points paginate by stable canonical sort/UUID');
select throws_ok($$select public.list_external_activities_v3(p_map_only=>true,p_cursor=>jsonb_set(current_setting('test.geo_cursor')::jsonb,'{id}',to_jsonb(gen_random_uuid()::text)))$$,'22023','Activity cursor requires refresh.','Tampered keyset cursor is rejected by HMAC');
select throws_ok($$select public.list_external_activities_v3(p_map_only=>false,p_cursor=>current_setting('test.geo_cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','List/map-only scopes cannot exchange cursors');
select throws_ok($$select public.list_external_activities_v3(p_map_only=>true,p_area=>'{"mode":"radius","latitude":46,"longitude":11,"radius_m":5000}',p_cursor=>current_setting('test.geo_cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','Changed area invalidates continuation');
select throws_ok($$select public.list_external_activities_v3(p_area=>'{"mode":"radius","latitude":46,"longitude":11,"radius_m":100001}')$$,'22023','Invalid external geographic area.','Radius cap matches MAP04');
select throws_ok($$select public.list_external_activities_v3(p_area=>'{"mode":"bounds","south":46,"west":12,"north":47,"east":11}')$$,'22023','Invalid external geographic area.','Reversed/antimeridian bounds are refused');
select throws_ok($$select public.list_external_activities_v3(p_area=>'{"mode":"bounds","south":-1,"west":-1,"north":2,"east":2}')$$,'22023','External viewport exceeds 50000 square kilometers; narrow the area.','Geodesic viewport complexity matches MAP04');
select throws_ok($$select public.list_external_activities_v3(p_area=>'{"mode":"radius","latitude":46,"longitude":11,"radius_m":5000,"private_meeting":true}')$$,'22023','Invalid external geographic area.','No arbitrary/private/native geographic fields');
update private.external_activity_sources set enabled=false where source_id='synthetic-geo-b';
select throws_ok($$select public.list_external_activities_v3(p_map_only=>true,p_cursor=>current_setting('test.geo_cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','Disabled source cannot reappear through an old signed cursor');
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true)->'items'),7,'Fresh map read immediately respects source disable');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":11,"radius_m":5000,"kinds":["external_activity"]}')$$,'22023','Kinds must contain 1..3 supported families.','Native default contract remains closed to external kinds');
set local role anon;
select is(jsonb_array_length(public.list_external_activities_v3(p_map_only=>true)->'items'),7,'Anonymous map uses the same source/public/freshness gates');
select throws_ok($$select key from private.external_catalogue_cursor_key$$,'42501',null,'Anonymous caller cannot read signing material');
reset role;
select * from finish();
rollback;
