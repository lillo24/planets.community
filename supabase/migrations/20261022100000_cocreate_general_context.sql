-- C02: admitted context, including frozen history of a retired public hub.
-- Route IDs identify a scope; they never replace admission checks.
create function public.get_cocreate_general_context(p_expected_profile_id uuid,p_hub_id uuid,p_room_id uuid,p_episode_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id);
 result jsonb;
begin
 select jsonb_build_object('profile_id',actor,'hub_id',h.id,'room_id',r.id,'episode_id',episode.id,
  'topic_label',t.label,'locality',h.locality,'closed',episode.ended_at is not null,'muted',episode.muted) into result
 from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id
 join private.cocreate_topics t on t.id=h.topic_id where r.id=p_room_id and r.kind='general' and h.id=p_hub_id;
 if result is null then raise sqlstate '42501' using message='The General route context is unavailable.';end if;
 return result;
end; $$;
revoke all on function public.get_cocreate_general_context(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_cocreate_general_context(uuid,uuid,uuid,uuid) to authenticated;
