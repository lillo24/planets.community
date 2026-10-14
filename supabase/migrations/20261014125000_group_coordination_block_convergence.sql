-- The canonical Block hook already owns the sorted pair. Add the full D03
-- group set BEFORE the existing group lock acquisition; never append lower IDs.
do $$ declare definition text:=pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure);
  marker text:=') affected;'; insertion text:=$insert$
    union all select s.group_id from private.group_coordination_proposals p join private.group_coordination_seats s on s.proposal_id=p.id and s.is_current
      where p.status='pending' and exists(select 1 from private.group_coordination_seats a join private.group_coordination_seats b on b.proposal_id=a.proposal_id
        where a.proposal_id=p.id and a.is_current and b.is_current and
          ((a.profile_id=p_blocker_profile_id and (b.profile_id=p_blocked_profile_id or (b.source_admission_id is null and private.group_authority_role(b.group_id,p_blocked_profile_id) is not null))) or
           (a.profile_id=p_blocked_profile_id and (b.profile_id=p_blocker_profile_id or (b.source_admission_id is null and private.group_authority_role(b.group_id,p_blocker_profile_id) is not null)))))
  $insert$;
  convergence text:=$converge$
  for item in update private.group_coordination_proposals p set status=case when p.initiator_id=p_blocker_profile_id then 'canceled' else 'declined' end,
    ended_at=clock_timestamp(),ended_by=p_blocker_profile_id,activity_at=clock_timestamp() where p.status='pending' and
    exists(select 1 from private.group_coordination_seats a join private.group_coordination_seats b on b.proposal_id=a.proposal_id
      where a.proposal_id=p.id and a.is_current and b.is_current and
        ((a.profile_id=p_blocker_profile_id and (b.profile_id=p_blocked_profile_id or (b.source_admission_id is null and private.group_authority_role(b.group_id,p_blocked_profile_id) is not null))) or
         (a.profile_id=p_blocked_profile_id and (b.profile_id=p_blocker_profile_id or (b.source_admission_id is null and private.group_authority_role(b.group_id,p_blocker_profile_id) is not null))))) returning p.id
  loop perform private.group_coordination_signal(item.id,true); end loop;
  $converge$;
begin
  if strpos(definition,marker)=0 or strpos(definition,'-- Generic own-account invalidation')=0 then raise exception 'Review the effective complete group Block lock order.'; end if;
  definition:=replace(definition,marker,insertion||marker);
  definition:=replace(definition,'-- Generic own-account invalidation',convergence||'-- Generic own-account invalidation');
  execute definition;
end; $$;

-- Closing affects every participant, so require current live admission. A
-- former participant retains only the safe own-seat leave and receipt recovery.
do $$ declare definition text:=pg_get_functiondef('private.group_contact_conversation_command(uuid,uuid,uuid,text,text)'::regprocedure);
  marker text:='elsif p_operation=''close'' then';
begin
  if strpos(definition,marker)=0 then raise exception 'Review the effective conversation exit command.'; end if;
  execute replace(definition,marker,marker||' if not private.group_contact_can_read(p_chat,actor) then raise sqlstate ''42501'' using message=''The conversation is unavailable.''; end if;');
end; $$;
