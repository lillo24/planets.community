-- B02: versioned, additive mobile readers and identifier-only invalidation.
create function public.list_cocreate_topics() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 return (select coalesce(jsonb_agg(jsonb_build_object('topic_id',id,'label',label) order by label,id),'[]'::jsonb)
   from (select id,label from private.cocreate_topics where active order by label,id limit 100) t);
end; $$;

-- Keep installed readers' shapes. Mobile v2 adds only the source title, so
-- closed discovery posts still have distinguishable private conversations.
create function public.list_own_cocreate_interests_v2(p_expected_profile_id uuid,p_post_id uuid default null,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(i.value||jsonb_build_object('post_title',p.title) order by i.ordinality),'[]'::jsonb)
 from jsonb_array_elements(public.list_own_cocreate_interests(p_expected_profile_id,p_post_id,p_limit,p_before_created_at,p_before_id))
 with ordinality i(value,ordinality) join private.cocreate_posts p on p.id=(i.value->>'post_id')::uuid;
$$;
create function public.list_own_cocreate_contacts_v2(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(c.value||jsonb_build_object('post_title',p.title) order by c.ordinality),'[]'::jsonb)
 from jsonb_array_elements(public.list_own_cocreate_contacts(p_expected_profile_id,p_limit,p_before_created_at,p_before_id))
 with ordinality c(value,ordinality) join private.cocreate_posts p on p.id=(c.value->>'post_id')::uuid;
$$;
create function public.list_own_cocreate_contact_exits(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_identity(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.contact_id desc),'[]'::jsonb) from (
  select c.id contact_id,c.created_at from private.cocreate_contacts c
  where actor in(c.author_id,c.requester_id) and c.closed_at is null
   and (p_before_id is null or (c.created_at,c.id)<(p_before_created_at,p_before_id))
  order by c.created_at desc,c.id desc limit p_limit) t);
end; $$;
create function public.list_own_cocreate_interest_exits(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_identity(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.interest_id desc),'[]'::jsonb) from (
  select i.id interest_id,i.post_id,i.created_at from private.cocreate_interests i
  where i.requester_id=actor and i.state='pending'
   and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
  order by i.created_at desc,i.id desc limit p_limit) t);
end; $$;

create function private.cocreate_signal(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor) then
  perform realtime.send(jsonb_build_object('profile_id',p_actor),'cocreate.changed',
   'cocreate:profile:'||p_actor::text,true);
 end if;
end; $$;
create function public.can_receive_cocreate_signal(p_topic text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and p_topic='cocreate:profile:'||auth.uid()::text
  and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=auth.uid());
$$;
create policy cocreate_signal_receive on realtime.messages for select to authenticated
 using(extension='broadcast' and public.can_receive_cocreate_signal((select realtime.topic())));

create function private.cocreate_post_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid; source uuid;
begin
 if tg_table_name='cocreate_posts' then source:=new.id; else source:=new.post_id; end if;
 for person in select author_id from private.cocreate_posts where id=source
  union select requester_id from private.cocreate_interests where post_id=source
 loop perform private.cocreate_signal(person); end loop;
 return null;
end; $$;
create trigger cocreate_post_signal after insert or update on private.cocreate_posts
 for each row execute function private.cocreate_post_change_signal();
create trigger cocreate_interest_signal after insert or update on private.cocreate_interests
 for each row execute function private.cocreate_post_change_signal();

create function private.cocreate_contact_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare room private.cocreate_contacts;
begin
 if tg_table_name='cocreate_contacts' then room:=new;
 else select * into room from private.cocreate_contacts where id=new.contact_id; end if;
 perform private.cocreate_signal(room.author_id); perform private.cocreate_signal(room.requester_id);
 return null;
end; $$;
create trigger cocreate_contact_signal after insert or update on private.cocreate_contacts
 for each row execute function private.cocreate_contact_change_signal();
create trigger cocreate_message_signal after insert on private.cocreate_contact_messages
 for each row execute function private.cocreate_contact_change_signal();
create trigger cocreate_read_signal after insert or update on private.cocreate_contact_reads
 for each row execute function private.cocreate_contact_change_signal();

-- Block already owns its established lock order. This extension only sends
-- actor hints after converging pending requests, and takes no additional locks.
create or replace function private.close_cocreate_interests_for_user_block(p_blocker_profile_id uuid,p_blocked_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 update private.cocreate_interests i set state='declined' from private.cocreate_posts p
 where p.id=i.post_id and i.state='pending'
  and ((p.author_id=p_blocker_profile_id and i.requester_id=p_blocked_profile_id)
    or (p.author_id=p_blocked_profile_id and i.requester_id=p_blocker_profile_id));
 perform private.cocreate_signal(p_blocker_profile_id);
 perform private.cocreate_signal(p_blocked_profile_id);
end; $$;

create function private.cocreate_access_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if tg_table_name='cocreate_settings' then
  for person in select author_id from private.cocreate_posts union select requester_id from private.cocreate_interests
  loop perform private.cocreate_signal(person); end loop;
 else
  if not exists(select 1 from private.cocreate_posts where author_id=new.id)
   and not exists(select 1 from private.cocreate_interests where requester_id=new.id)
   and not exists(select 1 from private.cocreate_contacts where new.id in(author_id,requester_id)) then
    return null;
  end if;
  perform private.cocreate_signal(new.id);
  for person in select case when c.author_id=new.id then c.requester_id else c.author_id end
   from private.cocreate_contacts c where new.id in(c.author_id,c.requester_id)
  loop perform private.cocreate_signal(person); end loop;
 end if;
 return null;
end; $$;
create trigger cocreate_account_signal after update of banned_until,deleted_at on auth.users
 for each row when(old.banned_until is distinct from new.banned_until or old.deleted_at is distinct from new.deleted_at)
 execute function private.cocreate_access_change_signal();
create trigger cocreate_profile_signal after update of display_name on public.profiles
 for each row when(old.display_name is distinct from new.display_name)
 execute function private.cocreate_access_change_signal();
create function private.cocreate_deleted_account_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in select case when c.author_id=old.id then c.requester_id else c.author_id end
  from private.cocreate_contacts c where old.id in(c.author_id,c.requester_id)
 loop perform private.cocreate_signal(person); end loop;
 return null;
end; $$;
create trigger cocreate_account_delete_signal after delete on auth.users
 for each row execute function private.cocreate_deleted_account_signal();
create trigger cocreate_gate_signal after update on private.cocreate_settings
 for each row execute function private.cocreate_access_change_signal();

create function public.get_own_message_unread_summary_with_cocreate(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); legacy jsonb; extra bigint:=0;
begin
 legacy:=public.get_own_message_unread_summary_with_contacts_and_discussions(actor);
 -- Disabled experiments add nothing; native unread stays available. Do not
 -- count loaded pages, closed discovery posts or synthetic Demo rows.
 if exists(select 1 from private.cocreate_settings c join private.policy_acceptances a
   on a.bundle_version=c.policy_bundle_version and a.account_id=actor where c.enabled)
   and private.cocreate_account_available(actor) then
  select count(*) into extra from private.cocreate_contacts c
  left join private.cocreate_contact_reads r on r.contact_id=c.id and r.actor_id=actor
  where actor in(c.author_id,c.requester_id)
   and private.cocreate_account_available(c.author_id) and private.cocreate_account_available(c.requester_id)
   and not private.has_active_user_block_between(c.author_id,c.requester_id)
   and not exists(select 1 from private.cocreate_posts p where p.id=c.post_id and p.suppressed)
   and exists(select 1 from private.cocreate_contact_messages m where m.contact_id=c.id
    and m.sender_id<>actor and m.sequence>coalesce(r.read_sequence,0));
 end if;
 return jsonb_build_object('total',(legacy->>'total')::bigint+extra,
   'private',(legacy->>'private')::bigint+extra,'groups',(legacy->>'groups')::bigint);
end; $$;

revoke all on function public.list_cocreate_topics() from public,anon,authenticated,service_role;
grant execute on function public.list_cocreate_topics() to anon,authenticated;
revoke all on function public.can_receive_cocreate_signal(text),public.get_own_message_unread_summary_with_cocreate(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.can_receive_cocreate_signal(text),public.get_own_message_unread_summary_with_cocreate(uuid) to authenticated;
revoke all on function public.list_own_cocreate_interests_v2(uuid,uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_contacts_v2(uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_contact_exits(uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_interest_exits(uuid,integer,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_own_cocreate_interests_v2(uuid,uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_contacts_v2(uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_contact_exits(uuid,integer,timestamptz,uuid),
 public.list_own_cocreate_interest_exits(uuid,integer,timestamptz,uuid) to authenticated;
revoke all on function private.cocreate_signal(uuid),private.cocreate_post_change_signal(),
 private.cocreate_contact_change_signal(),private.cocreate_access_change_signal(),
 private.cocreate_deleted_account_signal(),
 private.close_cocreate_interests_for_user_block(uuid,uuid) from public,anon,authenticated,service_role;
