-- D03 PROVISIONAL REVIEW ONLY: explicit seats, exact audience consent, fresh room.
create table private.group_coordination_proposals (
  id uuid primary key default gen_random_uuid(),
  source_chat_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  initiator_id uuid not null,
  title text not null check(char_length(title) between 1 and 120),
  note text not null check(char_length(note) between 1 and 1000),
  status text not null default 'pending' check(status in ('pending','declined','canceled','active')),
  version bigint not null default 1 check(version>0),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default(clock_timestamp()+interval '7 days'),
  activity_at timestamptz not null default clock_timestamp(),
  ended_at timestamptz, ended_by uuid,
  room_id uuid unique references private.group_contact_conversations(id) on delete restrict,
  check(expires_at>created_at),
  check((status='pending')=(ended_at is null)),
  check((ended_at is null)=(ended_by is null)),
  check((status='active')=(room_id is not null))
);
create index group_coordination_initiator_page on private.group_coordination_proposals(initiator_id,activity_at desc,id desc);
create index group_coordination_source_idx on private.group_coordination_proposals(source_chat_id);
create table private.group_coordination_seats (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references private.group_coordination_proposals(id) on delete restrict,
  group_id uuid not null references private.community_groups(id) on delete restrict,
  source_admission_id uuid references private.group_contact_admissions(id) on delete restrict,
  profile_id uuid,
  delegate_id uuid references private.group_delegates(id) on delete restrict,
  claimed_at timestamptz,
  confirmed_version bigint,
  is_current boolean not null default true,
  check((profile_id is null)=(claimed_at is null)),
  check(profile_id is not null or (delegate_id is null and source_admission_id is null and confirmed_version is null))
);
create unique index group_coordination_one_group on private.group_coordination_seats(proposal_id,group_id) where is_current;
create unique index group_coordination_one_human on private.group_coordination_seats(proposal_id,profile_id) where is_current and profile_id is not null;
create index group_coordination_seat_actor_idx on private.group_coordination_seats(profile_id,proposal_id);
create index group_coordination_seat_group_idx on private.group_coordination_seats(group_id,proposal_id);
create index group_coordination_seat_source_idx on private.group_coordination_seats(source_admission_id);
create index group_coordination_seat_delegate_idx on private.group_coordination_seats(delegate_id);
create table private.group_coordination_seen (
  proposal_id uuid not null references private.group_coordination_proposals(id) on delete restrict,
  profile_id uuid not null,
  seen_at timestamptz not null default clock_timestamp(),
  primary key(proposal_id,profile_id)
);
alter table private.group_contact_conversations add column coordination_proposal_id uuid unique references private.group_coordination_proposals(id) on delete restrict;
alter table private.group_contact_conversations add constraint group_contact_conversation_origin check(
  (conversation_kind='bilateral' and request_id is not null and coordination_proposal_id is null) or
  (conversation_kind='coordination' and request_id is null and coordination_proposal_id is not null));
create trigger group_coordination_provenance before update on private.group_coordination_proposals for each row
  execute function private.protect_group_relationship_provenance('status','version','activity_at','ended_at','ended_by','room_id');
create function private.group_coordination_seat_provenance() returns trigger language plpgsql set search_path='' as $$
begin
  if (to_jsonb(new)-array['profile_id','delegate_id','claimed_at','confirmed_version','is_current'])<>
     (to_jsonb(old)-array['profile_id','delegate_id','claimed_at','confirmed_version','is_current']) or
     (old.profile_id is not null and (new.profile_id is distinct from old.profile_id or new.delegate_id is distinct from old.delegate_id or new.claimed_at is distinct from old.claimed_at)) or
     (not old.is_current and new.is_current) or
     (old.source_admission_id is not null and not new.is_current) then
    raise sqlstate '23514' using message='Coordination seat provenance is immutable.';
  end if;
  return new;
end; $$;
create trigger group_coordination_seat_provenance before update on private.group_coordination_seats for each row execute function private.group_coordination_seat_provenance();
alter table private.group_coordination_proposals enable row level security;
alter table private.group_coordination_seats enable row level security;
alter table private.group_coordination_seen enable row level security;
revoke all on private.group_coordination_proposals,private.group_coordination_seats,private.group_coordination_seen from public,anon,authenticated,service_role;

create function private.group_coordination_slot_valid(p_seat private.group_coordination_seats) returns boolean
language sql stable security definer set search_path='' as $$
  select p_seat.is_current and p_seat.profile_id is not null and
    private.group_contact_representation_valid(p_seat.group_id,p_seat.profile_id,p_seat.delegate_id) and
    (p_seat.source_admission_id is null or exists(select 1 from private.group_contact_admissions a
      where a.id=p_seat.source_admission_id and a.profile_id=p_seat.profile_id and a.group_id=p_seat.group_id and
        a.delegate_id is not distinct from p_seat.delegate_id and a.left_at is null and
        private.group_contact_can_read(a.conversation_id,p_seat.profile_id)));
$$;
create function private.group_coordination_available(p_proposal private.group_coordination_proposals) returns boolean
language sql stable security definer set search_path='' as $$
  select p_proposal.status='pending' and p_proposal.expires_at>clock_timestamp() and
    private.group_contact_can_send(p_proposal.source_chat_id,p_proposal.initiator_id) and
    not exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and
      (not private.group_is_public(s.group_id) or (s.source_admission_id is not null and not private.group_coordination_slot_valid(s)))) and
    not exists(select 1 from private.group_coordination_seats a join private.group_coordination_seats b on a.proposal_id=b.proposal_id and a.profile_id<b.profile_id
      where a.proposal_id=p_proposal.id and private.group_coordination_slot_valid(a) and private.group_coordination_slot_valid(b) and
        private.has_active_user_block_between(a.profile_id,b.profile_id));
$$;
create function private.group_coordination_originals_confirmed(p_proposal private.group_coordination_proposals) returns boolean
language sql stable security definer set search_path='' as $$
  select (select count(*) from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and s.source_admission_id is not null)=2 and
    not exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and s.source_admission_id is not null and
      (not private.group_coordination_slot_valid(s) or s.confirmed_version is distinct from p_proposal.version));
$$;
create function private.group_coordination_can_claim(p_proposal private.group_coordination_proposals,p_group uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.group_coordination_available(p_proposal) and private.group_authority_role(p_group,p_actor) is not null and
    exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.group_id=p_group and s.is_current and
      s.source_admission_id is null and (s.profile_id is null or not private.group_coordination_slot_valid(s))) and
    not exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and s.profile_id=p_actor and private.group_coordination_slot_valid(s)) and
    not exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and private.group_coordination_slot_valid(s) and
      private.has_active_user_block_between(s.profile_id,p_actor));
$$;
create function private.group_coordination_visible(p_proposal private.group_coordination_proposals,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select p_proposal.initiator_id=p_actor or exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and
    (s.profile_id=p_actor or (s.is_current and s.source_admission_id is null and private.group_is_public(s.group_id) and private.group_authority_role(s.group_id,p_actor) is not null)));
$$;
create function private.group_coordination_candidate_ids(p_actor uuid) returns setof uuid
language sql stable security definer set search_path='' as $$
  -- Use actor/group indexes to select candidates before the authoritative
  -- projection predicate; ordinary membership is deliberately absent.
  select p.id from private.group_coordination_proposals p where p.initiator_id=p_actor
  union select s.proposal_id from private.group_coordination_seats s where s.profile_id=p_actor
  union select s.proposal_id from private.group_coordination_seats s join private.community_group_managers m on m.group_id=s.group_id
    where s.is_current and s.source_admission_id is null and m.profile_id=p_actor
  union select s.proposal_id from private.group_coordination_seats s join private.group_delegates d on d.group_id=s.group_id
    where s.is_current and s.source_admission_id is null and d.profile_id=p_actor and d.revoked_at is null;
$$;
create function private.group_coordination_lock(p_groups uuid[],p_people uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare before_ids uuid[]; after_ids uuid[];
begin
  select coalesce(array_agg(distinct m.profile_id order by m.profile_id),'{}') into before_ids from unnest(p_groups) g cross join lateral private.current_group_manager_profile_ids(g) m;
  perform private.group_contact_lock(p_groups,p_people||before_ids);
  select coalesce(array_agg(distinct m.profile_id order by m.profile_id),'{}') into after_ids from unnest(p_groups) g cross join lateral private.current_group_manager_profile_ids(g) m;
  if before_ids<>after_ids then raise sqlstate 'PT409' using message='This coordination changed. Refresh and retry.'; end if;
end; $$;
create function private.group_coordination_projection_slot_active(p_proposal private.group_coordination_proposals,p_seat private.group_coordination_seats) returns boolean
language sql stable security definer set search_path='' as $$
  select case when p_proposal.status='active' then private.group_contact_can_read(p_proposal.room_id,p_seat.profile_id)
    else private.group_coordination_slot_valid(p_seat) end;
$$;
create function private.group_coordination_projection(p_proposal private.group_coordination_proposals,p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare own_seat private.group_coordination_seats; detail boolean; named boolean; groups jsonb; audience jsonb; claim_groups jsonb; all_named boolean;
begin
  if not private.group_coordination_visible(p_proposal,p_actor) then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
  select * into own_seat from private.group_coordination_seats where proposal_id=p_proposal.id and is_current and profile_id=p_actor;
  detail:=coalesce(private.group_coordination_slot_valid(own_seat) and
      (p_proposal.status='pending' and p_proposal.expires_at>statement_timestamp()),false) or
    private.group_contact_can_read(p_proposal.room_id,p_actor) or
    exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and private.group_coordination_can_claim(p_proposal,s.group_id,p_actor));
  named:=coalesce(detail and (p_proposal.status='active' or own_seat.source_admission_id is not null or
    (private.group_coordination_slot_valid(own_seat) and private.group_coordination_originals_confirmed(p_proposal))),false);
  all_named:=p_proposal.status='active' or not exists(select 1 from private.group_coordination_seats s where s.proposal_id=p_proposal.id and s.is_current and not private.group_coordination_slot_valid(s));
  select coalesce(jsonb_agg(jsonb_build_object('group_id',s.group_id,'group_name',g.name,'is_claimed',private.group_coordination_projection_slot_active(p_proposal,s)) order by s.group_id),'[]') into groups
    from private.group_coordination_seats s join private.community_groups g on g.id=s.group_id where s.proposal_id=p_proposal.id and s.is_current and detail;
  -- The initiator explicitly authors the fresh invitation. The original peer's
  -- private affiliation/name is disclosed to claimants only after both original
  -- humans confirm this exact complete audience; no source-room existence leaks.
  select coalesce(jsonb_agg(jsonb_build_object('profile_id',s.profile_id,'group_id',s.group_id,'group_name',g.name,'display_name',p.display_name,
    'confirmed',coalesce(s.confirmed_version=p_proposal.version,false),'active',private.group_coordination_projection_slot_active(p_proposal,s)) order by s.group_id),'[]') into audience
    from private.group_coordination_seats s join private.community_groups g on g.id=s.group_id left join public.profiles p on p.id=s.profile_id
    where s.proposal_id=p_proposal.id and s.is_current and s.profile_id is not null and named;
  select coalesce(jsonb_agg(s.group_id order by s.group_id),'[]') into claim_groups from private.group_coordination_seats s
    where s.proposal_id=p_proposal.id and s.is_current and private.group_coordination_can_claim(p_proposal,s.group_id,p_actor);
  return jsonb_build_object('item_kind','group_coordination_proposal','proposal_id',p_proposal.id,
    'viewer_role',case when p_proposal.initiator_id=p_actor then 'requester' else 'delegate' end,
    'status',case when p_proposal.status='pending' and p_proposal.expires_at<=statement_timestamp() then 'expired' else p_proposal.status end,
    'version',p_proposal.version,'created_at',p_proposal.created_at,'activity_at',p_proposal.activity_at,'expires_at',p_proposal.expires_at,'resolved_at',p_proposal.ended_at,
    'title',case when detail then p_proposal.title end,'request_message',case when detail then p_proposal.note end,
    'requester_profile_id',case when detail then p_proposal.initiator_id end,
    'requester_display_name',case when detail then (select display_name from public.profiles where id=p_proposal.initiator_id) end,
    'groups',groups,'audience',audience,'audience_disclosed',named,'all_seats_named',detail and all_named,'claimable_group_ids',claim_groups,
    'own_group_id',case when detail and private.group_coordination_projection_slot_active(p_proposal,own_seat) then own_seat.group_id end,
    'own_confirmed',coalesce(detail and private.group_coordination_projection_slot_active(p_proposal,own_seat) and own_seat.confirmed_version=p_proposal.version,false),
    'can_confirm',coalesce(detail and all_named and private.group_coordination_available(p_proposal) and private.group_coordination_slot_valid(own_seat) and
      (own_seat.source_admission_id is not null or private.group_coordination_originals_confirmed(p_proposal)) and own_seat.confirmed_version is distinct from p_proposal.version,false),
    'can_change_audience',private.group_coordination_available(p_proposal) and p_proposal.initiator_id=p_actor,
    'can_cancel',p_proposal.initiator_id=p_actor and p_proposal.status='pending',
    'can_decline',detail and private.group_coordination_available(p_proposal) and p_proposal.initiator_id<>p_actor,
    'source_chat_id',case when detail and private.group_contact_can_read(p_proposal.source_chat_id,p_actor) then p_proposal.source_chat_id end,
    'chat_id',case when private.group_contact_can_read(p_proposal.room_id,p_actor) then p_proposal.room_id end);
end; $$;
create function private.group_coordination_command(p_expected uuid,p_action uuid,p_operation text,p_target uuid,p_intent jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected); receipt private.group_contact_receipts; hash text;
  r private.group_coordination_proposals; seat private.group_coordination_seats;
  groups uuid[]; old_groups uuid[]; added uuid[]; people uuid[]; original_groups uuid[]; original_people uuid[];
  source uuid; room uuid; snapshot_version bigint; expected_version bigint; chosen uuid;
  title text; note text; result jsonb; outcome text; now_at timestamptz:=clock_timestamp();
begin
  if p_action is null or p_target is null or p_operation not in ('propose','claim','confirm','targets','decline','cancel') then
    raise sqlstate '22023' using message='Invalid coordination action.'; end if;
  hash:=private.group_command_hash(jsonb_build_object('operation','coordination_'||p_operation,'target',p_target,'intent',p_intent));
  perform pg_advisory_xact_lock(hashtextextended('group.contact.action:'||actor::text||':'||p_action::text,0));
  select * into receipt from private.group_contact_receipts where actor_id=actor and action_id=p_action;
  if found then
    if hash<>receipt.intent_hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return receipt.result||jsonb_build_object('replayed',true);
  end if;
  if p_operation in ('propose','targets') then
    if jsonb_typeof(p_intent->'groups')<>'array' or jsonb_array_length(p_intent->'groups') not between 1 and 3 then
      raise sqlstate '22023' using message='Choose between one and three additional groups.'; end if;
    select array_agg(value::uuid order by value::uuid) into added from jsonb_array_elements_text(p_intent->'groups');
    if cardinality(added)<>(select count(distinct g) from unnest(added) g) or array_position(added,null) is not null then
      raise sqlstate '22023' using message='Additional groups must be distinct.'; end if;
  end if;
  if p_operation='propose' then
    perform pg_advisory_xact_lock(hashtextextended('group.contact.quota:'||actor::text,0));
    source:=p_target;
    select array_agg(a.group_id order by a.group_id),array_agg(a.profile_id order by a.profile_id) into original_groups,original_people
      from private.group_contact_admissions a where a.conversation_id=source;
    groups:=original_groups||added; people:=original_people||array[actor];
    if cardinality(original_groups)<>2 or cardinality(groups)<>(select count(distinct g) from unnest(groups) g) or
      not exists(select 1 from private.group_contact_conversations c where c.id=source and c.conversation_kind='bilateral') then
      raise sqlstate '42501' using message='This coordination context is unavailable.'; end if;
    perform private.group_coordination_lock(groups,people);
    perform private.require_group_actor(actor);
    if not private.group_contact_can_send(source,actor) or exists(select 1 from unnest(groups) g where not private.group_is_public(g)) or
      exists(select 1 from unnest(added) g cross join unnest(original_people) p where private.group_authority_role(g,p) is not null) or
      exists(select 1 from unnest(added) g cross join lateral private.current_group_manager_profile_ids(g) m cross join unnest(original_people) p
        where private.has_active_user_block_between(m.profile_id,p)) then
      raise sqlstate '42501' using message='This coordination context is unavailable.'; end if;
    if (select count(*) from private.group_coordination_proposals where initiator_id=actor and status='pending' and expires_at>now_at)>=
      (private.group_contact_limits()->>'coordination_pending')::integer or
      (select count(*) from private.group_coordination_proposals where initiator_id=actor and created_at>now_at-interval '24 hours')>=
      (private.group_contact_limits()->>'coordination_daily')::integer then
      raise sqlstate 'PT429' using message='The coordination limit has been reached. Try later.'; end if;
    title:=regexp_replace(coalesce(p_intent->>'title',''),'^[[:space:]]+|[[:space:]]+$','','g');
    note:=regexp_replace(coalesce(p_intent->>'note',''),'^[[:space:]]+|[[:space:]]+$','','g');
    if char_length(title) not between 1 and 120 or char_length(note) not between 1 and 1000 then
      raise sqlstate '22023' using message='Enter a fresh title and summary within the stated bounds.'; end if;
    insert into private.group_coordination_proposals(source_chat_id,initiator_id,title,note) values(source,actor,title,note) returning * into r;
    insert into private.group_coordination_seats(proposal_id,group_id,source_admission_id,profile_id,delegate_id,claimed_at)
      select r.id,a.group_id,a.id,a.profile_id,a.delegate_id,now_at from private.group_contact_admissions a where a.conversation_id=source;
    insert into private.group_coordination_seats(proposal_id,group_id) select r.id,g from unnest(added) g;
    outcome:='proposed';
  else
    select * into r from private.group_coordination_proposals where id=p_target;
    if r.id is null then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
    snapshot_version:=r.version; expected_version:=(p_intent->>'version')::bigint;
    select array_agg(group_id order by group_id),array_agg(profile_id order by profile_id) filter(where profile_id is not null) into old_groups,people
      from private.group_coordination_seats where proposal_id=r.id and is_current;
    groups:=old_groups||coalesce(added,'{}'); people:=coalesce(people,'{}')||array[actor,r.initiator_id];
    if p_operation='cancel' then
      perform 1 from private.community_groups g where g.id=any(groups) order by g.id for update;
    else perform private.group_coordination_lock(groups,people); end if;
    perform private.require_group_identity(actor);
    select * into r from private.group_coordination_proposals where id=p_target for update;
    if r.version<>snapshot_version or (select array_agg(group_id order by group_id) from private.group_coordination_seats where proposal_id=r.id and is_current)<>old_groups then
      raise sqlstate 'PT409' using message='The coordination audience changed. Review it again.'; end if;
    if r.status<>'pending' then raise sqlstate 'PT409' using message='This coordination proposal is already resolved.'; end if;
    if not private.group_coordination_visible(r,actor) then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
    if p_operation='cancel' then
      if actor<>r.initiator_id then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
      update private.group_coordination_proposals set status='canceled',ended_at=now_at,ended_by=actor,activity_at=now_at where id=r.id returning * into r;
      outcome:='canceled';
    else
      if expected_version is null or expected_version<>r.version then raise sqlstate 'PT409' using message='The coordination audience changed. Review it again.'; end if;
      if not private.group_coordination_available(r) then raise sqlstate '42501' using message='This coordination is unavailable. Refresh its context.'; end if;
      perform private.require_group_actor(actor);
      if p_operation='claim' then
        chosen:=(p_intent->>'group')::uuid;
        if chosen is null or not private.group_coordination_can_claim(r,chosen,actor) then raise sqlstate '42501' using message='This representation seat is unavailable.'; end if;
        select * into seat from private.group_coordination_seats where proposal_id=r.id and is_current and group_id=chosen for update;
        if seat.profile_id is not null then
          update private.group_coordination_seats set is_current=false where id=seat.id;
          insert into private.group_coordination_seats(proposal_id,group_id,profile_id,delegate_id,claimed_at)
            values(r.id,chosen,actor,private.group_contact_delegate(chosen,actor),now_at);
        else
          update private.group_coordination_seats set profile_id=actor,delegate_id=private.group_contact_delegate(chosen,actor),claimed_at=now_at where id=seat.id;
        end if;
        update private.group_coordination_proposals set version=version+1,activity_at=now_at where id=r.id returning * into r;
        outcome:='claimed';
      elsif p_operation='targets' then
        if actor<>r.initiator_id then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
        select array_agg(group_id order by group_id),array_agg(profile_id order by profile_id) into original_groups,original_people
          from private.group_coordination_seats where proposal_id=r.id and source_admission_id is not null and is_current;
        if exists(select 1 from unnest(added) g where g=any(original_groups) or not private.group_is_public(g)) or
          exists(select 1 from unnest(added) g cross join unnest(original_people) p where private.group_authority_role(g,p) is not null) or
          exists(select 1 from unnest(added) g cross join lateral private.current_group_manager_profile_ids(g) m cross join unnest(original_people) p
            where private.has_active_user_block_between(m.profile_id,p)) then
          raise sqlstate '42501' using message='These coordination targets are unavailable.'; end if;
        -- Explicit replacement starts a new selection round even for the same
        -- groups. The confirmation UI promises to retire their previous seats.
          update private.group_coordination_seats set is_current=false where proposal_id=r.id and is_current and source_admission_id is null;
          insert into private.group_coordination_seats(proposal_id,group_id) select r.id,g from unnest(added) g;
          update private.group_coordination_proposals set version=version+1,activity_at=now_at where id=r.id returning * into r;
        outcome:='changed';
      elsif p_operation='decline' then
        if actor=r.initiator_id or not exists(select 1 from private.group_coordination_seats s where s.proposal_id=r.id and s.is_current and
          ((s.profile_id=actor and private.group_coordination_slot_valid(s)) or private.group_coordination_can_claim(r,s.group_id,actor))) then
          raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
        update private.group_coordination_proposals set status='declined',ended_at=now_at,ended_by=actor,activity_at=now_at where id=r.id returning * into r;
        outcome:='declined';
      else
        select * into seat from private.group_coordination_seats where proposal_id=r.id and is_current and profile_id=actor for update;
        if not coalesce(private.group_coordination_slot_valid(seat),false) or exists(select 1 from private.group_coordination_seats s where s.proposal_id=r.id and s.is_current and not private.group_coordination_slot_valid(s)) or
          (seat.source_admission_id is null and not private.group_coordination_originals_confirmed(r)) then
          raise sqlstate 'PT409' using message='Review the complete named audience after the original representatives confirm.'; end if;
        if seat.confirmed_version=r.version then raise sqlstate 'PT409' using message='This audience was already confirmed.'; end if;
        update private.group_coordination_seats set confirmed_version=r.version where id=seat.id;
        outcome:='confirmed';
        if not exists(select 1 from private.group_coordination_seats s where s.proposal_id=r.id and s.is_current and s.confirmed_version is distinct from r.version) then
          -- All groups/accounts/grants/blocks remain locked through activation.
          if not private.group_coordination_available(r) or (select count(*) from private.group_coordination_seats where proposal_id=r.id and is_current) not between 3 and 5 then
            raise sqlstate '42501' using message='The coordination audience is unavailable.'; end if;
          insert into private.group_contact_conversations(title,summary,conversation_kind,coordination_proposal_id) values(r.title,r.note,'coordination',r.id) returning id into room;
          insert into private.group_contact_admissions(conversation_id,profile_id,group_id,delegate_id)
            select room,profile_id,group_id,delegate_id from private.group_coordination_seats where proposal_id=r.id and is_current;
          update private.group_coordination_proposals set status='active',room_id=room,ended_at=now_at,ended_by=actor,activity_at=now_at where id=r.id returning * into r;
          outcome:='active';
        else update private.group_coordination_proposals set activity_at=now_at where id=r.id returning * into r; end if;
      end if;
    end if;
  end if;
  result:=jsonb_build_object('coordination_id',r.id,'version',r.version,'outcome',outcome,'replayed',false);
  if outcome='active' then result:=result||jsonb_build_object('chat_id',r.room_id); end if;
  insert into private.group_contact_receipts values(actor,p_action,hash,result,clock_timestamp());
  perform private.audit_group_relationship('group.coordination_'||p_operation,actor,(select group_id from private.group_coordination_seats where proposal_id=r.id and source_admission_id is not null order by group_id limit 1),r.id);
  return result;
end; $$;
create function public.submit_group_coordination_proposal(p_expected_profile_id uuid,p_action_id uuid,p_source_chat_id uuid,p_group_ids uuid[],p_title text,p_note text) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'propose',p_source_chat_id,jsonb_build_object('groups',p_group_ids,'title',p_title,'note',p_note)); $$;
create function public.claim_group_coordination_seat(p_expected_profile_id uuid,p_action_id uuid,p_proposal_id uuid,p_expected_version bigint,p_group_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'claim',p_proposal_id,jsonb_build_object('version',p_expected_version,'group',p_group_id)); $$;
create function public.confirm_group_coordination_audience(p_expected_profile_id uuid,p_action_id uuid,p_proposal_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'confirm',p_proposal_id,jsonb_build_object('version',p_expected_version)); $$;
create function public.replace_group_coordination_targets(p_expected_profile_id uuid,p_action_id uuid,p_proposal_id uuid,p_expected_version bigint,p_group_ids uuid[]) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'targets',p_proposal_id,jsonb_build_object('version',p_expected_version,'groups',p_group_ids)); $$;
create function public.decline_group_coordination_proposal(p_expected_profile_id uuid,p_action_id uuid,p_proposal_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'decline',p_proposal_id,jsonb_build_object('version',p_expected_version)); $$;
create function public.cancel_group_coordination_proposal(p_expected_profile_id uuid,p_action_id uuid,p_proposal_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_coordination_command(p_expected_profile_id,p_action_id,'cancel',p_proposal_id,'{}'); $$;

create function private.group_coordination_signal(p_id uuid,p_access boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare r private.group_coordination_proposals; recipient uuid;
begin
  select * into r from private.group_coordination_proposals where id=p_id;
  if p_access then
    -- Losing claim/triage/confirmation visibility must also clear other
    -- managers' cached note. Former seen recipients get only this neutral hint.
    for recipient in select distinct profile_id from (
      select s.profile_id from private.group_coordination_seats s where s.proposal_id=p_id
      union select m.profile_id from private.group_coordination_seats s cross join lateral private.current_group_manager_profile_ids(s.group_id) m where s.proposal_id=p_id and s.source_admission_id is null
      union select seen.profile_id from private.group_coordination_seen seen where seen.proposal_id=p_id
    ) affected where profile_id is not null order by profile_id
    loop perform private.group_contact_access_signal(recipient); end loop;
    return;
  end if;
  for recipient in select distinct s.profile_id from private.group_coordination_seats s where s.proposal_id=p_id and s.is_current and s.profile_id is not null
    and private.group_coordination_slot_valid(s) order by s.profile_id
  loop
    if p_access then perform private.group_contact_access_signal(recipient); else perform private.group_contact_signal(recipient); end if;
  end loop;
  if not p_access then
    for recipient in select distinct m.profile_id from private.group_coordination_seats s cross join lateral private.current_group_manager_profile_ids(s.group_id) m
      where s.proposal_id=p_id and s.is_current and private.group_coordination_can_claim(r,s.group_id,m.profile_id) order by m.profile_id
    loop perform private.group_contact_signal(recipient); end loop;
  end if;
end; $$;
create function private.group_coordination_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare id uuid;
begin
  if tg_table_name='group_coordination_proposals' then
    id:=new.id;
    if tg_op='UPDATE' and (old.version<>new.version or old.status<>new.status) then perform private.group_coordination_signal(id,true); end if;
  else
    id:=new.proposal_id;
    if tg_op='UPDATE' then perform private.group_coordination_signal(id,true); end if;
    if tg_op='UPDATE' and old.is_current and not new.is_current and old.profile_id is not null then
      perform private.group_contact_access_signal(old.profile_id);
    end if;
  end if;
  perform private.group_coordination_signal(id);
  return new;
end; $$;
create trigger group_coordination_proposal_signal after insert or update on private.group_coordination_proposals for each row execute function private.group_coordination_change_signal();
create trigger group_coordination_seat_signal after insert or update on private.group_coordination_seats for each row execute function private.group_coordination_change_signal();
create function private.group_coordination_group_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare g uuid:=coalesce(to_jsonb(new)->>'group_id',to_jsonb(old)->>'group_id',to_jsonb(new)->>'id',to_jsonb(old)->>'id')::uuid; recipient uuid;
begin
  for recipient in select distinct b.profile_id from private.group_coordination_seats a join private.group_coordination_seats b on b.proposal_id=a.proposal_id
    where a.group_id=g and a.is_current and b.is_current and b.profile_id is not null order by b.profile_id
  loop perform private.group_contact_access_signal(recipient); end loop;
  return coalesce(new,old);
end; $$;
create trigger group_coordination_group_lifecycle after update on private.community_groups for each row execute function private.group_coordination_group_access();
create trigger group_coordination_group_anchor after update on private.community_group_managers for each row execute function private.group_coordination_group_access();
create trigger group_coordination_group_delegate after insert or update on private.group_delegates for each row execute function private.group_coordination_group_access();
create function private.group_coordination_source_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare source uuid; proposal uuid;
begin
  source:=case when tg_table_name='group_contact_admissions' then (to_jsonb(new)->>'conversation_id')::uuid else (to_jsonb(new)->>'id')::uuid end;
  for proposal in select id from private.group_coordination_proposals where source_chat_id=source and status='pending' order by id
  loop perform private.group_coordination_signal(proposal,true); end loop;
  return new;
end; $$;
-- Source human messages are private and emit no coordination hint. Only access
-- transitions invalidate still-pending proposals; activated rooms are separate.
create trigger group_coordination_source_leave after update on private.group_contact_admissions for each row when(old.left_at is distinct from new.left_at) execute function private.group_coordination_source_access();
create trigger group_coordination_source_close after update on private.group_contact_conversations for each row when(old.closed_at is distinct from new.closed_at) execute function private.group_coordination_source_access();

do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'group_coordination_%') or (n.nspname='public' and p.proname like '%group_coordination%')
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
create function public.get_own_group_coordination_proposal(p_expected_profile_id uuid,p_proposal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); r private.group_coordination_proposals; result jsonb;
begin
  select * into r from private.group_coordination_proposals where id=p_proposal_id;
  if r.id is null then raise sqlstate '42501' using message='The coordination proposal is unavailable.'; end if;
  result:=private.group_coordination_projection(r,actor);
  if result->>'request_message' is not null then insert into private.group_coordination_seen(proposal_id,profile_id) values(r.id,actor) on conflict do nothing; end if;
  return result;
end; $$;
create function public.get_own_group_coordination_for_conversation(p_expected_profile_id uuid,p_chat_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); r private.group_coordination_proposals;
begin
  if not private.group_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The coordination context is unavailable.'; end if;
  select p.* into r from private.group_coordination_proposals p where p.room_id=p_chat_id;
  if r.id is null then return null; end if;
  return private.group_coordination_projection(r,actor);
end; $$;
revoke all on function public.get_own_group_coordination_proposal(uuid,uuid),public.get_own_group_coordination_for_conversation(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_group_coordination_proposal(uuid,uuid),public.get_own_group_coordination_for_conversation(uuid,uuid) to authenticated;
