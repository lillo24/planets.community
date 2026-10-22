-- Bounded removal recovery for the current numbered-room creator only.
create function public.list_cocreate_numbered_removed(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,
 p_limit integer default 25,p_after_profile_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 if not exists(select 1 from private.cocreate_rooms where id=p_room_id and kind='numbered' and manager_id=actor and not archived)
 then raise sqlstate '42501' using message='Only this current numbered creator can review removal barriers.';end if;
 if p_limit is null or p_limit not between 1 and 50 then raise sqlstate '22023' using message='Invalid removed People page.';end if;
 return (select coalesce(jsonb_agg(to_jsonb(p) order by p.profile_id),'[]'::jsonb) from (
  select e.actor_id profile_id,p.display_name from private.cocreate_room_exclusions e join public.profiles p on p.id=e.actor_id
  where e.room_id=p_room_id and e.active and private.cocreate_account_available(e.actor_id)
   and (p_after_profile_id is null or e.actor_id>p_after_profile_id) order by e.actor_id limit p_limit)p);
end; $$;
revoke all on function public.list_cocreate_numbered_removed(uuid,uuid,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.list_cocreate_numbered_removed(uuid,uuid,uuid,integer,uuid) to authenticated;
