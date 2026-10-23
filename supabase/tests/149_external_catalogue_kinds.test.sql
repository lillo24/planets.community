begin;
select no_plan();
select is(public.list_external_activities_v2()->>'state','unconfigured','V2 distinguishes unconfigured from empty');
select ok(not has_function_privilege(r,'private.external_catalogue_rows(timestamptz,timestamptz,text,text,date,date)','EXECUTE'),r||' cannot read private catalogue rows')
 from unnest(array['anon','authenticated','service_role']) r;
select ok(has_function_privilege(r,'public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb)','EXECUTE'),r||' has deliberate public V2 read')
 from unnest(array['anon','authenticated']) r;

insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
 values('synthetic-actcat02','Synthetic catalogue','https://sports.example.org',true,true,'Synthetic fixture only','https://sports.example.org/license');
create function pg_temp.catalogue_fixture(p_id text,p_kind text) returns jsonb language sql as $$
 select jsonb_build_object('upstream_id',p_id,'title','Synthetic '||p_id,'kind',p_kind,
  'description',case when p_kind='event' then 'Synthetic event description' end,
  'canonical_url','https://sports.example.org/'||p_id,'category','sports','source_categories','[]'::jsonb,
  'status','scheduled','publishable',true,'discipline',case when p_kind='place' then 'basketball' when p_kind='course' then 'yoga' else 'swimming' end,
  'occurrences',case when p_kind='event' then jsonb_build_array(jsonb_build_object('kind','timed',
    'start',to_char((now()+interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'timezone','Europe/Rome')) else '[]'::jsonb end,
  'schedule',case when p_kind='course' then jsonb_build_object('season_start',(now()::date-1)::text,'season_end',(now()::date+30)::text,'text','Schedule to confirm') end)
$$;
select lives_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('place','place'),'https://sports.example.org')$$,'A place needs no description or date');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('place','place')||'{"geometry":{"latitude":91,"longitude":11,"precision":"venue","provenance_url":"https://sports.example.org/data"}}','https://sports.example.org')$$,'22023',null,'Out-of-range public geometry rejected');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('place','place')||'{"geometry":{"latitude":46,"longitude":11,"provenance_url":"https://sports.example.org/data"}}','https://sports.example.org')$$,'22023',null,'Geometry requires explicit precision');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('place','place')||'{"geometry":{"latitude":"NaN","longitude":11,"precision":"venue","provenance_url":"https://sports.example.org/data"}}','https://sports.example.org')$$,'22023',null,'Non-numeric coordinates rejected');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('place','place')||'{"geometry":{"latitude":46,"longitude":11,"precision":"venue","provenance_url":"https://other.example.org/data"}}','https://sports.example.org')$$,'22023',null,'Geometry provenance must belong to the source');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('course','course')||'{"schedule":{"season_start":"2026-10-01","weekly":{"days":[7],"start_time":"10:00"},"timezone":"Europe/Rome"}}','https://sports.example.org')$$,'22023',null,'Unbounded weekly recurrence rejected');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('course','course')||'{"schedule":{"season_start":"2026-10-01","season_end":"2026-12-01","timezone":"Europe/Rome","weekly":{"days":[7,7],"start_time":"10:00"}}}','https://sports.example.org')$$,'22023',null,'Duplicate weekday rule rejected');
select throws_ok($$select private.validate_external_activity(pg_temp.catalogue_fixture('course','course')||'{"schedule":{"season_start":"2026-10-01","season_end":"2026-12-01","timezone":"Europe/Rome","weekly":{"days":[7],"start_time":"24:00"}}}','https://sports.example.org')$$,'22023',null,'Impossible weekly wall clock rejected');

select set_config('test.catalogue_run',public.begin_external_activity_import('synthetic-actcat02')->>'run_id',true);
select is(public.finish_external_activity_import(current_setting('test.catalogue_run')::uuid,'success',jsonb_build_array(
 pg_temp.catalogue_fixture('event','event'),pg_temp.catalogue_fixture('course','course'),
 pg_temp.catalogue_fixture('place','place')||'{"geometry":{"latitude":46.07,"longitude":11.12,"precision":"locality","provenance_url":"https://sports.example.org/data"}}'
),3)->>'changed','3','Three kinds enter the existing atomic import');
select set_config('test.place_id',(select activity_id::text from private.external_activities where upstream_id='place'),true);
select set_config('test.course_id',(select activity_id::text from private.external_activities where upstream_id='course'),true);
select set_config('test.event_id',(select activity_id::text from private.external_activities where upstream_id='event'),true);
select is(jsonb_array_length(public.list_external_activities()->'items'),1,'Released V1 list receives only described scheduled events');
select is(public.list_external_activities()->'items'->0->>'id',current_setting('test.event_id'),'V1 event UUID is unchanged');
select ok(public.get_external_activity(current_setting('test.place_id')::uuid) is null,'Released V1 detail never returns a place');
select is(jsonb_array_length(public.list_external_activities_v2()->'items'),3,'V2 reads all supported kinds');
select is((select count(*) from private.external_catalogue_rows(now(),now()-interval '3 days','course',null,null,null)),0::bigint,'Courses entering their season after a page reference wait for refresh');
select is(public.list_external_activities_v2()->'items'->0->>'kind','event','Mixed ordering starts with dated events');
select is(public.list_external_activities_v2()->'items'->1->>'kind','course','Current unknown-session courses form a stable group');
select is(public.list_external_activities_v2()->'items'->2->>'kind','place','Alphabetical places follow scheduled material');
select is(public.get_external_activity_v2(current_setting('test.course_id')::uuid)->'next_at','null'::jsonb,'Unknown next lesson stays null');
select is(public.get_external_activity_v2(current_setting('test.place_id')::uuid)->'description','null'::jsonb,'Missing source prose stays null');
select is(public.get_external_activity_v2(current_setting('test.place_id')::uuid)->'geometry'->>'precision','locality','Locality geometry remains approximate');
select is(jsonb_array_length(public.list_external_activities_v2(p_limit=>1)->'disciplines'),3,'Facets span the complete eligible catalogue');
select is(jsonb_array_length(public.list_external_activities_v2(p_kind=>'place')->'items'),1,'Kind filters apply before pagination');
select is(jsonb_array_length(public.list_external_activities_v2(p_query=>'place')->'items'),1,'Literal search applies before pagination');
select is(jsonb_array_length(public.list_external_activities_v2(p_query=>'%')->'items'),0,'Search has no SQL wildcard semantics');
select is(jsonb_array_length(public.list_external_activities_v2(p_discipline=>'basketball')->'items'),1,'Discipline filters are canonical');
select is(jsonb_array_length(public.list_external_activities_v2(p_from=>now()::date,p_to=>now()::date+3)->'items'),1,'Date window excludes undated places and unknown lessons');
select throws_ok($$select public.list_external_activities_v2(p_from=>now()::date)$$,'22023',null,'Partial date windows rejected');
select throws_ok($$select public.list_external_activities_v2(p_from=>now()::date,p_to=>now()::date+91)$$,'22023',null,'Date windows bounded to 90 days');
select set_config('test.catalogue_cursor',(public.list_external_activities_v2(p_limit=>1)->'next_cursor')::text,true);
select is(public.list_external_activities_v2(p_limit=>1,p_cursor=>current_setting('test.catalogue_cursor')::jsonb)->'items'->0->>'kind','course','Keyset advances across kinds');
select throws_ok($$select public.list_external_activities_v2(p_kind=>'place',p_cursor=>current_setting('test.catalogue_cursor')::jsonb)$$,'22023',null,'Cursor binds every filter');

-- A real weekly wall-clock term spans the Rome offset change. October 25 is
-- explicitly cancelled; the next Sunday is November 1 at 09:00 UTC.
select is((select next_at from private.external_catalogue_timing('{"occurrences":[],"schedule":{"season_start":"2026-10-01","season_end":"2026-11-30","timezone":"Europe/Rome","weekly":{"days":[7],"start_time":"10:00"},"exceptions":["2026-10-25"]}}','2026-10-23T00:00:00Z')),'2026-11-01T09:00:00Z'::timestamptz,'Weekly course preserves DST and cancelled lesson');
select is((select next_at from private.external_catalogue_timing('{"occurrences":[],"schedule":{"season_start":"2026-10-01","season_end":"2026-11-30","timezone":"Europe/Rome","weekly":{"days":[7],"start_time":"10:00"},"exceptions":[]}}','2026-10-16T00:00:00Z')),'2026-10-18T08:00:00Z'::timestamptz,'Summer-time lesson has the preceding offset');
select is((select next_occurrence->'end' from private.external_catalogue_timing('{"occurrences":[],"schedule":{"season_start":"2026-10-01","season_end":"2026-11-30","timezone":"Europe/Rome","weekly":{"days":[7],"start_time":"10:00"}}}','2026-10-23T00:00:00Z')),'null'::jsonb,'Weekly rule does not invent an end time');
select is((select next_at from private.external_catalogue_timing('{"occurrences":[],"schedule":{"season_start":"2026-03-01","season_end":"2026-04-15","timezone":"Europe/Rome","weekly":{"days":[7],"start_time":"02:30"}}}','2026-03-28T00:00:00Z')),'2026-04-05T00:30:00Z'::timestamptz,'Nonexistent spring clock is skipped instead of shifted');
select is((select next_at from private.external_catalogue_timing('{"occurrences":[{"kind":"date","start":"2026-10-25","end":"2026-10-26","timezone":"Europe/Rome"}]}','2026-10-24T00:00:00Z')),'2026-10-24T22:00:00Z'::timestamptz,'Date-only internal ordering respects local midnight without changing public date');
select is((select next_at from private.external_catalogue_timing('{"occurrences":[{"kind":"all_day","start":"2026-10-24","end":"2026-10-27","timezone":"Europe/Rome"}]}','2026-10-23T00:00:00Z','2026-10-25','2026-10-26')),'2026-10-23T22:00:00Z'::timestamptz,'Date window includes overlapping multiday occurrences');
select is((select next_at from private.external_catalogue_timing('{"occurrences":[{"kind":"all_day","start":"2026-10-24","end":"2026-10-25","timezone":"Europe/Rome"}]}','2026-10-23T00:00:00Z','2026-10-25','2026-10-26')),null::timestamptz,'Exclusive all-day end does not overlap the following date');
select is((select next_at from private.external_catalogue_timing('{"kind":"course","occurrences":[{"kind":"timed","start":"2026-10-25T10:00:00+01:00","timezone":"Europe/Rome"},{"kind":"timed","start":"2026-11-01T10:00:00+01:00","timezone":"Europe/Rome"}],"schedule":{"season_start":"2026-10-01","season_end":"2026-11-30","timezone":"Europe/Rome","exceptions":["2026-10-25"]}}','2026-10-23T00:00:00Z')),'2026-11-01T09:00:00Z'::timestamptz,'Cancelled lesson exceptions apply to explicit sessions too');

update private.external_activities set last_observed_at=now()-interval '8 days' where upstream_id='place';
select is(public.get_external_activity_v2(current_setting('test.place_id')::uuid)->>'stale','true','Place warns after seven days');
update private.external_activities set last_observed_at=now()-interval '31 days' where upstream_id='place';
update private.external_activity_sources set last_success_at=now() where source_id='synthetic-actcat02';
select ok(public.get_external_activity_v2(current_setting('test.place_id')::uuid) is null,'Source-wide success does not unhide expired observations');
select is(jsonb_array_length(public.list_external_activities_v2(p_kind=>'place')->'items'),0,'Expired place is hidden from list too');
update private.external_activities set content=jsonb_set(content,'{schedule}',jsonb_build_object('season_start',(now()::date-30)::text,'season_end',(now()::date-2)::text)) where upstream_id='course';
select ok(public.get_external_activity_v2(current_setting('test.course_id')::uuid) is null,'Expired course not exposed as current');
update private.external_activities set content=jsonb_set(content,'{schedule}','{"text":"Schedule unknown"}') where upstream_id='course';
select is(jsonb_array_length(public.list_external_activities_v2(p_kind=>'course')->'items'),0,'Unknown season does not imply active enrollment');
update private.external_activities set content=jsonb_set(content,'{status}','"cancelled"') where upstream_id='event';
select is(jsonb_array_length(public.list_external_activities_v2(p_kind=>'event')->'items'),0,'Cancelled event excluded from active discovery');
select is(public.get_external_activity_v2(current_setting('test.event_id')::uuid)->>'status','cancelled','Exact event detail reports source cancellation');
update private.external_activity_sources set enabled=false where source_id='synthetic-actcat02';
set local role anon;
select is(public.list_external_activities_v2()->>'state','unconfigured','Anonymous list observes source disable immediately');
select ok(public.get_external_activity_v2(current_setting('test.event_id')::uuid) is null,'Anonymous exact detail observes disable');
select throws_ok($$select * from private.external_activities$$,'42501',null,'Anonymous callers cannot read canonical private rows');
reset role;
select * from finish();
rollback;
