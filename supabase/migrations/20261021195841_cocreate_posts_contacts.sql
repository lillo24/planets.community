-- B01: people-seeking posts and consent-based post-scoped contacts.
-- Private tables, never native Projects or registered Groups.
alter table private.cocreate_settings
 add column max_drafts integer not null default 20 check(max_drafts between 1 and 100),
 add column contact_messages_per_minute integer not null default 30 check(contact_messages_per_minute between 1 and 120);
create table private.cocreate_topics (
  id uuid primary key default gen_random_uuid(),
  label text not null check(char_length(btrim(label)) between 1 and 80),
  active boolean not null default false
);
create table private.cocreate_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null,
  state text not null default 'draft' check(state in ('draft','open','closed')),
  title text not null default '' check(char_length(title)<=120 and title=btrim(title)),
  body text not null default '' check(char_length(body)<=1000 and body=btrim(body)),
  locality text not null default '' check(char_length(locality)<=100 and locality=btrim(locality)),
  topic_id uuid references private.cocreate_topics(id),
  version bigint not null default 1 check(version>0),
  suppressed boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz,
  check(state<>'open' or (title<>'' and body<>'' and locality<>'' and expires_at is not null))
);
create index cocreate_posts_page on private.cocreate_posts(created_at desc,id desc) where state='open' and not suppressed;
create index cocreate_posts_owner on private.cocreate_posts(author_id,created_at desc,id desc);
create table private.cocreate_interests (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references private.cocreate_posts(id),
  requester_id uuid not null,
  note text not null check(char_length(note)<=500 and note=btrim(note)),
  state text not null default 'pending' check(state in ('pending','accepted','declined','withdrawn')),
  created_at timestamptz not null default clock_timestamp()
);
create unique index cocreate_interest_active on private.cocreate_interests(post_id,requester_id) where state in ('pending','accepted');
create index cocreate_interest_owner on private.cocreate_interests(post_id,created_at desc,id desc);
create index cocreate_interest_requester on private.cocreate_interests(requester_id,created_at desc,id desc);
create table private.cocreate_contacts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references private.cocreate_posts(id),
  requester_id uuid not null,
  author_id uuid not null,
  last_sequence bigint not null default 0,
  closed_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  read_secret uuid not null default gen_random_uuid(),
  unique(post_id,requester_id),
  check(requester_id<>author_id)
);
create index cocreate_contacts_author on private.cocreate_contacts(author_id,created_at desc,id desc);
create index cocreate_contacts_requester on private.cocreate_contacts(requester_id,created_at desc,id desc);
create table private.cocreate_contact_messages (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references private.cocreate_contacts(id),
  sender_id uuid not null,
  sequence bigint not null check(sequence>0),
  body text not null check(char_length(body) between 1 and 2000 and body=btrim(body)),
  created_at timestamptz not null default clock_timestamp(),
  unique(contact_id,sequence)
);
create index cocreate_messages_sender on private.cocreate_contact_messages(sender_id,created_at desc);
create table private.cocreate_contact_reads (
  contact_id uuid not null references private.cocreate_contacts(id),
  actor_id uuid not null,
  read_sequence bigint not null default 0 check(read_sequence>=0),
  primary key(contact_id,actor_id)
);
create table private.cocreate_post_receipts (
  actor_id uuid not null,
  command_id uuid not null,
  intent_hash text not null,
  result jsonb not null,
  primary key(actor_id,command_id)
);
create function private.cocreate_immutable() returns trigger
language plpgsql security invoker set search_path='' as $$
begin raise sqlstate '55000' using message='Co-creation history is immutable.'; end;
$$;
create trigger cocreate_messages_immutable before update or delete on private.cocreate_contact_messages
for each row execute function private.cocreate_immutable();
create trigger cocreate_post_receipts_immutable before update or delete on private.cocreate_post_receipts
for each row execute function private.cocreate_immutable();
do $$ declare t text; begin
 foreach t in array array['cocreate_topics','cocreate_posts','cocreate_interests','cocreate_contacts','cocreate_contact_messages','cocreate_contact_reads','cocreate_post_receipts'] loop
  execute format('alter table private.%I enable row level security',t);
  execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
 end loop;
end; $$;

create function private.cocreate_post_public(p_post uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_posts p where p.id=p_post
  and p.state='open' and not p.suppressed and p.expires_at>statement_timestamp()
  and private.cocreate_account_available(p.author_id)
  and (p.topic_id is null or exists(select 1 from private.cocreate_topics t where t.id=p.topic_id and t.active)));
$$;
create function private.cocreate_public_post(p private.cocreate_posts) returns jsonb
language sql immutable security invoker set search_path='' as $$
 select jsonb_build_object('post_id',p.id,'title',p.title,'body',p.body,'locality',p.locality,
  'topic_id',p.topic_id,'created_at',p.created_at,'expires_at',p.expires_at);
$$;
create function private.cocreate_page(p_limit integer,p_time timestamptz,p_id uuid) returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
 if p_limit is null or p_limit not between 1 and 50 or (p_time is null)<>(p_id is null) then
  raise sqlstate '22023' using message='Invalid co-creation page.';
 end if;
end; $$;
create function public.list_cocreate_posts(p_search text default '',p_locality text default '',
 p_topic_id uuid default null,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.require_cocreate_enabled();
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 if p_search is null or p_locality is null or char_length(p_search)>120 or char_length(p_locality)>100 then
  raise sqlstate '22023' using message='Invalid co-creation filters.'; end if;
 select coalesce(jsonb_agg(private.cocreate_public_post(page::private.cocreate_posts) order by page.created_at desc,page.id desc),'[]'::jsonb) into result from (
  select p.* from private.cocreate_posts p where private.cocreate_post_public(p.id)
   and (p_topic_id is null or p.topic_id=p_topic_id)
   and (btrim(p_locality)='' or lower(p.locality)=lower(btrim(p_locality)))
   and (btrim(p_search)='' or strpos(lower(p.title||' '||p.body),lower(btrim(p_search)))>0)
   and (p_before_id is null or (p.created_at,p.id)<(p_before_created_at,p_before_id))
  order by p.created_at desc,p.id desc limit p_limit
 ) page;
 return result;
end; $$;
create function public.get_cocreate_post(p_post_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 return (select private.cocreate_public_post(p) from private.cocreate_posts p where p.id=p_post_id and private.cocreate_post_public(p.id));
end; $$;
create function public.list_own_cocreate_posts(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); result jsonb;
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.post_id desc),'[]'::jsonb) into result from (
  select p.id post_id,p.title,p.body,p.locality,p.topic_id,p.state,p.version,p.suppressed,p.created_at,p.expires_at
  from private.cocreate_posts p where p.author_id=actor
   and (p_before_id is null or (p.created_at,p.id)<(p_before_created_at,p_before_id))
  order by p.created_at desc,p.id desc limit p_limit
 ) page;
 return result;
end; $$;
create function public.mutate_cocreate_post(p_expected_profile_id uuid,p_command_id uuid,p_operation text,
 p_post_id uuid default null,p_expected_version bigint default null,p_content jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 post private.cocreate_posts%rowtype; prior private.cocreate_post_receipts%rowtype;
 intent text; result jsonb; topic uuid;
begin
 if p_command_id is null or p_operation is null or p_operation not in ('create','edit','publish','close','renew')
  or p_content is null or jsonb_typeof(p_content)<>'object'
  or exists(select 1 from jsonb_object_keys(p_content) k where k not in ('title','body','locality','topic_id'))
  or exists(select 1 from jsonb_each(p_content) e where e.value<>'null'::jsonb and jsonb_typeof(e.value)<>'string')
  or (p_operation='create' and (p_post_id is not null or p_expected_version is not null))
  or (p_operation<>'create' and (p_post_id is null or p_expected_version is null))
  or (p_operation not in ('create','edit') and p_content<>'{}'::jsonb) then
  raise sqlstate '22023' using message='Invalid post command.';
 end if;
 intent:=private.group_command_hash(jsonb_build_array(p_operation,p_post_id,p_expected_version,p_content));
 -- Actor serialization also bounds simultaneous open/renew operations.
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 perform private.require_cocreate_actor(actor);
 select * into prior from private.cocreate_post_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The co-creation command intent differs.'; end if;
  return prior.result;
 end if;
 if p_operation='create' then
  -- Draft storage is bounded too; no unbounded private draft-spam surface.
  if (select count(*) from private.cocreate_posts where author_id=actor and state='draft')>=(select max_drafts from private.cocreate_settings) then
   raise sqlstate 'PT429' using message='The draft limit was reached.'; end if;
  insert into private.cocreate_posts(author_id) values(actor) returning * into post;
 else
  select * into post from private.cocreate_posts where id=p_post_id for update;
  if not found or post.author_id<>actor then raise sqlstate '42501' using message='The post is unavailable.'; end if;
  if post.version<>p_expected_version then raise sqlstate 'PT409' using message='The post changed. Refresh before retrying.'; end if;
 end if;
 if p_operation in ('create','edit') then
  if post.state='closed' then raise sqlstate '55000' using message='Renew the post before editing.'; end if;
  if p_content ? 'topic_id' then topic:=(p_content->>'topic_id')::uuid; else topic:=post.topic_id; end if;
  if topic is not null and not exists(select 1 from private.cocreate_topics where id=topic and active) then
   raise sqlstate '22023' using message='The curated topic is unavailable.'; end if;
  update private.cocreate_posts set
   title=case when p_content ? 'title' then btrim(coalesce(p_content->>'title','')) else title end,
   body=case when p_content ? 'body' then btrim(coalesce(p_content->>'body','')) else body end,
   locality=case when p_content ? 'locality' then btrim(coalesce(p_content->>'locality','')) else locality end,
   topic_id=topic where id=post.id returning * into post;
 elsif p_operation in ('publish','renew') then
  if post.suppressed or post.title='' or post.body='' or post.locality='' then
   raise sqlstate '22023' using message='A public title, description and broad locality are required.'; end if;
  if p_operation='publish' and post.state<>'draft' then raise sqlstate '55000' using message='The post is not a draft.'; end if;
  if p_operation='renew' and post.state='draft' then raise sqlstate '55000' using message='Publish the draft deliberately before renewal.'; end if;
  if post.topic_id is not null and not exists(select 1 from private.cocreate_topics where id=post.topic_id and active) then
   raise sqlstate '22023' using message='The curated topic is unavailable.'; end if;
  if (select count(*) from private.cocreate_posts p where p.author_id=actor and p.id<>post.id
    and p.state='open' and p.expires_at>clock_timestamp()) >= (select max_open_posts from private.cocreate_settings) then
   raise sqlstate 'PT429' using message='The open post limit was reached.'; end if;
  update private.cocreate_posts set state='open',
   expires_at=clock_timestamp()+make_interval(days=>(select post_lifetime_days from private.cocreate_settings))
   where id=post.id returning * into post;
 elsif p_operation='close' then
  update private.cocreate_posts set state='closed' where id=post.id returning * into post;
  update private.cocreate_interests set state='declined' where post_id=post.id and state='pending';
 end if;
 update private.cocreate_posts set version=version+case when p_operation='create' then 0 else 1 end
  where id=post.id returning * into post;
 result:=jsonb_build_object('post_id',post.id,'version',post.version,'state',post.state);
 insert into private.cocreate_post_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata)
 values('cocreate.post.'||p_operation,'cocreate_post',post.id,jsonb_build_object('actor_id',actor,'version',post.version));
 return result;
end; $$;

create function private.require_cocreate_contact(p_contact uuid,p_actor uuid) returns private.cocreate_contacts
language plpgsql stable security definer set search_path='' as $$
declare room private.cocreate_contacts%rowtype;
begin
 perform private.require_cocreate_actor(p_actor);
 select * into room from private.cocreate_contacts where id=p_contact;
 if not found or p_actor not in (room.author_id,room.requester_id)
  or not private.cocreate_account_available(room.author_id)
  or not private.cocreate_account_available(room.requester_id)
  or exists(select 1 from private.cocreate_posts p where p.id=room.post_id and p.suppressed)
  or private.has_active_user_block_between(room.author_id,room.requester_id) then
  raise sqlstate '42501' using message='The contact is unavailable.'; end if;
 return room;
end; $$;
create function public.mutate_cocreate_interest(p_expected_profile_id uuid,p_command_id uuid,p_post_id uuid,
 p_operation text,p_interest_id uuid default null,p_note text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; post private.cocreate_posts%rowtype; interest private.cocreate_interests%rowtype;
 prior private.cocreate_post_receipts%rowtype; intent text; result jsonb; contact uuid; counterparty uuid;
begin
 -- Withdrawal is an own-exit path, available even with gate OFF.
 actor:=case when p_operation='withdraw' then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_command_id is null or p_post_id is null or p_operation is null
  or p_operation not in ('request','accept','decline','withdraw') or p_note is null or char_length(p_note)>500
  or (p_operation='request' and p_interest_id is not null)
  or (p_operation<>'request' and (p_interest_id is null or p_note<>'')) then
  raise sqlstate '22023' using message='Invalid interest command.'; end if;
 intent:=private.group_command_hash(jsonb_build_array('interest',p_post_id,p_operation,p_interest_id,p_note));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 select * into post from private.cocreate_posts where id=p_post_id;
 if not found then raise sqlstate '42501' using message='The post is unavailable.'; end if;
 counterparty:=case when p_operation='request' then actor else
  (select requester_id from private.cocreate_interests where id=p_interest_id and post_id=post.id) end;
 -- Same pair-before-domain order as canonical block activation.
 if counterparty is not null then perform private.lock_user_interaction_pair(post.author_id,counterparty); end if;
 select * into post from private.cocreate_posts where id=p_post_id for update;
 if p_operation<>'withdraw' then perform private.require_cocreate_actor(actor); end if;
 select * into prior from private.cocreate_post_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The co-creation command intent differs.'; end if;
  return prior.result;
 end if;
 if p_operation='request' then
  if not private.cocreate_post_public(post.id) or post.expires_at<=clock_timestamp()
   or post.author_id=actor or private.has_active_user_block_between(post.author_id,actor) then
   raise sqlstate '42501' using message='The request is unavailable.'; end if;
  if exists(select 1 from private.cocreate_interests where requester_id=actor and post_id=post.id and state in ('pending','accepted')) then
   raise sqlstate 'PT409' using message='An active interest already exists.'; end if;
  if exists(select 1 from private.cocreate_interests i where i.requester_id=actor
   and i.created_at>clock_timestamp()-make_interval(secs=>(select request_cooldown_seconds from private.cocreate_settings))) then
   raise sqlstate 'PT429' using message='Wait before sending another interest.'; end if;
  insert into private.cocreate_interests(post_id,requester_id,note)
   values(post.id,actor,btrim(p_note)) returning * into interest;
 else
  select * into interest from private.cocreate_interests where id=p_interest_id and post_id=post.id for update;
  if not found or (p_operation='withdraw' and interest.requester_id<>actor)
   or (p_operation<>'withdraw' and post.author_id<>actor) then
   raise sqlstate '42501' using message='The interest is unavailable.'; end if;
  if interest.state<>'pending' then raise sqlstate 'PT409' using message='The interest was already resolved.'; end if;
  if p_operation='accept' then
   if not private.cocreate_post_public(post.id) or post.expires_at<=clock_timestamp()
    or not private.cocreate_account_available(interest.requester_id)
    or not exists(select 1 from private.policy_acceptances a join private.cocreate_settings c
      on c.singleton and a.bundle_version=c.policy_bundle_version where a.account_id=interest.requester_id)
    or private.has_active_user_block_between(post.author_id,interest.requester_id) then
    raise sqlstate '42501' using message='The request can no longer be accepted.'; end if;
   insert into private.cocreate_contacts(post_id,author_id,requester_id)
    values(post.id,post.author_id,interest.requester_id)
    on conflict(post_id,requester_id) do nothing;
   select id into contact from private.cocreate_contacts where post_id=post.id and requester_id=interest.requester_id;
  end if;
  update private.cocreate_interests set state=case p_operation when 'accept' then 'accepted' when 'decline' then 'declined' else 'withdrawn' end
   where id=interest.id returning * into interest;
 end if;
 result:=jsonb_build_object('interest_id',interest.id,'state',interest.state,'contact_id',contact);
 insert into private.cocreate_post_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;
create function public.list_own_cocreate_interests(p_expected_profile_id uuid,p_post_id uuid default null,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); result jsonb;
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.interest_id desc),'[]'::jsonb) into result from (
  select i.id interest_id,i.post_id,i.requester_id,i.note,i.state,i.created_at,c.id contact_id
  from private.cocreate_interests i join private.cocreate_posts p on p.id=i.post_id
  left join private.cocreate_contacts c on c.post_id=i.post_id and c.requester_id=i.requester_id
  where (i.requester_id=actor or p.author_id=actor) and (p_post_id is null or p.id=p_post_id)
   and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
  order by i.created_at desc,i.id desc limit p_limit
 ) page;
 return result;
end; $$;
create function private.cocreate_read_token(p_room private.cocreate_contacts,p_actor uuid,p_sequence bigint) returns text
language sql immutable security invoker set search_path='' as $$
 select p_sequence::text||'.'||encode(extensions.hmac(
  p_room.id::text||':'||p_actor::text||':'||p_sequence::text,p_room.read_secret::text,'sha256'),'hex');
$$;
create function public.get_cocreate_contact_page(p_expected_profile_id uuid,p_contact_id uuid,
 p_limit integer default 30,p_before_sequence bigint default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 room private.cocreate_contacts:=private.require_cocreate_contact(p_contact_id,actor); messages jsonb;
begin
 if p_limit is null or p_limit not between 1 and 50 or p_before_sequence<1 then
  raise sqlstate '22023' using message='Invalid contact page.'; end if;
 select coalesce(jsonb_agg(to_jsonb(page) order by page.sequence desc),'[]'::jsonb) into messages from (
  select m.id message_id,m.sender_id,m.sequence,m.body,m.created_at from private.cocreate_contact_messages m
  where m.contact_id=room.id and (p_before_sequence is null or m.sequence<p_before_sequence)
  order by m.sequence desc limit p_limit
 ) page;
 return jsonb_build_object('profile_id',actor,'contact_id',room.id,'closed',room.closed_at is not null,
  'messages',messages,'read_token',case when p_before_sequence is null and room.last_sequence>0
   then private.cocreate_read_token(room,actor,room.last_sequence) else null end);
end; $$;
create function public.mutate_cocreate_contact(p_expected_profile_id uuid,p_command_id uuid,p_contact_id uuid,
 p_operation text,p_body text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; room private.cocreate_contacts%rowtype; prior private.cocreate_post_receipts%rowtype;
 intent text; result jsonb; message uuid;
begin
 actor:=case when p_operation='close' then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_command_id is null or p_contact_id is null or p_operation is null or p_operation not in ('send','close')
  or p_body is null or (p_operation='close' and p_body<>'') or (p_operation='send' and char_length(btrim(p_body)) not between 1 and 2000) then
  raise sqlstate '22023' using message='Invalid contact command.'; end if;
 intent:=private.group_command_hash(jsonb_build_array('contact',p_contact_id,p_operation,p_body));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 select * into room from private.cocreate_contacts where id=p_contact_id;
 if found then perform private.lock_user_interaction_pair(room.author_id,room.requester_id); end if;
 select * into room from private.cocreate_contacts where id=p_contact_id for update;
 if not found or actor not in (room.author_id,room.requester_id) then
  raise sqlstate '42501' using message='The contact is unavailable.'; end if;
 if p_operation<>'close' then perform private.require_cocreate_contact(room.id,actor); end if;
 select * into prior from private.cocreate_post_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The co-creation command intent differs.'; end if;
  return prior.result;
 end if;
 if p_operation='close' then
  update private.cocreate_contacts set closed_at=coalesce(closed_at,clock_timestamp()) where id=room.id;
 else
  if room.closed_at is not null then raise sqlstate '55000' using message='The contact is closed.'; end if;
  if (select count(*) from private.cocreate_contact_messages where sender_id=actor and created_at>clock_timestamp()-interval '1 minute')>=(select contact_messages_per_minute from private.cocreate_settings) then
   raise sqlstate 'PT429' using message='The message limit was reached.'; end if;
  update private.cocreate_contacts set last_sequence=last_sequence+1 where id=room.id returning * into room;
  insert into private.cocreate_contact_messages(contact_id,sender_id,sequence,body)
   values(room.id,actor,room.last_sequence,btrim(p_body)) returning id into message;
 end if;
 result:=jsonb_build_object('contact_id',room.id,'message_id',message,'operation',p_operation);
 insert into private.cocreate_post_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;
create function public.acknowledge_cocreate_contact(p_expected_profile_id uuid,p_contact_id uuid,p_read_token text)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 room private.cocreate_contacts%rowtype; sequence bigint;
begin
 select * into room from private.cocreate_contacts where id=p_contact_id for update;
 perform private.require_cocreate_contact(p_contact_id,actor);
 if p_read_token is null or p_read_token !~ '^[0-9]{1,18}\.[0-9a-f]{64}$' then
  raise sqlstate '22023' using message='Invalid rendered-page receipt.'; end if;
 sequence:=split_part(p_read_token,'.',1)::bigint;
 if sequence<1 or sequence>room.last_sequence or p_read_token<>private.cocreate_read_token(room,actor,sequence) then
  raise sqlstate '42501' using message='Invalid rendered-page receipt.'; end if;
 insert into private.cocreate_contact_reads(contact_id,actor_id,read_sequence) values(room.id,actor,sequence)
 on conflict(contact_id,actor_id) do update set read_sequence=greatest(private.cocreate_contact_reads.read_sequence,excluded.read_sequence);
end; $$;
create function public.list_own_cocreate_contacts(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); result jsonb;
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.contact_id desc),'[]'::jsonb) into result from (
  select c.id contact_id,c.post_id,c.created_at,c.closed_at,
   (select count(*) from private.cocreate_contact_messages m where m.contact_id=c.id and m.sender_id<>actor
    and m.sequence>coalesce(r.read_sequence,0)) unread_count
  from private.cocreate_contacts c left join private.cocreate_contact_reads r on r.contact_id=c.id and r.actor_id=actor
  where actor in (c.author_id,c.requester_id)
   and private.cocreate_account_available(c.author_id) and private.cocreate_account_available(c.requester_id)
   and not exists(select 1 from private.cocreate_posts p where p.id=c.post_id and p.suppressed)
   and not private.has_active_user_block_between(c.author_id,c.requester_id)
   and (p_before_id is null or (c.created_at,c.id)<(p_before_created_at,p_before_id))
  order by c.created_at desc,c.id desc limit p_limit
 ) page;
 return result;
end; $$;

-- No implicit function grant, even when the domain is disabled.
do $$ declare f record; begin
 for f in select oid::regprocedure signature,proname,pronamespace from pg_proc
  where pronamespace in ('public'::regnamespace,'private'::regnamespace) and proname like '%cocreate%'
 loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.pronamespace='public'::regnamespace then
   execute format('grant execute on function %s to authenticated',f.signature);
   if f.proname in ('get_cocreate_availability','list_cocreate_posts','get_cocreate_post') then
    execute format('grant execute on function %s to anon',f.signature);
   end if;
  end if;
 end loop;
end; $$;
-- Compose canonical block activation without replacing any predecessor domain.
do $$ declare definition text:=pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure);
begin
 execute replace(definition,'FUNCTION private.close_pending_direct_requests_for_user_block(',
  'FUNCTION private.close_pre_cocreate_direct_requests_for_user_block(');
end; $$;
create or replace function private.close_pending_direct_requests_for_user_block(p_blocker_profile_id uuid,p_blocked_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.close_pre_cocreate_direct_requests_for_user_block(p_blocker_profile_id,p_blocked_profile_id);
 update private.cocreate_interests i set state='declined' from private.cocreate_posts p
 where p.id=i.post_id and i.state='pending'
  and ((p.author_id=p_blocker_profile_id and i.requester_id=p_blocked_profile_id)
    or (p.author_id=p_blocked_profile_id and i.requester_id=p_blocker_profile_id));
end; $$;
revoke all on function private.close_pre_cocreate_direct_requests_for_user_block(uuid,uuid),
 private.close_pending_direct_requests_for_user_block(uuid,uuid) from public,anon,authenticated,service_role;

alter table private.moderation_cases add column target_cocreate_id uuid,
 add column cocreate_evidence jsonb,
 add constraint moderation_cases_cocreate_shape check(
  (target_kind in ('cocreate_post','cocreate_interest','cocreate_contact_message'))=(target_cocreate_id is not null)
  and (target_cocreate_id is null)=(cocreate_evidence is null));
do $$ declare name text; expression text; begin
 foreach name in array array['moderation_cases_target_kind_valid','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid','moderation_cases_one_typed_target'] loop
  select pg_get_expr(conbin,conrelid) into expression from pg_constraint
   where conrelid='private.moderation_cases'::regclass and conname=name;
  if expression is null then raise exception 'Missing predecessor moderation constraint: %',name; end if;
  if name='moderation_cases_one_typed_target' then
   expression:=replace(expression,'num_nonnulls(','num_nonnulls(target_cocreate_id,');
  elsif name='moderation_cases_context_shape_valid' then
   expression:='('||expression||') or (target_kind in (''cocreate_post'',''cocreate_interest'',''cocreate_contact_message'') and num_nonnulls(project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0)';
  else expression:='('||expression||') or target_kind in (''cocreate_post'',''cocreate_interest'',''cocreate_contact_message'')'; end if;
  execute format('alter table private.moderation_cases drop constraint %I, add constraint %I check (%s)',name,name,expression);
 end loop;
end; $$;
create function private.protect_cocreate_report_identity() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.target_cocreate_id is distinct from old.target_cocreate_id
  or new.cocreate_evidence is distinct from old.cocreate_evidence then
  raise sqlstate '55000' using message='Moderation evidence is immutable.'; end if;
 return new;
end; $$;
create trigger moderation_cases_cocreate_identity before update on private.moderation_cases
for each row execute function private.protect_cocreate_report_identity();
create function public.submit_cocreate_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,
 p_target_kind text,p_target_id uuid,p_category text,p_explanation text)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_moderation_identity(p_expected_reporter_profile_id,true);
 explanation text:=btrim(p_explanation); evidence jsonb; subject uuid; post private.cocreate_posts%rowtype;
 interest private.cocreate_interests%rowtype; message private.cocreate_contact_messages%rowtype;
 room private.cocreate_contacts%rowtype; prior record; new_case private.moderation_cases%rowtype;
 new_report private.moderation_reports%rowtype;
begin
 if p_client_submission_id is null or p_target_id is null or p_target_kind is null
  or p_target_kind not in ('cocreate_post','cocreate_interest','cocreate_contact_message')
  or p_category is null or p_category not in ('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other')
  or explanation is null or char_length(explanation) not between 10 and 4000 then
  raise sqlstate '22023' using message='Invalid co-creation report.'; end if;
 perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
 select r.id,r.case_id,c.state,r.created_at,r.category,r.explanation,c.target_kind,c.target_cocreate_id
 into prior from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id
 where r.reporter_profile_id=actor and r.client_submission_id=p_client_submission_id;
 if found then
  if prior.target_cocreate_id is distinct from p_target_id or prior.target_kind<>p_target_kind
   or prior.category<>p_category or prior.explanation<>explanation then
   raise sqlstate '22023' using message='The report identity was reused.'; end if;
  return query select prior.id,prior.case_id,prior.state,prior.created_at; return;
 end if;
 if p_target_kind='cocreate_post' then
  perform private.require_cocreate_enabled();
  select * into post from private.cocreate_posts where id=p_target_id;
  if not found or not private.cocreate_post_public(post.id) then raise sqlstate '42501' using message='The report target is unavailable.'; end if;
  subject:=post.author_id; evidence:=private.cocreate_public_post(post);
 elsif p_target_kind='cocreate_interest' then
  select * into interest from private.cocreate_interests where id=p_target_id;
  select * into post from private.cocreate_posts where id=interest.post_id;
  if interest.id is null or actor not in (post.author_id,interest.requester_id) then raise sqlstate '42501' using message='The report target is unavailable.'; end if;
  subject:=interest.requester_id;
  evidence:=jsonb_build_object('interest_id',interest.id,'post_id',post.id,'note',interest.note,'created_at',interest.created_at);
 else
  select * into message from private.cocreate_contact_messages where id=p_target_id;
  select * into room from private.cocreate_contacts where id=message.contact_id;
  if message.id is null or actor not in (room.author_id,room.requester_id) then raise sqlstate '42501' using message='The report target is unavailable.'; end if;
  subject:=message.sender_id;
  evidence:=jsonb_build_object('message_id',message.id,'contact_id',room.id,'post_id',room.post_id,
   'sender_id',subject,'body',message.body,'created_at',message.created_at);
 end if;
 if subject=actor then raise sqlstate '22023' using message='A profile cannot report itself.'; end if;
 if not exists(select 1 from public.profiles p join auth.users a on a.id=p.id where p.id=subject and p.display_name is not null and a.deleted_at is null) then
  raise sqlstate '42501' using message='The report target is unavailable.'; end if;
 insert into private.moderation_cases(subject_profile_id,target_kind,target_cocreate_id,cocreate_evidence)
 values(subject,p_target_kind,p_target_id,evidence) returning * into new_case;
 insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
 values(new_case.id,actor,p_client_submission_id,p_category,explanation,new_case.created_at) returning * into new_report;
 insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at)
 values(new_case.id,actor,'report_received','received',0,new_case.created_at);
 insert into private.audit_events(action,target_type,target_id,metadata)
 values('moderation.report_submitted','moderation_case',new_case.id,jsonb_build_object('actor_id',actor,'report_id',new_report.id,'target_kind',p_target_kind));
 return query select new_report.id,new_case.id,new_case.state,new_report.created_at;
end; $$;
do $$ declare definition text:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure);
begin
 execute replace(definition,'FUNCTION public.submit_moderation_report(','FUNCTION private.submit_pre_cocreate_report(');
end; $$;
create or replace function public.submit_moderation_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,
 p_category text,p_explanation text,p_target_kind text,p_target_id uuid,p_context_kind text default null,p_context_id uuid default null)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_moderation_identity(p_expected_reporter_profile_id,true);
begin
 perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
 if p_target_kind in ('cocreate_post','cocreate_interest','cocreate_contact_message') then
  if p_context_kind is not null or p_context_id is not null then raise sqlstate '22023' using message='The report context is invalid.'; end if;
  return query select * from public.submit_cocreate_report(actor,p_client_submission_id,p_target_kind,p_target_id,p_category,p_explanation);
 else
  if exists(select 1 from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id
   where r.reporter_profile_id=actor and r.client_submission_id=p_client_submission_id and c.target_cocreate_id is not null) then
   raise sqlstate '22023' using message='The report identity was reused.'; end if;
  return query select * from private.submit_pre_cocreate_report(actor,p_client_submission_id,p_category,p_explanation,p_target_kind,p_target_id,p_context_kind,p_context_id);
 end if;
end; $$;
create function public.get_moderation_case_cocreate(p_expected_staff_profile_id uuid,p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare evidence jsonb; source private.cocreate_posts%rowtype;
begin
 perform private.require_moderation_staff(p_expected_staff_profile_id);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_cocreate_id is not null;
 if evidence is null then raise sqlstate '42501' using message='The report evidence is unavailable.'; end if;
 select * into source from private.cocreate_posts where id=(evidence->>'post_id')::uuid;
 return jsonb_build_object('evidence',evidence,'post_version',source.version,
  'post_suppressed',source.suppressed);
end; $$;
create function public.moderate_cocreate_post(p_expected_staff_profile_id uuid,p_command_id uuid,p_case_id uuid,p_expected_version bigint,p_suppressed boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=p_expected_staff_profile_id; post private.cocreate_posts%rowtype; source uuid;
 prior private.cocreate_post_receipts%rowtype; intent text; result jsonb;
begin
 perform private.require_moderation_staff(actor);
 if p_command_id is null or p_case_id is null or p_expected_version is null or p_suppressed is null then
  raise sqlstate '22023' using message='Invalid scoped moderation command.'; end if;
 intent:=private.group_command_hash(jsonb_build_array('moderation',p_case_id,p_expected_version,p_suppressed));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 perform private.require_moderation_staff(actor);
 select * into prior from private.cocreate_post_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The co-creation command intent differs.'; end if;
  return prior.result;
 end if;
 select (cocreate_evidence->>'post_id')::uuid into source from private.moderation_cases where id=p_case_id;
 select * into post from private.cocreate_posts where id=source for update;
 if not found then raise sqlstate '42501' using message='The reported post is unavailable.'; end if;
 if post.version<>p_expected_version then raise sqlstate 'PT409' using message='The post changed.'; end if;
 update private.cocreate_posts set suppressed=p_suppressed,version=version+1 where id=post.id returning * into post;
 result:=jsonb_build_object('post_id',post.id,'version',post.version,'suppressed',post.suppressed);
 insert into private.cocreate_post_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata)
 values('cocreate.post.moderated','cocreate_post',post.id,jsonb_build_object('actor_id',actor,'case_id',p_case_id,'version',post.version));
 return result;
end; $$;
revoke all on function private.protect_cocreate_report_identity(),private.submit_pre_cocreate_report(uuid,uuid,text,text,text,uuid,text,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.submit_cocreate_report(uuid,uuid,text,uuid,text,text),
 public.get_moderation_case_cocreate(uuid,uuid),public.moderate_cocreate_post(uuid,uuid,uuid,bigint,boolean)
 from public,anon,authenticated,service_role;
grant execute on function public.submit_cocreate_report(uuid,uuid,text,uuid,text,text),
 public.get_moderation_case_cocreate(uuid,uuid),public.moderate_cocreate_post(uuid,uuid,uuid,bigint,boolean)
 to authenticated;
comment on table private.cocreate_posts is 'Separate experimental post domain. Expiry is discovery eligibility, not retention. Raw actor provenance adds no new Auth/Profile erasure FK.';
comment on table private.cocreate_contacts is 'Exactly one accepted post-scoped bilateral contact per post/requester. No unsolicited DM or membership. Closing a post never deletes accepted history.';
