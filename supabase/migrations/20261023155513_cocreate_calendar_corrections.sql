-- CAL01-FIX01: read-only admission preview and current-member calendar parity.
-- Installed closed card DTOs and all atomic command/recovery paths stay intact.
set lock_timeout = '5s';
set statement_timeout = '60s';

create function private.cocreate_can_join_recruitment(p_actor uuid,p_card uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from private.cocreate_recruitments c
  join private.cocreate_rooms r on r.id=c.room_id
  left join private.cocreate_meetings m on m.id=c.meeting_id
  left join private.cocreate_room_episodes member on member.room_id=r.id
   and member.actor_id=p_actor and member.ended_at is null
  where c.id=p_card and c.retracted_at is null and c.expires_at>statement_timestamp()
   and private.cocreate_numbered_public(r.id)
   and private.cocreate_hub_member(r.hub_id,p_actor)
   and private.cocreate_account_available(r.manager_id)
   and not private.has_active_user_block_between(p_actor,r.manager_id)
   and not exists(select 1 from private.cocreate_room_exclusions x
    where x.room_id=r.id and x.actor_id=p_actor and x.active)
   and (member.id is not null or (
    private.cocreate_numbered_occupied(r.id)<r.capacity
    and (select count(*) from private.cocreate_room_episodes e
     join private.cocreate_rooms room on room.id=e.room_id
     where e.actor_id=p_actor and e.ended_at is null and room.kind='numbered')
     <(select max_numbered_memberships from private.cocreate_settings)))
   and (c.meeting_id is null or (m.cancelled_at is null and m.starts_at>statement_timestamp()
    and (private.cocreate_meeting_occupied(m.id)<m.capacity or exists(
     select 1 from private.cocreate_meeting_attendance a where a.meeting_id=m.id
      and a.actor_id=p_actor and a.episode_id=member.id and a.attending))))
 );
$$;
revoke all on function private.cocreate_can_join_recruitment(uuid,uuid)
 from public,anon,authenticated,service_role;

create function public.get_cocreate_recruitment_review_v1(
 p_expected_profile_id uuid,p_general_room_id uuid,p_episode_id uuid,p_recruitment_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); card jsonb;
begin
 -- Reuse the installed exact history frontier; this read creates no membership,
 -- attendance, receipt, transcript or ACK. Command retries never depend on it.
 card:=public.get_cocreate_recruitment_v2(actor,p_general_room_id,p_episode_id,p_recruitment_id);
 return jsonb_build_object('profile_id',actor,'hub_id',card->'hub_id',
  'general_room_id',p_general_room_id,'episode_id',p_episode_id,
  'recruitment',card,'can_join',(card->>'available')::boolean
   and private.cocreate_can_join_recruitment(actor,p_recruitment_id));
end; $$;
revoke all on function public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid) to authenticated;
comment on function public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid)
 is 'CAL01-FIX01: exact General episode/history review with fresh viewer admission eligibility. Closed installed cards unchanged; atomic Join remains final authority and exact recovery is independent.';

-- Replace the body in place: preserve OID, signature/defaults, ACL and cursor.
create or replace function public.get_cocreate_calendar_v1(
 p_expected_profile_id uuid,p_hub_id uuid,p_general_room_id uuid,p_episode_id uuid,
 p_window_start timestamptz,p_window_end timestamptz,
 p_limit integer default 25,p_cursor text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare
 actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes;
 scope text; payload jsonb; after_at timestamptz; after_id uuid;
 rows jsonb; last_row jsonb; next_cursor text;
begin
 if num_nulls(p_hub_id,p_general_room_id,p_episode_id,p_window_start,p_window_end,p_limit)>0
  or not isfinite(p_window_start) or not isfinite(p_window_end)
  or p_window_end<=p_window_start or p_window_end-p_window_start>interval '62 days'
  or p_limit not between 1 and 50 then
  raise sqlstate '22023' using message='Calendar requires a finite window of at most 62 days and 1-50 rows.';
 end if;
 episode:=private.require_cocreate_room_episode(actor,p_general_room_id,p_episode_id);
 if not private.cocreate_hub_public(p_hub_id) or not exists(
  select 1 from private.cocreate_rooms where id=p_general_room_id and hub_id=p_hub_id
   and kind='general' and not archived
 ) then raise sqlstate '42501' using message='The community calendar is unavailable.';end if;

 -- Bind keysets to this actor, database realm (private episode secret), exact
 -- General history, window and membership authority. Every page rechecks access.
 scope:=jsonb_build_array('cocreate.calendar.v1',actor,p_hub_id,p_general_room_id,
  episode.id,episode.exit_sequence,p_window_start,p_window_end,p_limit,
  (select jsonb_agg(jsonb_build_array(e.id,e.ended_at,e.exit_sequence) order by e.id)
   from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
   where e.actor_id=actor and r.hub_id=p_hub_id))::text;
 if p_cursor is not null then
  if length(p_cursor)>1024 then raise sqlstate '22023' using message='Invalid calendar cursor.';end if;
  begin
   payload:=p_cursor::jsonb;
   after_at:=(payload->>'at')::timestamptz;
   after_id:=(payload->>'id')::uuid;
  exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
   raise sqlstate '22023' using message='Invalid calendar cursor.';
  end;
  if jsonb_typeof(payload) is distinct from 'object' or after_at is null or after_id is null
   or not isfinite(after_at) or after_at<p_window_start or after_at>=p_window_end
   or (select count(*) from jsonb_object_keys(payload))<>3
   or payload->>'mac' is distinct from encode(extensions.hmac(
    scope||jsonb_build_array(after_at,after_id)::text,episode.read_secret::text,'sha256'),'hex') then
   raise sqlstate '22023' using message='Calendar cursor scope changed; refresh the window.';
  end if;
 end if;

 with eligible as materialized (
  select m.*,r.group_number,r.capacity chat_capacity,r.id numbered_room,
   member.id member_episode,card.id recruitment_id,
   card.retracted_at,card.expires_at,
   private.cocreate_meeting_occupied(m.id) occupied
  from private.cocreate_meetings m join private.cocreate_rooms r on r.id=m.room_id
  -- A current numbered episode has the same authority as current-meeting review.
  left join lateral (
   select e.id from private.cocreate_room_episodes e
   where e.room_id=r.id and e.actor_id=actor and e.ended_at is null
    and private.cocreate_hub_member(p_hub_id,actor)
    and m.id=(select latest.id from private.cocreate_meetings latest
     where latest.room_id=r.id order by latest.created_at desc,latest.id desc limit 1)
  ) member on true
  -- Match the installed General reader's exact upper history frontier. An old
  -- retracted card cannot hide a newer eligible repost, or bypass this frontier.
  left join lateral (
   select c.id,c.retracted_at,c.expires_at from private.cocreate_recruitments c
   join private.cocreate_room_messages msg on msg.id=c.message_id
   join private.cocreate_rooms general on general.id=msg.room_id
   where c.meeting_id=m.id and c.general_room_id=p_general_room_id
    and msg.sequence<=coalesce(episode.exit_sequence,general.last_sequence)
   order by (c.retracted_at is null and c.expires_at>statement_timestamp()) desc,
    c.created_at desc,c.id desc limit 1
  ) card on true
  where r.hub_id=p_hub_id and private.cocreate_numbered_public(r.id)
   and m.starts_at>=p_window_start and m.starts_at<p_window_end
   and (after_id is null or (m.starts_at,m.id)>(after_at,after_id))
   and (member.id is not null or (card.id is not null
    and private.cocreate_account_available(r.manager_id)
    and not private.has_active_user_block_between(actor,r.manager_id)))
  order by m.starts_at,m.id limit p_limit+1
 ), projected as (
  select starts_at,id,jsonb_build_object(
   'meeting_id',id,'room_id',room_id,'number',group_number,'starts_at',starts_at,
   'capacity',capacity,'occupied',occupied,
   'state',case when cancelled_at is not null then 'cancelled'
    when starts_at<=statement_timestamp() then 'past' else 'scheduled' end,
   'attending',exists(select 1 from private.cocreate_meeting_attendance a
    where a.meeting_id=eligible.id and a.actor_id=actor and a.attending and a.episode_id=member_episode),
   'episode_id',member_episode,'recruitment_id',recruitment_id,
   'can_confirm',member_episode is not null and cancelled_at is null
    and starts_at>statement_timestamp() and occupied<capacity,
   'can_join',member_episode is null and recruitment_id is not null
    and private.cocreate_can_join_recruitment(actor,recruitment_id)
  ) item from eligible
 ) select coalesce(jsonb_agg(item order by starts_at,id),'[]'::jsonb) into rows from projected;

 if jsonb_array_length(rows)>p_limit then
  rows:=rows-(jsonb_array_length(rows)-1);
  last_row:=rows->(p_limit-1);
  after_at:=(last_row->>'starts_at')::timestamptz;
  after_id:=(last_row->>'meeting_id')::uuid;
  next_cursor:=jsonb_build_object('at',after_at,'id',after_id,'mac',encode(extensions.hmac(
   scope||jsonb_build_array(after_at,after_id)::text,episode.read_secret::text,'sha256'),'hex'))::text;
 end if;
 return jsonb_build_object('profile_id',actor,'hub_id',p_hub_id,
  'general_room_id',p_general_room_id,'episode_id',episode.id,
  'window_start',p_window_start,'window_end',p_window_end,'meetings',rows,'next_cursor',next_cursor);
end; $$;
reset lock_timeout;
reset statement_timeout;
