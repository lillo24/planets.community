-- D03 uses the actually merged ACTAPI01 catalogue. No importer, provider
-- credentials, scraping, event mutation or native participation is added.
create table private.cocreate_post_events (
 post_id uuid primary key references private.cocreate_posts(id) on delete cascade,
 activity_id uuid references private.external_activities(activity_id) on delete set null
);
alter table private.cocreate_post_events enable row level security;
create index cocreate_post_event_activity on private.cocreate_post_events(activity_id,post_id) where activity_id is not null;
revoke all on private.cocreate_post_events from public,anon,authenticated,service_role;

create function public.get_cocreate_event_context(p_activity_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare activity jsonb;
begin
 perform private.require_cocreate_enabled();
 activity:=public.get_external_activity(p_activity_id);
 if activity is null or activity->>'status'<>'scheduled' then return null;end if;
 return activity;
end; $$;

create function public.create_cocreate_post_from_event(p_expected_profile_id uuid,p_command_id uuid,
 p_activity_id uuid,p_content jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);source text;activity jsonb;
 prior private.cocreate_room_receipts;intent text;result jsonb;
begin
 if p_command_id is null or p_activity_id is null or p_content is null then
  raise sqlstate '22023' using message='An exact event and reviewed draft content are required.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 intent:=private.group_command_hash(jsonb_build_array('event_post_draft',p_activity_id,p_content));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The event draft intent differs.';end if;
  if not exists(select 1 from private.cocreate_posts where id=(prior.result->>'post_id')::uuid and author_id=actor)
   then raise sqlstate 'P0002' using message='The recorded people-seeking draft is unavailable.';end if;
  return prior.result;
 end if;
 select source_id into source from private.external_activities where activity_id=p_activity_id;
 -- Same source-before-record order as the canonical importer. Concurrent
 -- withdrawal/rights revocation cannot race a new invitation into availability.
 perform 1 from private.external_activity_sources where source_id=source for share;
 perform 1 from private.external_activities where activity_id=p_activity_id for share;
 activity:=public.get_cocreate_event_context(p_activity_id);
 if activity is null then raise sqlstate '42501' using message='This public event is no longer available for a new draft.';end if;
 -- The ordinary B01 validator/abuse limits own all user-reviewed content.
 -- This transaction creates a draft only; it never publishes or joins an event.
 result:=public.mutate_cocreate_post(actor,gen_random_uuid(),'create',null,null,p_content);
 insert into private.cocreate_post_events(post_id,activity_id) values((result->>'post_id')::uuid,p_activity_id);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;

create function public.get_cocreate_post_event(p_post_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare target uuid;activity jsonb;
begin
 perform private.require_cocreate_enabled();
 if not private.cocreate_post_public(p_post_id) then return null;end if;
 select activity_id into target from private.cocreate_post_events where post_id=p_post_id;
 if not found then return null;end if;
 activity:=public.get_external_activity(target);
 if activity is null then return jsonb_build_object('post_id',p_post_id,'state','unavailable');end if;
 -- Minimal deliberately public reference. Never copy provider addresses,
 -- descriptions, contact data or private post fields into this projection.
 return jsonb_build_object('post_id',p_post_id,'state','available','event',jsonb_build_object(
  'activity_id',activity->'id','title',activity->'title','canonical_url',activity->'canonical_url',
  'source_name',activity->'source'->'name','attribution',activity->'source'->'attribution',
  'license_url',activity->'source'->'license_url','status',activity->'status','stale',activity->'stale'));
end; $$;
revoke all on function public.get_cocreate_event_context(uuid),public.get_cocreate_post_event(uuid),
 public.create_cocreate_post_from_event(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.get_cocreate_event_context(uuid),public.get_cocreate_post_event(uuid) to anon,authenticated;
grant execute on function public.create_cocreate_post_from_event(uuid,uuid,uuid,jsonb) to authenticated;
