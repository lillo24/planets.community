-- COMM01: curated category -> named topic -> locality-scoped hub. No enrollment
-- follows proposal support. Legacy IDs, rooms, episodes and flat readers survive.
create table private.cocreate_categories (
 id text primary key check(id ~ '^[a-z][a-z_]{1,30}$'),
 label_en text not null check(char_length(label_en) between 1 and 60),
 label_it text not null check(char_length(label_it) between 1 and 60),
 icon text not null check(icon in('games','concerts','sports','travel','art','other')),
 sort_order integer not null unique check(sort_order>=0), active boolean not null default true
);
insert into private.cocreate_categories values
 ('videogames','Video games','Videogiochi','games',10,true),
 ('boardgames','Board games','Giochi da tavolo','games',20,true),
 ('concerts','Concerts','Concerti','concerts',30,true),
 ('sports','Sports','Sport','sports',40,true),
 ('travel','Travel','Viaggi','travel',50,true),
 ('art','Art','Arte','art',60,true),
 ('other','Other interests','Altri interessi','other',100,true);
alter table private.cocreate_topics add column category_id text not null default 'other'
 references private.cocreate_categories(id);
create index cocreate_topics_category on private.cocreate_topics(category_id,id);
alter table private.cocreate_settings
 add column community_activation_threshold integer not null default 3 check(community_activation_threshold between 3 and 10),
 add column community_proposals_per_day integer not null default 3 check(community_proposals_per_day between 1 and 20),
 add column community_pending_interests integer not null default 50 check(community_pending_interests between 1 and 200),
 add column community_proposal_lifetime_days integer not null default 30 check(community_proposal_lifetime_days between 1 and 90);
create function private.cocreate_normalize(p_text text) returns text
language sql immutable strict set search_path='' as $$
 select lower(btrim(regexp_replace(p_text,'[[:space:]]+',' ','g')));
$$;
create table private.cocreate_community_proposals (
 id uuid primary key default gen_random_uuid(), category_id text not null references private.cocreate_categories(id),
 name text not null check(name=btrim(name) and char_length(name) between 2 and 80),
 locality text not null check(locality=btrim(locality) and char_length(locality) between 1 and 100),
 explanation text not null default '' check(explanation=btrim(explanation) and char_length(explanation)<=500),
 normalized_name text generated always as(private.cocreate_normalize(name)) stored,
 normalized_locality text generated always as(private.cocreate_normalize(locality)) stored,
 proposer_id uuid not null, state text not null default 'pending' check(state in('pending','activated','cancelled','rejected')),
 suppressed boolean not null default false, hub_id uuid references private.cocreate_hubs(id),
 version bigint not null default 1 check(version>0), created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null, check(expires_at>created_at),check((state='activated')=(hub_id is not null))
);
create index cocreate_proposals_catalog on private.cocreate_community_proposals(category_id,created_at desc,id desc);
create index cocreate_proposals_owner_rate on private.cocreate_community_proposals(proposer_id,created_at desc);
create table private.cocreate_community_interests (
 proposal_id uuid not null references private.cocreate_community_proposals(id), actor_id uuid not null,
 interested boolean not null default true, created_at timestamptz not null default clock_timestamp(),
 primary key(proposal_id,actor_id)
);
create index cocreate_community_interests_actor on private.cocreate_community_interests(actor_id,proposal_id) where interested;
-- A normalized identity registry handles case/space variants without merging or
-- deleting old hubs. Existing ambiguous duplicates keep all their original IDs.
create table private.cocreate_community_identity (
 category_id text not null references private.cocreate_categories(id), name text not null, locality text not null,
 hub_id uuid references private.cocreate_hubs(id), proposal_id uuid references private.cocreate_community_proposals(id),
 primary key(category_id,name,locality)
);
insert into private.cocreate_community_identity(category_id,name,locality,hub_id)
 select distinct on(t.category_id,private.cocreate_normalize(t.label),private.cocreate_normalize(h.locality))
 t.category_id,private.cocreate_normalize(t.label),private.cocreate_normalize(h.locality),h.id
 from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
 order by t.category_id,private.cocreate_normalize(t.label),private.cocreate_normalize(h.locality),
 (h.active and not h.suppressed and t.active) desc,h.created_at,h.id;

create function private.cocreate_community_eligible(p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.cocreate_account_available(p_actor) and exists(select 1 from private.policy_acceptances a
 join private.cocreate_settings s on s.policy_bundle_version=a.bundle_version where s.singleton and a.account_id=p_actor);
$$;
create function private.cocreate_proposal_public(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_community_proposals p join private.cocreate_categories c on c.id=p.category_id
 where p.id=p_id and c.active and not p.suppressed and private.cocreate_community_eligible(p.proposer_id)
 and (p.state='activated' and private.cocreate_hub_public(p.hub_id) or p.state='pending' and p.expires_at>statement_timestamp()));
$$;
create function private.cocreate_proposal_support(p_id uuid) returns integer
language sql stable security definer set search_path='' as $$
 select count(*)::integer from private.cocreate_community_interests i join private.cocreate_community_proposals p on p.id=i.proposal_id
 where p.id=p_id and i.interested and private.cocreate_community_eligible(i.actor_id)
 and not private.has_active_user_block_between(i.actor_id,p.proposer_id);
$$;
create function private.cocreate_proposal_projection(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('proposal_id',p.id,'category_id',p.category_id,'name',p.name,'locality',p.locality,
 'explanation',p.explanation,'state',case when p.state='pending' and p.expires_at<=statement_timestamp() then 'expired' else p.state end,
 'interested_count',private.cocreate_proposal_support(p.id),'activation_threshold',s.community_activation_threshold,
 'hub_id',p.hub_id,'version',p.version,'created_at',p.created_at,'expires_at',p.expires_at)
 from private.cocreate_community_proposals p cross join private.cocreate_settings s where p.id=p_id and s.singleton;
$$;
create function public.list_cocreate_categories() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 return (select coalesce(jsonb_agg(jsonb_build_object('category_id',id,'label_en',label_en,'label_it',label_it,'icon',icon,'sort_order',sort_order) order by sort_order),'[]')
 from private.cocreate_categories where active);
end; $$;

-- Categories control discovery, including admission through retained exact IDs.
-- Existing topic IDs and flat result shapes are unchanged.
create or replace function private.cocreate_hub_public(p_hub uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
 join private.cocreate_categories c on c.id=t.category_id
 where h.id=p_hub and h.active and not h.suppressed and t.active and c.active);
$$;
create function public.list_cocreate_communities(p_category_id text,p_search text default '',p_locality text default '',
 p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 if p_category_id is null or p_search is null or char_length(p_search)>120 or p_locality is null or char_length(p_locality)>100 then
  raise sqlstate '22023' using message='Invalid community filters.';end if;
 return (with entries as (
  select h.created_at,h.id,jsonb_build_object('category_id',p_category_id,'kind','hub','hub',private.cocreate_hub_projection(h.id),'proposal',null) item
  from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id join private.cocreate_categories c on c.id=t.category_id
  where t.category_id=p_category_id and c.active and private.cocreate_hub_public(h.id)
  and (btrim(p_search)='' or strpos(private.cocreate_normalize(t.label),private.cocreate_normalize(p_search))>0)
  and (btrim(p_locality)='' or private.cocreate_normalize(h.locality)=private.cocreate_normalize(p_locality))
  union all
  select p.created_at,p.id,jsonb_build_object('category_id',p_category_id,'kind','proposal','hub',null,'proposal',private.cocreate_proposal_projection(p.id))
  from private.cocreate_community_proposals p where p.category_id=p_category_id and p.state='pending'
  and private.cocreate_proposal_public(p.id) and (auth.uid() is null or not private.has_active_user_block_between(auth.uid(),p.proposer_id))
  and (btrim(p_search)='' or strpos(p.normalized_name,private.cocreate_normalize(p_search))>0)
  and (btrim(p_locality)='' or p.normalized_locality=private.cocreate_normalize(p_locality))
 ), page as (select * from entries where p_before_id is null or (created_at,id)<(p_before_created_at,p_before_id)
  order by created_at desc,id desc limit p_limit)
 select coalesce(jsonb_agg(item order by created_at desc,id desc),'[]') from page);
end; $$;

create function public.get_cocreate_community_proposal(p_proposal_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 if private.cocreate_proposal_public(p_proposal_id) and not exists(select 1 from private.cocreate_community_proposals p
 where p.id=p_proposal_id and auth.uid() is not null and private.has_active_user_block_between(auth.uid(),p.proposer_id)) then
 return private.cocreate_proposal_projection(p_proposal_id);end if;
 return null;
end; $$;

create function public.propose_cocreate_community(p_expected_profile_id uuid,p_command_id uuid,p_category_id text,
 p_name text,p_locality text,p_explanation text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); prior private.cocreate_room_receipts;
 intent text; result jsonb; identity private.cocreate_community_identity; proposal uuid; hub uuid;
 v_name text:=btrim(regexp_replace(p_name,'[[:space:]]+',' ','g'));
 v_locality text:=btrim(regexp_replace(p_locality,'[[:space:]]+',' ','g')); v_explanation text:=btrim(p_explanation);
begin
 if p_command_id is null or p_category_id is null or v_name is null or char_length(v_name) not between 2 and 80
 or v_locality is null or char_length(v_locality) not between 1 and 100 or v_explanation is null or char_length(v_explanation)>500 then
 raise sqlstate '22023' using message='A bounded community name, broad locality and explanation are required.';end if;
 perform 1 from auth.users where id=actor for share;perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.catalog:'||p_category_id||':'||private.cocreate_normalize(v_name),0));
 perform 1 from private.cocreate_categories where id=p_category_id and active for share;
 if not found then raise sqlstate '42501' using message='This category is unavailable.';end if;
 intent:=private.group_command_hash(jsonb_build_array('propose_community',p_category_id,p_name,p_locality,p_explanation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
 if prior.intent_hash<>intent then raise sqlstate '22023' using message='The proposal command intent differs.';end if;
 return prior.result;end if;
 -- Also examine legacy/operator-created hubs added after registry installation.
 select h.id into hub from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
 where t.category_id=p_category_id and private.cocreate_normalize(t.label)=private.cocreate_normalize(v_name)
 and private.cocreate_normalize(h.locality)=private.cocreate_normalize(v_locality)
 order by (h.active and not h.suppressed and t.active) desc,h.created_at,h.id limit 1;
 select * into identity from private.cocreate_community_identity where category_id=p_category_id
 and name=private.cocreate_normalize(v_name) and locality=private.cocreate_normalize(v_locality);
 if hub is null and identity.hub_id is not null then
 select h.id into hub from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
 where h.id=identity.hub_id and t.category_id=p_category_id and private.cocreate_normalize(t.label)=private.cocreate_normalize(v_name)
 and private.cocreate_normalize(h.locality)=private.cocreate_normalize(v_locality);
 end if;
 if hub is not null then
 if not private.cocreate_hub_public(hub) then raise sqlstate 'PT409' using message='This community is unavailable; a duplicate cannot bypass it.';end if;
 else
 select p.id into proposal from private.cocreate_community_proposals p where p.id=identity.proposal_id and p.state='pending' and p.expires_at>clock_timestamp();
 if proposal is not null and (not private.cocreate_proposal_public(proposal) or exists(select 1 from private.cocreate_community_proposals existing where existing.id=proposal and private.has_active_user_block_between(actor,existing.proposer_id))) then
 raise sqlstate 'PT409' using message='This proposal is unavailable; a duplicate cannot bypass it.';end if;
 if proposal is null then
 if (select count(*) from private.cocreate_community_proposals where proposer_id=actor and created_at>clock_timestamp()-interval '24 hours')
 >=(select community_proposals_per_day from private.cocreate_settings) then raise sqlstate 'PT429' using message='The daily community proposal limit was reached.';end if;
 if (select count(*) from private.cocreate_community_interests i join private.cocreate_community_proposals p on p.id=i.proposal_id
 where i.actor_id=actor and i.interested and p.state='pending' and p.expires_at>clock_timestamp())
 >=(select community_pending_interests from private.cocreate_settings) then raise sqlstate 'PT429' using message='The pending community interest limit was reached.';end if;
 insert into private.cocreate_community_proposals(category_id,name,locality,explanation,proposer_id,expires_at)
 values(p_category_id,v_name,v_locality,v_explanation,actor,clock_timestamp()+make_interval(days=>(select community_proposal_lifetime_days from private.cocreate_settings))) returning id into proposal;
 insert into private.cocreate_community_interests(proposal_id,actor_id) values(proposal,actor);
 insert into private.cocreate_community_identity(category_id,name,locality,proposal_id)
 values(p_category_id,private.cocreate_normalize(v_name),private.cocreate_normalize(v_locality),proposal)
 on conflict(category_id,name,locality) do update set proposal_id=excluded.proposal_id;
 end if;end if;
 result:=jsonb_build_object('operation','propose','proposal_id',proposal,'hub_id',hub);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_signal(actor);return result;
end; $$;

create function public.mutate_cocreate_community_interest(p_expected_profile_id uuid,p_command_id uuid,p_proposal_id uuid,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; p private.cocreate_community_proposals; prior private.cocreate_room_receipts;
 intent text; result jsonb; topic uuid; hub uuid; person uuid; threshold integer;
begin
 actor:=case when p_operation in('withdraw','cancel') then private.require_cocreate_identity(p_expected_profile_id)
 else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_command_id is null or p_proposal_id is null or p_operation is null or p_operation not in('interest','withdraw','cancel') then
 raise sqlstate '22023' using message='Invalid community interest command.';end if;
 select * into p from private.cocreate_community_proposals where id=p_proposal_id;
 if not found then raise sqlstate '42501' using message='This proposal is unavailable.';end if;
 -- Shared account locks stabilize eligibility against ban/erasure while activating.
 perform 1 from auth.users where id in(select actor_id from private.cocreate_community_interests where proposal_id=p.id union select actor union select p.proposer_id) order by id for share;
 perform 1 from public.profiles where id in(select actor_id from private.cocreate_community_interests where proposal_id=p.id union select actor union select p.proposer_id) order by id for share;
 if p_operation='interest' then perform private.require_cocreate_actor(actor);end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 if p_operation='interest' and actor<>p.proposer_id then perform private.lock_user_interaction_pair(actor,p.proposer_id);end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.catalog:'||p.category_id||':'||p.normalized_name,0));
 select * into p from private.cocreate_community_proposals where id=p.id for update;
 intent:=private.group_command_hash(jsonb_build_array('community_interest',p_proposal_id,p_operation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
 if prior.intent_hash<>intent then raise sqlstate '22023' using message='The community interest intent differs.';end if;
 return prior.result;end if;
 if p.state<>'pending' or p.expires_at<=clock_timestamp() then raise sqlstate 'PT409' using message='This proposal is no longer pending.';end if;
 if p_operation='cancel' then
 if p.proposer_id<>actor then raise sqlstate '42501' using message='Only the proposer cancels this pending proposal.';end if;
 update private.cocreate_community_proposals set state='cancelled',version=version+1 where id=p.id;
 elsif p_operation='withdraw' then
 update private.cocreate_community_interests set interested=false where proposal_id=p.id and actor_id=actor;
 update private.cocreate_community_proposals set version=version+1 where id=p.id;
 else
 if not private.cocreate_proposal_public(p.id) or private.has_active_user_block_between(actor,p.proposer_id) then
 raise sqlstate '42501' using message='This proposal is unavailable for this account.';end if;
 if not exists(select 1 from private.cocreate_community_interests where proposal_id=p.id and actor_id=actor and interested)
 and (select count(*) from private.cocreate_community_interests i join private.cocreate_community_proposals q on q.id=i.proposal_id
 where i.actor_id=actor and i.interested and q.state='pending' and q.expires_at>clock_timestamp())
 >=(select community_pending_interests from private.cocreate_settings) then raise sqlstate 'PT429' using message='The pending interest limit was reached.';end if;
 insert into private.cocreate_community_interests(proposal_id,actor_id) values(p.id,actor)
 on conflict(proposal_id,actor_id) do update set interested=true;
 select community_activation_threshold into threshold from private.cocreate_settings;
 if private.cocreate_proposal_support(p.id)>=threshold and exists(select 1 from private.cocreate_community_interests
 where proposal_id=p.id and actor_id=p.proposer_id and interested) then
 select h.id into hub from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
 where t.category_id=p.category_id and private.cocreate_normalize(t.label)=p.normalized_name
 and private.cocreate_normalize(h.locality)=p.normalized_locality order by h.created_at,h.id limit 1;
 if hub is null then
 select id into topic from private.cocreate_topics where category_id=p.category_id and private.cocreate_normalize(label)=p.normalized_name and active order by id limit 1;
 if topic is null then insert into private.cocreate_topics(label,active,category_id) values(p.name,true,p.category_id) returning id into topic;end if;
 insert into private.cocreate_hubs(topic_id,locality,active) values(topic,p.locality,true) returning id into hub;
 -- The existing canonical hub INSERT trigger creates its one General.
 else
 perform private.cocreate_lock_hub(hub);
 if not private.cocreate_hub_public(hub) then raise sqlstate 'PT409' using message='The matching hub is unavailable.';end if;
 end if;
 update private.cocreate_community_proposals set state='activated',hub_id=hub,version=version+1 where id=p.id;
 insert into private.cocreate_community_identity(category_id,name,locality,hub_id,proposal_id) values(p.category_id,p.normalized_name,p.normalized_locality,hub,p.id)
 on conflict(category_id,name,locality) do update set hub_id=excluded.hub_id,proposal_id=excluded.proposal_id;
 -- Persistent interested rows are the actor-private ready-to-join invitations.
 for person in select actor_id from private.cocreate_community_interests where proposal_id=p.id and interested loop
 perform private.cocreate_signal(person);end loop;
 else update private.cocreate_community_proposals set version=version+1 where id=p.id;end if;
 end if;
 result:=jsonb_build_object('operation',p_operation,'proposal_id',p.id,'hub_id',hub);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_signal(actor);return result;
end; $$;

create function public.list_own_cocreate_community_interests(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 return (select coalesce(jsonb_agg(jsonb_build_object('proposal',private.cocreate_proposal_projection(p.id),
 'is_proposer',p.proposer_id=actor,'interested',coalesce(i.interested,false),'ready_to_join',p.state='activated' and coalesce(i.interested,false)) order by p.created_at desc,p.id desc),'[]')
 from (select p.* from private.cocreate_community_proposals p left join private.cocreate_community_interests i on i.proposal_id=p.id and i.actor_id=actor
 where (p.proposer_id=actor or i.interested) and not p.suppressed and private.cocreate_community_eligible(p.proposer_id)
 and not private.has_active_user_block_between(actor,p.proposer_id)
 and (p.state<>'activated' or private.cocreate_hub_public(p.hub_id))
 and (p_before_id is null or (p.created_at,p.id)<(p_before_created_at,p_before_id))
 order by p.created_at desc,p.id desc limit p_limit)p
 left join private.cocreate_community_interests i on i.proposal_id=p.id and i.actor_id=actor);
end; $$;

do $$ declare t text; signature text;begin
 foreach t in array array['cocreate_categories','cocreate_community_proposals','cocreate_community_interests','cocreate_community_identity'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);end loop;
 foreach signature in array array[
 'private.cocreate_normalize(text)','private.cocreate_community_eligible(uuid)','private.cocreate_proposal_public(uuid)',
 'private.cocreate_proposal_support(uuid)','private.cocreate_proposal_projection(uuid)'] loop
 execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';end loop;
 foreach signature in array array[
 'public.list_cocreate_categories()','public.list_cocreate_communities(text,text,text,integer,timestamptz,uuid)',
 'public.get_cocreate_community_proposal(uuid)'] loop
 execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
 execute 'grant execute on function '||signature||' to anon,authenticated';end loop;
 foreach signature in array array[
 'public.propose_cocreate_community(uuid,uuid,text,text,text,text)',
 'public.mutate_cocreate_community_interest(uuid,uuid,uuid,text)',
 'public.list_own_cocreate_community_interests(uuid,integer,timestamptz,uuid)'] loop
 execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
 execute 'grant execute on function '||signature||' to authenticated';end loop;
end; $$;

alter table private.moderation_cases drop constraint moderation_cases_cocreate_shape,
 add constraint moderation_cases_cocreate_shape check(
 (target_kind in('cocreate_post','cocreate_interest','cocreate_contact_message','cocreate_room_message','cocreate_community_proposal'))=(target_cocreate_id is not null)
 and (target_cocreate_id is null)=(cocreate_evidence is null));
do $$ declare name text;expression text;source text;
 needle text:='if p_target_kind=''cocreate_post'' then';
begin
 foreach name in array array['moderation_cases_target_kind_valid','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid'] loop
 select pg_get_expr(conbin,conrelid) into expression from pg_constraint where conrelid='private.moderation_cases'::regclass and conname=name;
 if expression is null then raise exception 'Unknown moderation predecessor: %',name;end if;
 execute format('alter table private.moderation_cases drop constraint %I, add constraint %I check ((%s) or (target_kind=''cocreate_community_proposal'' and num_nonnulls(project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0))',name,name,expression);
 end loop;
 source:=pg_get_functiondef('public.submit_cocreate_report(uuid,uuid,text,uuid,text,text)'::regprocedure);
 if strpos(source,needle)=0 then raise exception 'Unknown co-creation report predecessor.';end if;
 source:=replace(source,'''cocreate_post'',''cocreate_interest'',''cocreate_contact_message''','''cocreate_post'',''cocreate_interest'',''cocreate_contact_message'',''cocreate_community_proposal''');
 source:=replace(source,needle,'if p_target_kind=''cocreate_community_proposal'' then
 perform private.require_cocreate_enabled();
 if not private.cocreate_proposal_public(p_target_id) then raise sqlstate ''42501'' using message=''The proposal report target is unavailable.'';end if;
 select proposer_id into subject from private.cocreate_community_proposals where id=p_target_id;
 evidence:=private.cocreate_proposal_projection(p_target_id);
 elsif p_target_kind=''cocreate_post'' then');
 execute source;
 source:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure);
 if strpos(source,'''cocreate_post'',''cocreate_interest'',''cocreate_contact_message''')=0 then raise exception 'Unknown report dispatch predecessor.';end if;
 execute replace(source,'''cocreate_post'',''cocreate_interest'',''cocreate_contact_message''','''cocreate_post'',''cocreate_interest'',''cocreate_contact_message'',''cocreate_community_proposal''');
end; $$;
create function public.get_moderation_case_cocreate_proposal(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare evidence jsonb; p private.cocreate_community_proposals;
begin
 perform private.require_moderation_staff(p_expected_staff_profile_id);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='cocreate_community_proposal';
 if evidence is null then raise sqlstate '42501' using message='The scoped proposal evidence is unavailable.';end if;
 select * into p from private.cocreate_community_proposals where id=(evidence->>'proposal_id')::uuid;
 return jsonb_build_object('evidence',evidence,'version',p.version,'suppressed',p.suppressed,'state',p.state);
end; $$;
create function public.moderate_cocreate_community_proposal(p_expected_staff_profile_id uuid,p_command_id uuid,
 p_case_id uuid,p_expected_version bigint,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=p_expected_staff_profile_id; p private.cocreate_community_proposals; evidence jsonb;
 intent text;prior private.cocreate_room_receipts;result jsonb;
begin
 perform private.require_moderation_staff(actor);
 if num_nulls(p_command_id,p_case_id,p_expected_version,p_operation)>0 or p_operation not in('suppress','restore','reject') then
 raise sqlstate '22023' using message='Invalid scoped proposal moderation command.';end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.require_moderation_staff(actor);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='cocreate_community_proposal';
 select * into p from private.cocreate_community_proposals where id=(evidence->>'proposal_id')::uuid;
 if p.id is null then raise sqlstate '42501' using message='The scoped proposal evidence is unavailable.';end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.catalog:'||p.category_id||':'||p.normalized_name,0));
 select * into p from private.cocreate_community_proposals where id=p.id for update;
 intent:=private.group_command_hash(jsonb_build_array('community_moderation',p_case_id,p_expected_version,p_operation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
 if prior.intent_hash<>intent then raise sqlstate '22023' using message='The proposal moderation intent differs.';end if;
 return prior.result;end if;
 if p.version<>p_expected_version then raise sqlstate 'PT409' using message='The proposal changed.';end if;
 if p_operation='reject' then
 if p.state<>'pending' then raise sqlstate 'PT409' using message='Only a pending proposal can be rejected.';end if;
 update private.cocreate_community_proposals set state='rejected',version=version+1 where id=p.id;
 else update private.cocreate_community_proposals set suppressed=p_operation='suppress',version=version+1 where id=p.id;end if;
 result:=jsonb_build_object('operation',p_operation,'proposal_id',p.id,'version',p.version+1);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata) values('cocreate.proposal.moderated','cocreate_community_proposal',p.id,
 jsonb_build_object('actor_id',actor,'case_id',p_case_id,'operation',p_operation,'version',p.version+1));
 perform private.cocreate_signal(p.proposer_id);return result;
end; $$;
revoke all on function public.get_moderation_case_cocreate_proposal(uuid,uuid),
 public.moderate_cocreate_community_proposal(uuid,uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.get_moderation_case_cocreate_proposal(uuid,uuid),
 public.moderate_cocreate_community_proposal(uuid,uuid,uuid,bigint,text) to authenticated;
