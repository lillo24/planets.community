-- Keep the original Block function identity. The member wrapper must not lock
-- Groups before the captured Project/Resource closure, or reserve a partial Group
-- set before coordination adds a lower ID. Extend the predecessor's one union.
do $migration$
declare
  canonical_oid oid:='private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure;
  previous_oid oid:='private.member_contact_previous_block_convergence(uuid,uuid)'::regprocedure;
  canonical_acl aclitem[]; previous_acl aclitem[];
  canonical_source text; canonical_definition text; previous_definition text;
  marker text:='  ) affected;';
  legacy_call text:='perform private.close_pending_project_resource_requests_for_user_block(p_blocker_profile_id,p_blocked_profile_id);';
  group_union text:='select array_agg(distinct g order by g) into groups from (';
  group_lock text:='perform 1 from private.community_groups g where g.id=any(groups) order by g.id for update;';
  group_call text:='perform private.group_contact_legacy_block_convergence(p_blocker_profile_id,p_blocked_profile_id);';
  coordination_union text:='union all select s.group_id from private.group_coordination_proposals';
  member_union text:=$member$
    union all select p.group_id from private.member_contact_pairs p
      where p.low_profile_id=least(p_blocker_profile_id,p_blocked_profile_id)
        and p.high_profile_id=greatest(p_blocker_profile_id,p_blocked_profile_id)
$member$;
  old_prefix text:=$prefix$
declare groups uuid[]; pair private.member_contact_pairs;
begin
  select array_agg(distinct g order by g) into groups from (
    select r.group_id g from private.group_join_requests r where r.status='pending' and
      ((r.requester_id=p_blocker_profile_id and private.group_authority_role(r.group_id,p_blocked_profile_id) is not null)
        or (r.requester_id=p_blocked_profile_id and private.group_authority_role(r.group_id,p_blocker_profile_id) is not null))
    union all select g from private.group_contact_requests r cross join lateral unnest(array[r.source_group_id,r.target_group_id]) g
      where r.status='pending' and ((r.submitter_id=p_blocker_profile_id and private.group_authority_role(r.target_group_id,p_blocked_profile_id) is not null)
        or (r.submitter_id=p_blocked_profile_id and private.group_authority_role(r.target_group_id,p_blocker_profile_id) is not null))
    union all select p.group_id from private.member_contact_pairs p where p.low_profile_id=least(p_blocker_profile_id,p_blocked_profile_id)
      and p.high_profile_id=greatest(p_blocker_profile_id,p_blocked_profile_id)
  ) affected;
  perform 1 from private.community_groups where id=any(groups) order by id for update;
$prefix$;
  preserved_tail text:=$tail$
  perform private.member_contact_previous_block_convergence(p_blocker_profile_id,p_blocked_profile_id);
  for pair in select * from private.member_contact_pairs p where p.low_profile_id=least(p_blocker_profile_id,p_blocked_profile_id)
    and p.high_profile_id=greatest(p_blocker_profile_id,p_blocked_profile_id) order by p.id for update
  loop
    update private.member_contact_requests set status=case when sender_profile_id=p_blocker_profile_id then 'withdrawn' else 'declined' end,
      resolved_at=clock_timestamp(),resolved_by=p_blocker_profile_id,activity_at=clock_timestamp() where pair_id=pair.id and status='pending';
    delete from private.member_contact_read_snapshots where pair_id=pair.id;
    perform private.member_contact_signal(pair.low_profile_id,true);
    perform private.member_contact_signal(pair.high_profile_id,true);
  end loop;
end;
$tail$;
begin
  select replace(prosrc,E'\r\n',E'\n'),proacl into canonical_source,canonical_acl from pg_proc where oid=canonical_oid;
  select proacl into previous_acl from pg_proc where oid=previous_oid;
  -- Normalize host line endings only. A changed canonical body needs explicit
  -- reconciliation rather than losing peer behavior through replacement.
  old_prefix:=replace(old_prefix,E'\r\n',E'\n');
  preserved_tail:=replace(preserved_tail,E'\r\n',E'\n');
  if btrim(canonical_source,E' \t\r\n') is distinct from
    btrim(rtrim(old_prefix,E'\n')||preserved_tail,E' \t\r\n') then
    raise exception 'Review the changed canonical member Block wrapper before composing its lock order.';
  end if;
  previous_definition:=replace(pg_get_functiondef(previous_oid),E'\r\n',E'\n');
  if (length(previous_definition)-length(replace(previous_definition,marker,'')))<>length(marker)
    or (length(previous_definition)-length(replace(previous_definition,legacy_call,'')))<>length(legacy_call)
    or (length(previous_definition)-length(replace(previous_definition,group_union,'')))<>length(group_union)
    or (length(previous_definition)-length(replace(previous_definition,group_lock,'')))<>length(group_lock)
    or (length(previous_definition)-length(replace(previous_definition,group_call,'')))<>length(group_call)
    or (length(previous_definition)-length(replace(previous_definition,coordination_union,'')))<>length(coordination_union)
    or strpos(previous_definition,'private.member_contact_pairs')>0
    or not (strpos(previous_definition,legacy_call)<strpos(previous_definition,group_union)
      and strpos(previous_definition,group_union)<strpos(previous_definition,coordination_union)
      and strpos(previous_definition,coordination_union)<strpos(previous_definition,marker)
      and strpos(previous_definition,marker)<strpos(previous_definition,group_lock)
      and strpos(previous_definition,group_lock)<strpos(previous_definition,group_call)) then
    raise exception 'Review the effective legacy/coordination Block union and lock order before adding member Groups.';
  end if;
  canonical_definition:=replace(pg_get_functiondef(canonical_oid),E'\r\n',E'\n');
  execute replace(previous_definition,marker,replace(member_union,E'\r\n',E'\n')||marker);
  execute replace(canonical_definition,canonical_source,
    E'\ndeclare pair private.member_contact_pairs;\nbegin'||preserved_tail);
  if 'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure::oid<>canonical_oid
    or 'private.member_contact_previous_block_convergence(uuid,uuid)'::regprocedure::oid<>previous_oid
    or (select proacl from pg_proc where oid=canonical_oid) is distinct from canonical_acl
    or (select proacl from pg_proc where oid=previous_oid) is distinct from previous_acl then
    raise exception 'Block composition must preserve both function identities and privileges.';
  end if;
end;
$migration$;
