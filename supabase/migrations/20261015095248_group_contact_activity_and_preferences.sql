-- D-R03 review candidate. No message bodies, rosters or source-chat identifiers
-- enter an activity notice. Legacy notification readers retain their old kinds.
create table private.contact_activity_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid not null,
  source_outbox_event_id uuid not null references private.outbox_events(id),
  kind text not null check(kind in ('group_contact_request','group_coordination_proposal','member_contact_request')),
  target_id uuid not null,
  audience_version bigint,
  created_at timestamptz not null,
  read_at timestamptz,
  unique(source_outbox_event_id,recipient_profile_id),
  check(read_at is null or read_at>=created_at)
);
create index contact_activity_recipient_page on private.contact_activity_notifications(recipient_profile_id,created_at desc,id desc);
create index contact_activity_source on private.contact_activity_notifications(source_outbox_event_id);
create table private.contact_activity_progress (
  outbox_event_id uuid primary key references private.outbox_events(id),
  last_recipient_id uuid
);
create table private.contact_activity_events (
  kind text not null,
  target_id uuid not null,
  audience_version bigint not null,
  outbox_event_id uuid not null unique references private.outbox_events(id),
  primary key(kind,target_id,audience_version)
);
create table private.group_contact_preferences (
  profile_id uuid not null,
  conversation_id uuid not null references private.group_contact_conversations(id),
  muted boolean not null default false,
  primary key(profile_id,conversation_id)
);
create index group_contact_preferences_chat on private.group_contact_preferences(conversation_id);
alter table private.contact_activity_notifications enable row level security;
alter table private.contact_activity_progress enable row level security;
alter table private.contact_activity_events enable row level security;
alter table private.group_contact_preferences enable row level security;
revoke all on private.contact_activity_notifications,private.contact_activity_progress,
  private.contact_activity_events,private.group_contact_preferences from public,anon,authenticated,service_role;

create function private.enqueue_contact_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare kind text; target uuid; version bigint; event_id uuid;
begin
  if tg_table_name='group_contact_requests' then
    kind:='group_contact_request'; target:=new.id; version:=0;
  elsif tg_table_name='group_coordination_proposals' then
    if new.status<>'pending' then return new; end if;
    if tg_op='UPDATE' and new.version=old.version then return new; end if;
    kind:='group_coordination_proposal'; target:=new.id; version:=new.version;
  else raise exception 'Unsupported contact activity source: %',tg_table_name;
  end if;
  -- One source event; recipient expansion runs in bounded worker pages after
  -- the transaction has installed all seats. Never fan out inside a command.
  insert into private.outbox_events(event_type,payload)
    values('contact.activity_requested',jsonb_build_object('kind',kind,'target_id',target,'audience_version',version))
    returning id into event_id;
  insert into private.contact_activity_events values(kind,target,version,event_id);
  return new;
end; $$;
create trigger group_contact_activity_requested after insert on private.group_contact_requests
  for each row execute function private.enqueue_contact_activity();
create trigger group_coordination_activity_requested after insert or update of version on private.group_coordination_proposals
  for each row execute function private.enqueue_contact_activity();

create function private.contact_activity_allowed(p_kind text,p_target uuid,p_actor uuid,p_version bigint default null)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare result boolean;
begin
  if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor) then return false; end if;
  if p_kind='group_contact_request' then
    return exists(select 1 from private.group_contact_requests r where r.id=p_target
      and r.status='pending' and r.expires_at>statement_timestamp() and r.submitter_id<>p_actor
      and private.group_authority_role(r.target_group_id,p_actor) is not null
      and private.group_contact_triage_available(r));
  elsif p_kind='group_coordination_proposal' then
    return exists(select 1 from private.group_coordination_proposals p where p.id=p_target
      and p.initiator_id<>p_actor and (p_version is null or p.version=p_version)
      and private.group_coordination_available(p) and (
        exists(select 1 from private.group_coordination_seats s where s.proposal_id=p.id
          and s.profile_id=p_actor and private.group_coordination_slot_valid(s))
        or exists(select 1 from private.group_coordination_seats s where s.proposal_id=p.id
          and s.is_current and private.group_coordination_can_claim(p,s.group_id,p_actor))));
  elsif p_kind='member_contact_request' then
    -- The member migration owns the lifetime predicate. No representative or
    -- Idea predicate may substitute for it. A missing installed dependency fails.
    execute 'select private.member_contact_notice_allowed($1,$2)' into result using p_target,p_actor;
    return coalesce(result,false);
  end if;
  raise sqlstate '22023' using message='Unknown contact activity kind.';
end; $$;

create function private.contact_activity_candidates(p_kind text,p_target uuid,p_after uuid,p_limit integer)
returns table(profile_id uuid) language plpgsql stable security definer set search_path='' as $$
begin
  if p_limit is null or p_limit not between 1 and 26 then raise sqlstate '22023' using message='Invalid contact recipient page.'; end if;
  if p_kind='group_contact_request' then
    return query select m.profile_id from private.group_contact_requests r
      cross join lateral private.current_group_manager_profile_ids(r.target_group_id) m
      where r.id=p_target and (p_after is null or m.profile_id>p_after) order by m.profile_id limit p_limit;
  elsif p_kind='group_coordination_proposal' then
    return query select candidate.id from (
      select s.profile_id id from private.group_coordination_seats s where s.proposal_id=p_target and s.is_current and s.profile_id is not null
      union select m.profile_id from private.group_coordination_seats s
        cross join lateral private.current_group_manager_profile_ids(s.group_id) m
        where s.proposal_id=p_target and s.is_current and s.source_admission_id is null
    ) candidate where p_after is null or candidate.id>p_after order by candidate.id limit p_limit;
  else raise sqlstate '22023' using message='Unknown expanded contact activity kind.';
  end if;
end; $$;

create function private.process_contact_activity_batch(p_limit integer)
returns table(processed_count integer,notifications_created integer,notifications_suppressed integer)
language plpgsql security definer set search_path='' as $$
declare e private.outbox_events; last_id uuid; recipients uuid[]; recipient uuid;
  kind text; target uuid; version bigint; enabled boolean; inserted integer;
  processed integer:=0; created integer:=0; suppressed integer:=0;
begin
  if p_limit is null or p_limit not between 1 and 100 then raise sqlstate '22023' using message='Invalid contact activity batch size.'; end if;
  for e in select o.* from private.outbox_events o where o.event_type in ('contact.activity_requested','member_contact.request_created')
    and o.available_at<=statement_timestamp() and not exists(select 1 from private.outbox_consumer_receipts r
      where r.outbox_event_id=o.id and r.consumer_key='notifications.v1')
    order by o.created_at,o.id limit p_limit for update of o skip locked
  loop
    if e.event_type='member_contact.request_created' then
      kind:='member_contact_request'; target:=(e.payload->>'request_id')::uuid; version:=null;
      recipients:=array[(e.payload->>'recipient_profile_id')::uuid];
    else
      kind:=e.payload->>'kind'; target:=(e.payload->>'target_id')::uuid; version:=(e.payload->>'audience_version')::bigint;
      select p.last_recipient_id into last_id from private.contact_activity_progress p where p.outbox_event_id=e.id;
      select coalesce(array_agg(c.profile_id order by c.profile_id),'{}') into recipients
        from private.contact_activity_candidates(kind,target,last_id,26) c;
    end if;
    if target is null or array_position(recipients,null) is not null then raise sqlstate '22023' using message='Invalid contact activity event identifiers.'; end if;
    foreach recipient in array coalesce(recipients[1:25],'{}'::uuid[]) loop
      -- Preference uses the installed participation category; no new category,
      -- mandatory channel or external provider is silently enabled.
      select coalesce(p.in_app_enabled,c.default_in_app_enabled) into enabled from public.notification_categories c
        left join public.profile_notification_preferences p on p.category_slug=c.slug and p.profile_id=recipient where c.slug='participation';
      if enabled is null then raise sqlstate '55000' using message='The participation notification category is unavailable.'; end if;
      if enabled and private.contact_activity_allowed(kind,target,recipient,version) then
        insert into private.contact_activity_notifications(recipient_profile_id,source_outbox_event_id,kind,target_id,audience_version,created_at)
          values(recipient,e.id,kind,target,version,e.created_at) on conflict do nothing;
        get diagnostics inserted=row_count; created:=created+inserted;
        perform private.group_contact_signal(recipient);
      else suppressed:=suppressed+1; end if;
    end loop;
    if cardinality(recipients)>25 then
      insert into private.contact_activity_progress values(e.id,recipients[25])
        on conflict(outbox_event_id) do update set last_recipient_id=excluded.last_recipient_id;
    else
      insert into private.outbox_consumer_receipts(outbox_event_id,consumer_key,processed_at)
        values(e.id,'notifications.v1',statement_timestamp()) on conflict do nothing;
      delete from private.contact_activity_progress where outbox_event_id=e.id;
    end if;
    -- A processed item is one bounded event page; unfinished fanout retains its
    -- durable cursor and no completion receipt. Workers continue until zero.
    processed:=processed+1;
  end loop;
  return query select processed,created,suppressed;
end; $$;

alter function public.process_notification_outbox_batch(integer) rename to process_notification_outbox_before_contacts;
alter function public.process_notification_outbox_before_contacts(integer) set schema private;
revoke all on function private.process_notification_outbox_before_contacts(integer) from public,anon,authenticated,service_role;
create function public.process_notification_outbox_batch(p_limit integer default 100)
returns table(processed_count integer,notifications_created integer,notifications_suppressed integer)
language plpgsql security definer set search_path='' as $$
declare contact_result record; legacy_result record; remaining integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then raise sqlstate '22023' using message='Notification projector batch size must be between 1 and 100.'; end if;
  select * into contact_result from private.process_contact_activity_batch(greatest(1,p_limit/2));
  remaining:=p_limit-contact_result.processed_count;
  if remaining>0 then select * into legacy_result from private.process_notification_outbox_before_contacts(remaining);
  else select 0 processed_count,0 notifications_created,0 notifications_suppressed into legacy_result; end if;
  return query select contact_result.processed_count+legacy_result.processed_count,
    contact_result.notifications_created+legacy_result.notifications_created,
    contact_result.notifications_suppressed+legacy_result.notifications_suppressed;
end; $$;

create function public.list_own_notifications_with_contacts(p_expected_profile_id uuid,p_limit integer default 20,
  p_cursor_created_at timestamptz default null,p_cursor_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);
begin
  if p_limit is null or p_limit not between 1 and 100 or (p_cursor_created_at is null)<>(p_cursor_id is null) then
    raise sqlstate '22023' using message='Invalid notification page or cursor.';
  end if;
  return (with candidates as (
    select n.created_at,n.notification_id id,to_jsonb(n) item from public.list_own_notifications(actor,p_limit,p_cursor_created_at,p_cursor_id) n
    union all select n.created_at,n.id,jsonb_build_object('notification_id',n.id,'category_slug','participation',
      'notification_kind',n.kind,'destination_kind',n.kind,'contact_target_id',n.target_id,'created_at',n.created_at,'read_at',n.read_at)
      from private.contact_activity_notifications n where n.recipient_profile_id=actor
        and private.contact_activity_allowed(n.kind,n.target_id,actor,n.audience_version)
        and (p_cursor_id is null or (n.created_at,n.id)<(p_cursor_created_at,p_cursor_id))
  ), page as (select * from candidates order by created_at desc,id desc limit p_limit)
  select coalesce(jsonb_agg(item order by created_at desc,id desc),'[]') from page);
end; $$;
create function public.get_own_unread_notification_count_with_contacts(p_expected_profile_id uuid)
returns bigint language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id);
begin return public.get_own_unread_notification_count(actor)+(select count(*) from private.contact_activity_notifications n
  where n.recipient_profile_id=actor and n.read_at is null and private.contact_activity_allowed(n.kind,n.target_id,actor,n.audience_version)); end; $$;
create function public.mark_contact_or_legacy_notification_read(p_expected_profile_id uuid,p_notification_id uuid)
returns timestamptz language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id); n private.contact_activity_notifications; result timestamptz;
begin
  select * into n from private.contact_activity_notifications where id=p_notification_id;
  if not found then return public.mark_notification_read(actor,p_notification_id); end if;
  if n.recipient_profile_id<>actor or not private.contact_activity_allowed(n.kind,n.target_id,actor,n.audience_version) then
    raise sqlstate '42501' using message='The notification is unavailable.'; end if;
  update private.contact_activity_notifications set read_at=coalesce(read_at,clock_timestamp()) where id=n.id returning read_at into result;
  return result;
end; $$;
create function public.mark_all_notifications_with_contacts_read(p_expected_profile_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_notification_identity(p_expected_profile_id); contact_count integer; legacy_count integer;
begin
  legacy_count:=public.mark_all_notifications_read(actor);
  update private.contact_activity_notifications n set read_at=clock_timestamp() where n.recipient_profile_id=actor and n.read_at is null
    and private.contact_activity_allowed(n.kind,n.target_id,actor,n.audience_version);
  get diagnostics contact_count=row_count; return legacy_count+contact_count;
end; $$;

create function public.get_own_group_contact_preferences(p_expected_profile_id uuid,p_chat_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  if not private.group_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The conversation is unavailable.'; end if;
  return jsonb_build_object('muted',coalesce((select p.muted from private.group_contact_preferences p where p.profile_id=actor and p.conversation_id=p_chat_id),false));
end; $$;
-- Delivery eligibility is separate from history, unread and activity requests.
-- Any future configured message-alert worker must recheck it at delivery time.
create function private.group_contact_message_notice_allowed(p_chat_id uuid,p_actor uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select private.group_contact_can_send(p_chat_id,p_actor)
    and not coalesce((select p.muted from private.group_contact_preferences p
      where p.profile_id=p_actor and p.conversation_id=p_chat_id),false);
$$;
create function public.set_group_contact_muted(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_muted boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); hash text; receipt private.group_contact_receipts; result jsonb;
begin
  if p_action_id is null or p_chat_id is null or p_muted is null then raise sqlstate '22023' using message='Invalid conversation preference.'; end if;
  hash:=private.group_command_hash(jsonb_build_object('operation','mute','chat_id',p_chat_id,'muted',p_muted));
  perform pg_advisory_xact_lock(hashtextextended('group.contact.action:'||actor::text||':'||p_action_id::text,0));
  select * into receipt from private.group_contact_receipts where actor_id=actor and action_id=p_action_id;
  if found then
    if receipt.intent_hash<>hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return receipt.result||jsonb_build_object('replayed',true);
  end if;
  perform 1 from private.community_groups g where g.id in(select a.group_id from private.group_contact_admissions a where a.conversation_id=p_chat_id) order by g.id for share;
  perform private.require_group_identity(actor);
  if not private.group_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The conversation is unavailable.'; end if;
  insert into private.group_contact_preferences values(actor,p_chat_id,p_muted)
    on conflict(profile_id,conversation_id) do update set muted=excluded.muted;
  result:=jsonb_build_object('chat_id',p_chat_id,'outcome',case when p_muted then 'muted' else 'unmuted' end,'replayed',false);
  insert into private.group_contact_receipts values(actor,p_action_id,hash,result,clock_timestamp());
  -- Muting does not ACK, drop unread receipts, hide history or unsubscribe.
  perform private.group_contact_signal(actor); return result;
end; $$;

do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname in ('enqueue_contact_activity','contact_activity_allowed','contact_activity_candidates','process_contact_activity_batch','group_contact_message_notice_allowed'))
    or (n.nspname='public' and p.proname in ('process_notification_outbox_batch','list_own_notifications_with_contacts',
      'get_own_unread_notification_count_with_contacts','mark_contact_or_legacy_notification_read','mark_all_notifications_with_contacts_read',
      'get_own_group_contact_preferences','set_group_contact_muted'))
  loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to %I',f.signature,
      case when f.proname='process_notification_outbox_batch' then 'service_role' else 'authenticated' end); end if;
  end loop;
end; $$;
