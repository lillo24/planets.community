-- FILL01: durable actor-private in-app notices. Outbox payloads contain IDs only.
create table private.cocreate_filling_notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null,
 general_episode_id uuid not null references private.cocreate_room_episodes(id),
 recruitment_id uuid not null references private.cocreate_recruitments(id),
 source_outbox_event_id uuid not null references private.outbox_events(id),
 created_at timestamptz not null,read_at timestamptz,
 unique(source_outbox_event_id,recipient_id),check(read_at is null or read_at>=created_at)
);
create index cocreate_filling_notice_recipient on private.cocreate_filling_notifications(recipient_id,created_at desc,id desc);
create table private.cocreate_filling_progress (
 outbox_event_id uuid primary key references private.outbox_events(id),last_episode_id uuid
);
alter table private.cocreate_filling_notifications enable row level security;
alter table private.cocreate_filling_progress enable row level security;
revoke all on private.cocreate_filling_notifications,private.cocreate_filling_progress from public,anon,authenticated,service_role;
create function private.cocreate_enqueue_filling() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.meeting_id is not null then
 insert into private.outbox_events(event_type,payload) values('cocreate.filling_posted',jsonb_build_object('recruitment_id',new.id));
 end if;return null;
end; $$;
create trigger cocreate_enqueue_filling after insert on private.cocreate_recruitments for each row execute function private.cocreate_enqueue_filling();

create function private.cocreate_filling_allowed(p_card uuid,p_actor uuid,p_episode uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_recruitments c join private.cocreate_meetings m on m.id=c.meeting_id
 join private.cocreate_room_episodes e on e.id=p_episode and e.room_id=c.general_room_id and e.actor_id=p_actor
 join private.cocreate_settings s on s.singleton
 join public.notification_categories category on category.slug='participation'
 left join public.profile_notification_preferences preference on preference.profile_id=p_actor and preference.category_slug=category.slug
 where c.id=p_card and s.enabled and c.creator_id<>p_actor and c.retracted_at is null and c.expires_at>statement_timestamp()
 and m.cancelled_at is null and m.starts_at>statement_timestamp() and private.cocreate_numbered_public(c.room_id)
 and e.ended_at is null and not e.muted and e.joined_at<=c.created_at
 and private.cocreate_community_eligible(p_actor) and private.cocreate_community_eligible(c.creator_id)
 and not private.has_active_user_block_between(p_actor,c.creator_id)
 and coalesce(preference.in_app_enabled,category.default_in_app_enabled)
 and not exists(select 1 from private.cocreate_hub_exclusions x join private.cocreate_rooms r on r.hub_id=x.hub_id
 where r.id=c.general_room_id and x.actor_id=p_actor and x.active));
$$;
create function private.process_cocreate_filling_batch(p_limit integer)
returns table(processed_count integer,notifications_created integer,notifications_suppressed integer)
language plpgsql security definer set search_path='' as $$
declare event private.outbox_events; card private.cocreate_recruitments; episode private.cocreate_room_episodes;
 after_id uuid; ids uuid[]; episode_id uuid; inserted integer; processed integer:=0; created integer:=0; suppressed integer:=0;
begin
 if p_limit is null or p_limit not between 1 and 100 then raise sqlstate '22023' using message='Invalid filling worker budget.';end if;
 for event in select o.* from private.outbox_events o where o.event_type='cocreate.filling_posted'
 and o.available_at<=statement_timestamp() and not exists(select 1 from private.outbox_consumer_receipts r
 where r.outbox_event_id=o.id and r.consumer_key='notifications.v1')
 order by o.created_at,o.id limit p_limit for update of o skip locked loop
 -- Recheck after obtaining the event lock, including a stale cursor snapshot.
 if exists(select 1 from private.outbox_consumer_receipts r where r.outbox_event_id=event.id and r.consumer_key='notifications.v1') then continue;end if;
 select * into card from private.cocreate_recruitments where id=(event.payload->>'recruitment_id')::uuid and meeting_id is not null;
 if card.id is null then raise sqlstate '22023' using message='Missing canonical filling event source.';end if;
 select last_episode_id into after_id from private.cocreate_filling_progress where outbox_event_id=event.id;
 select coalesce(array_agg(e.id order by e.id),'{}') into ids from (
 select e.id from private.cocreate_room_episodes e where e.room_id=card.general_room_id and e.joined_at<=card.created_at
 and (after_id is null or e.id>after_id) order by e.id limit 26)e;
 foreach episode_id in array coalesce(ids[1:25],'{}'::uuid[]) loop
 select * into episode from private.cocreate_room_episodes where id=episode_id;
 if private.cocreate_filling_allowed(card.id,episode.actor_id,episode.id) then
 insert into private.cocreate_filling_notifications(recipient_id,general_episode_id,recruitment_id,source_outbox_event_id,created_at)
 values(episode.actor_id,episode.id,card.id,event.id,card.created_at) on conflict do nothing;
 get diagnostics inserted=row_count;created:=created+inserted;
 if inserted>0 then perform private.cocreate_signal(episode.actor_id);end if;
 else suppressed:=suppressed+1;end if;
 end loop;
 if cardinality(ids)>25 then
 insert into private.cocreate_filling_progress values(event.id,ids[25]) on conflict(outbox_event_id) do update set last_episode_id=excluded.last_episode_id;
 else
 insert into private.outbox_consumer_receipts(outbox_event_id,consumer_key,processed_at) values(event.id,'notifications.v1',statement_timestamp()) on conflict do nothing;
 delete from private.cocreate_filling_progress where outbox_event_id=event.id;
 end if;
 processed:=processed+1;
 end loop;
 return query select processed,created,suppressed;
end; $$;

-- Extend the repaired canonical body in place. Its resolver, atomic legacy
-- claim, OID/ACL and one total budget remain unchanged.
do $$ declare source text:=pg_get_functiondef('public.process_notification_outbox_batch(integer)'::regprocedure);
 needle text:='select * into contact_result from private.process_contact_activity_batch(greatest(1,p_limit/2));';
begin
 if strpos(source,needle)=0 or strpos(source,'private.resolve_notification_event(source_event.id)')=0
 or strpos(source,'get diagnostics inserted_count = row_count;')=0 then
 raise exception 'Unknown repaired notification worker predecessor.';end if;
 source:=replace(source,'contact_result record;','contact_result record; filling_result record;');
 source:=replace(source,needle,'select * into filling_result from private.process_cocreate_filling_batch(greatest(1,p_limit/3));
 if p_limit>filling_result.processed_count then
 select * into contact_result from private.process_contact_activity_batch(greatest(1,(p_limit-filling_result.processed_count)/2));
 else select 0 processed_count,0 notifications_created,0 notifications_suppressed into contact_result;end if;
 contact_result.processed_count:=contact_result.processed_count+filling_result.processed_count;
 contact_result.notifications_created:=contact_result.notifications_created+filling_result.notifications_created;
 contact_result.notifications_suppressed:=contact_result.notifications_suppressed+filling_result.notifications_suppressed;');
 execute source;
end; $$;
create function public.list_own_notifications_with_cocreate(p_expected_profile_id uuid,p_limit integer default 20,
 p_cursor_created_at timestamptz default null,p_cursor_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);
begin
 if p_limit is null or p_limit not between 1 and 100 or (p_cursor_created_at is null)<>(p_cursor_id is null) then
 raise sqlstate '22023' using message='Invalid notification page.';end if;
 return (with items as (
 select (v->>'created_at')::timestamptz created_at,(v->>'notification_id')::uuid id,v item
 from jsonb_array_elements(public.list_own_notifications_with_contacts(actor,p_limit,p_cursor_created_at,p_cursor_id))v
 union all
 select n.created_at,n.id,jsonb_build_object('notification_id',n.id,'category_slug','participation',
 'notification_kind','cocreate_filling','destination_kind','cocreate_filling','created_at',n.created_at,'read_at',n.read_at,
 'cocreate_hub_id',r.hub_id,'cocreate_general_room_id',c.general_room_id,'cocreate_episode_id',n.general_episode_id,
 'cocreate_recruitment_id',c.id,'cocreate_topic',t.label,'cocreate_number',r.group_number,
 'cocreate_starts_at',m.starts_at,'cocreate_capacity',m.capacity,'cocreate_occupied',private.cocreate_meeting_occupied(m.id))
 from private.cocreate_filling_notifications n join private.cocreate_recruitments c on c.id=n.recruitment_id
 join private.cocreate_rooms r on r.id=c.room_id join private.cocreate_hubs h on h.id=r.hub_id
 join private.cocreate_topics t on t.id=h.topic_id join private.cocreate_meetings m on m.id=c.meeting_id
 where n.recipient_id=actor and private.cocreate_filling_allowed(c.id,actor,n.general_episode_id)
 and (p_cursor_id is null or (n.created_at,n.id)<(p_cursor_created_at,p_cursor_id))
 ), page as(select * from items order by created_at desc,id desc limit p_limit)
 select coalesce(jsonb_agg(item order by created_at desc,id desc),'[]') from page);
end; $$;
create function public.get_own_unread_notification_count_with_cocreate(p_expected_profile_id uuid) returns bigint
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);
begin return public.get_own_unread_notification_count_with_contacts(actor)+(select count(*) from private.cocreate_filling_notifications n
 where n.recipient_id=actor and n.read_at is null and private.cocreate_filling_allowed(n.recruitment_id,actor,n.general_episode_id));end; $$;
create function public.mark_notification_with_cocreate_read(p_expected_profile_id uuid,p_notification_id uuid) returns timestamptz
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);n private.cocreate_filling_notifications;result timestamptz;
begin
 select * into n from private.cocreate_filling_notifications where id=p_notification_id;
 if not found then return public.mark_contact_or_legacy_notification_read(actor,p_notification_id);end if;
 if n.recipient_id<>actor or not private.cocreate_filling_allowed(n.recruitment_id,actor,n.general_episode_id) then
 raise sqlstate '42501' using message='This filling notification is unavailable.';end if;
 update private.cocreate_filling_notifications set read_at=coalesce(read_at,clock_timestamp()) where id=n.id returning read_at into result;return result;
end; $$;
create function public.mark_all_notifications_with_cocreate_read(p_expected_profile_id uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);count integer;previous integer;
begin
 previous:=public.mark_all_notifications_with_contacts_read(actor);
 update private.cocreate_filling_notifications n set read_at=clock_timestamp() where n.recipient_id=actor and n.read_at is null
 and private.cocreate_filling_allowed(n.recruitment_id,actor,n.general_episode_id);
 get diagnostics count=row_count;return previous+count;
end; $$;
do $$ declare signature text;begin
 foreach signature in array array['private.cocreate_enqueue_filling()','private.cocreate_filling_allowed(uuid,uuid,uuid)',
 'private.process_cocreate_filling_batch(integer)'] loop
 execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';end loop;
 foreach signature in array array['public.list_own_notifications_with_cocreate(uuid,integer,timestamptz,uuid)',
 'public.get_own_unread_notification_count_with_cocreate(uuid)','public.mark_notification_with_cocreate_read(uuid,uuid)',
 'public.mark_all_notifications_with_cocreate_read(uuid)'] loop
 execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
 execute 'grant execute on function '||signature||' to authenticated';end loop;
end; $$;
