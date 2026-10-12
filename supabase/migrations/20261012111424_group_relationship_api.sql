-- Narrow authenticated group relationship adapters. No direct relationship grants.

create function public.create_group_join_request(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_note text default null)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'request',jsonb_build_object('note',p_note));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.withdraw_group_join_request(p_expected_profile_id uuid,p_request_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_join_requests lookup where lookup.id=p_request_id),'withdraw_request',jsonb_build_object('id',p_request_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.accept_group_join_request(p_expected_profile_id uuid,p_request_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_join_requests lookup where lookup.id=p_request_id),'accept_request',jsonb_build_object('id',p_request_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.reject_group_join_request(p_expected_profile_id uuid,p_request_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_join_requests lookup where lookup.id=p_request_id),'reject_request',jsonb_build_object('id',p_request_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.leave_group(p_expected_profile_id uuid,p_membership_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_memberships lookup where lookup.id=p_membership_id),'leave',jsonb_build_object('id',p_membership_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.remove_group_member(p_expected_profile_id uuid,p_membership_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_memberships lookup where lookup.id=p_membership_id),'remove',jsonb_build_object('id',p_membership_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.create_group_authority_invitation(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_role text)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz,invite_token text)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'invite_authority',jsonb_build_object('role',p_role));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz,invite_token text);
end;
$$;

create function public.create_group_role_offer(p_expected_profile_id uuid,p_group_id uuid,p_membership_id uuid,p_client_request_id uuid,p_role text)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'offer',jsonb_build_object('id',p_membership_id,'role',p_role));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.accept_group_role_offer(p_expected_profile_id uuid,p_offer_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_authority_invitations lookup where lookup.id=p_offer_id and lookup.token_digest is null),'accept_authority',jsonb_build_object('id',p_offer_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.decline_group_role_offer(p_expected_profile_id uuid,p_offer_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_authority_invitations lookup where lookup.id=p_offer_id and lookup.token_digest is null),'decline_offer',jsonb_build_object('id',p_offer_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.revoke_group_authority_invitation(p_expected_profile_id uuid,p_invitation_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_authority_invitations lookup where lookup.id=p_invitation_id),'revoke_authority_invitation',jsonb_build_object('id',p_invitation_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.change_group_delegate_role(p_expected_profile_id uuid,p_delegate_id uuid,p_client_request_id uuid,p_role text)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_delegates lookup where lookup.id=p_delegate_id),'change_role',jsonb_build_object('id',p_delegate_id,'role',p_role));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.revoke_group_delegate(p_expected_profile_id uuid,p_delegate_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_delegates lookup where lookup.id=p_delegate_id),'revoke_delegate',jsonb_build_object('id',p_delegate_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.step_down_group_authority(p_expected_profile_id uuid,p_delegate_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,(select lookup.group_id from private.group_delegates lookup where lookup.id=p_delegate_id),'step_down',jsonb_build_object('id',p_delegate_id));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.accept_group_authority_invitation(p_expected_profile_id uuid,p_token text,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare digest text; target_group uuid; result jsonb;
begin
  perform private.require_group_identity(p_expected_profile_id);
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then raise exception using errcode='42501',message='This interaction is unavailable.'; end if;
  digest:=encode(extensions.digest(p_token,'sha256'),'hex');
  select i.group_id into target_group from private.group_authority_invitations i where i.token_digest=digest;
  if target_group is null then raise exception using errcode='42501',message='This interaction is unavailable.'; end if;
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,target_group,'accept_authority',jsonb_build_object('digest',digest));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.accept_group_participant_invitation(p_expected_profile_id uuid,p_token text,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare digest text; target_group uuid; result jsonb;
begin
  perform private.require_group_identity(p_expected_profile_id);
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then raise exception using errcode='PT409',message='This interaction is unavailable.'; end if;
  digest:=encode(extensions.digest(p_token,'sha256'),'hex');
  select i.group_id into target_group from private.group_participant_invitations i where i.token_digest=digest;
  if target_group is null then raise exception using errcode='PT409',message='This interaction is unavailable.'; end if;
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,target_group,'accept_participant',jsonb_build_object('digest',digest));
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz);
end;
$$;

create function public.recover_group_relationship_command(p_expected_profile_id uuid,p_client_request_id uuid)
returns table(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  select private.group_relationship_result(c.result,true) into result from private.group_relationship_receipts c
    where c.actor_id=actor and c.client_request_id=p_client_request_id;
  return query select r.* from jsonb_to_record(result) as r(group_id uuid,relationship_id uuid,relationship_kind text,outcome text,current_status text,replayed boolean,expires_at timestamptz) where result is not null;
end;
$$;

create function private.read_group_participant_link(p_expected uuid,p_group uuid,p_invitation uuid)
returns table(invitation_id uuid,invite_token text,created_at timestamptz,revoked_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected);
begin
  perform 1 from private.community_groups where id=p_group for update;
  perform private.require_group_identity(p_expected);
  perform private.require_group_manager(p_group,actor);
  if exists(select 1 from private.group_participant_invitations i left join private.group_participant_invitation_secrets s on s.invitation_id=i.id
    where i.id=p_invitation and i.group_id=p_group and i.revoked_at is null
      and (s.token is null or encode(extensions.digest(s.token,'sha256'),'hex')<>i.token_digest)) then
    raise exception using errcode='55000',message='The current sharing secret is unavailable.';
  end if;
  return query select i.id,case when i.revoked_at is null then s.token else null end,i.created_at,i.revoked_at
    from private.group_participant_invitations i left join private.group_participant_invitation_secrets s on s.invitation_id=i.id
    where i.group_id=p_group and i.id=p_invitation;
end;
$$;

create function public.create_group_participant_invitation(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid)
returns table(invitation_id uuid,invite_token text,created_at timestamptz,revoked_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'create_participant_link','{}'::jsonb);
  return query select * from private.read_group_participant_link(p_expected_profile_id,p_group_id,(result->>'relationship_id')::uuid);
end;
$$;

create function public.regenerate_group_participant_invitation(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid)
returns table(invitation_id uuid,invite_token text,created_at timestamptz,revoked_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'regenerate_participant_link','{}'::jsonb);
  return query select * from private.read_group_participant_link(p_expected_profile_id,p_group_id,(result->>'relationship_id')::uuid);
end;
$$;

create function public.revoke_group_participant_invitation(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_invitation_id uuid)
returns table(invitation_id uuid,invite_token text,created_at timestamptz,revoked_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=private.group_relationship_command(p_expected_profile_id,p_client_request_id,p_group_id,'revoke_participant_link',jsonb_build_object('id',p_invitation_id));
  return query select * from private.read_group_participant_link(p_expected_profile_id,p_group_id,(result->>'relationship_id')::uuid);
end;
$$;

create function public.get_current_group_participant_invitation(p_expected_profile_id uuid,p_group_id uuid)
returns table(invitation_id uuid,invite_token text,created_at timestamptz,revoked_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); invitation uuid;
begin
  perform 1 from private.community_groups where id=p_group_id for update;
  perform private.require_group_identity(p_expected_profile_id);
  perform private.require_group_manager(p_group_id,actor);
  select i.id into invitation from private.group_participant_invitations i where i.group_id=p_group_id and i.revoked_at is null;
  return query select * from private.read_group_participant_link(p_expected_profile_id,p_group_id,invitation);
end;
$$;
create function public.get_group_participant_invitation_preview(p_token text)
returns table(available boolean,group_id uuid,group_name text,group_kind text)
language sql stable security definer set search_path='' as $$
  select g.id is not null,g.id,g.name,g.group_kind from (select 1) seed left join
    (select c.id,c.name,c.group_kind from private.group_participant_invitations i join private.community_groups c on c.id=i.group_id
      where p_token ~ '^[A-Za-z0-9_-]{43}$' and i.token_digest=encode(extensions.digest(p_token,'sha256'),'hex')
        and i.revoked_at is null and private.group_is_public(c.id)) g on true;
$$;
create function public.get_group_authority_invitation_preview(p_token text)
returns table(available boolean,group_id uuid,group_name text,group_kind text,offered_role text,expires_at timestamptz)
language sql stable security definer set search_path='' as $$
  select g.id is not null,g.id,g.name,g.group_kind,g.offered_role,g.expires_at from (select 1) seed left join
    (select c.id,c.name,c.group_kind,i.offered_role,i.expires_at from private.group_authority_invitations i join private.community_groups c on c.id=i.group_id
      where p_token ~ '^[A-Za-z0-9_-]{43}$' and i.token_digest=encode(extensions.digest(p_token,'sha256'),'hex')
        and i.status='pending' and i.expires_at>statement_timestamp() and private.group_is_public(c.id)
        and private.group_authority_role(c.id,i.issuer_id) in ('creator','co_creator')) g on true;
$$;
-- Bounded context reads use relationship IDs and immutable timestamp/UUID cursors.
create function private.validate_group_page(p_limit integer,p_time timestamptz,p_id uuid) returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
  if p_limit is null or p_limit not between 1 and 50 or (p_time is null)<>(p_id is null) or (p_time is not null and not isfinite(p_time)) then
    raise exception using errcode='22023',message='Invalid page size or paired cursor.';
  end if;
end;
$$;
create function public.get_own_group_role(p_expected_profile_id uuid,p_group_id uuid)
returns table(authority_role text,delegate_id uuid,current_membership_id uuid,membership_status text)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  return query select private.group_authority_role(p_group_id,actor),
    (select d.id from private.group_delegates d where d.group_id=p_group_id and d.profile_id=actor and d.revoked_at is null),
    (select m.id from private.group_memberships m where m.group_id=p_group_id and m.profile_id=actor and m.ended_at is null),
    case when exists(select 1 from private.group_memberships m where m.group_id=p_group_id and m.profile_id=actor and m.ended_at is null) then 'current' else null end;
end;
$$;
create function private.require_group_people_viewer(p_expected uuid,p_group uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected);
begin
  if not private.group_has_accountable_identity(p_group) or (private.group_authority_role(p_group,actor) is null
    and not exists(select 1 from private.group_memberships where group_id=p_group and profile_id=actor and ended_at is null)) then
    raise exception using errcode='42501',message='The group is unavailable.';
  end if;
  return actor;
end;
$$;
create function public.list_current_group_people(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 50,p_after_role_rank integer default null,p_after_profile_id uuid default null)
returns table(profile_id uuid,display_name text,is_creator boolean,authority_role text,delegate_id uuid,current_membership_id uuid,joined_at timestamptz,role_rank integer)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_group_people_viewer(p_expected_profile_id,p_group_id);
  if p_limit is null or p_limit not between 1 and 50 or (p_after_role_rank is null)<>(p_after_profile_id is null)
    or (p_after_role_rank is not null and p_after_role_rank not between 0 and 3) then
    raise exception using errcode='22023',message='Invalid People page size or paired cursor.';
  end if;
  return query with identities as (
    select x.profile_id from private.current_group_manager_profile_ids(p_group_id) x union
    select m.profile_id from private.group_memberships m where m.group_id=p_group_id and m.ended_at is null
  ), people as (
    select p.id,p.display_name,private.group_authority_role(p_group_id,p.id) as authority,d.id as delegation,m.id as membership,m.joined_at
    from identities i join public.profiles p on p.id=i.profile_id join auth.users a on a.id=p.id
    left join private.group_delegates d on d.group_id=p_group_id and d.profile_id=p.id and d.revoked_at is null
    left join private.group_memberships m on m.group_id=p_group_id and m.profile_id=p.id and m.ended_at is null
  ), ranked as (
    select *,case authority when 'creator' then 0 when 'co_creator' then 1 when 'co_organizer' then 2 else 3 end as rank from people
  )
  select r.id,r.display_name,coalesce(r.authority='creator',false),r.authority,r.delegation,r.membership,r.joined_at,r.rank
    from ranked r where p_after_profile_id is null or (r.rank,r.id)>(p_after_role_rank,p_after_profile_id)
    order by r.rank,r.id limit p_limit;
end;
$$;

create function public.list_own_group_join_requests(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(request_id uuid,group_id uuid,requester_profile_id uuid,requester_display_name text,note text,status text,created_at timestamptz,resolved_at timestamptz,resolved_by_profile_id uuid,resolution_reason text,superseded_by_membership_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  
  return query select r.id,r.group_id,r.requester_id,p.display_name,r.note,r.status,r.created_at,r.resolved_at,r.resolved_by,case when r.resolution_reason='blocking' then case when r.status='rejected' then 'review' else 'withdrawal' end else r.resolution_reason end,r.superseded_by_membership_id
    from private.group_join_requests r left join public.profiles p on p.id=r.requester_id
    where r.requester_id=actor and (p_before_id is null or (r.created_at,r.id)<(p_before_created_at,p_before_id))
    order by r.created_at desc,r.id desc limit p_limit;
end;
$$;

create function public.list_own_group_memberships(p_expected_profile_id uuid,p_limit integer default 25,p_before_joined_at timestamptz default null,p_before_id uuid default null)
returns table(membership_id uuid,group_id uuid,profile_id uuid,display_name text,originating_request_id uuid,joined_at timestamptz,admitted_by_profile_id uuid,ended_at timestamptz,ended_by_profile_id uuid,membership_status text)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_joined_at,p_before_id);
  
  return query select m.id,m.group_id,m.profile_id,p.display_name,m.originating_request_id,m.joined_at,m.admitted_by,m.ended_at,m.ended_by,coalesce(m.end_reason,'current')
    from private.group_memberships m left join public.profiles p on p.id=m.profile_id
    where m.profile_id=actor and (p_before_id is null or (m.joined_at,m.id)<(p_before_joined_at,p_before_id))
    order by m.joined_at desc,m.id desc limit p_limit;
end;
$$;

create function public.list_group_join_requests(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(request_id uuid,group_id uuid,requester_profile_id uuid,requester_display_name text,note text,status text,created_at timestamptz,resolved_at timestamptz,resolved_by_profile_id uuid,resolution_reason text,superseded_by_membership_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor);
  return query select r.id,r.group_id,r.requester_id,p.display_name,r.note,r.status,r.created_at,r.resolved_at,r.resolved_by,case when r.resolution_reason='blocking' then case when r.status='rejected' then 'review' else 'withdrawal' end else r.resolution_reason end,r.superseded_by_membership_id
    from private.group_join_requests r left join public.profiles p on p.id=r.requester_id
    where r.group_id=p_group_id and (p_before_id is null or (r.created_at,r.id)<(p_before_created_at,p_before_id))
    order by r.created_at desc,r.id desc limit p_limit;
end;
$$;

create function public.list_group_membership_history(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_joined_at timestamptz default null,p_before_id uuid default null)
returns table(membership_id uuid,group_id uuid,profile_id uuid,display_name text,originating_request_id uuid,joined_at timestamptz,admitted_by_profile_id uuid,ended_at timestamptz,ended_by_profile_id uuid,membership_status text)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_joined_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor);
  return query select m.id,m.group_id,m.profile_id,p.display_name,m.originating_request_id,m.joined_at,m.admitted_by,m.ended_at,m.ended_by,coalesce(m.end_reason,'current')
    from private.group_memberships m left join public.profiles p on p.id=m.profile_id
    where m.group_id=p_group_id and (p_before_id is null or (m.joined_at,m.id)<(p_before_joined_at,p_before_id))
    order by m.joined_at desc,m.id desc limit p_limit;
end;
$$;

create function public.list_group_delegates(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_granted_at timestamptz default null,p_before_id uuid default null)
returns table(delegate_id uuid,profile_id uuid,display_name text,initial_role text,delegate_role text,granted_by_profile_id uuid,granted_at timestamptz,revoked_at timestamptz,revoked_by_profile_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_granted_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor,true);
  return query select d.id,d.profile_id,p.display_name,d.initial_role,d.delegate_role,d.granted_by,d.granted_at,d.revoked_at,d.revoked_by
    from private.group_delegates d left join public.profiles p on p.id=d.profile_id
    where d.group_id=p_group_id and (p_before_id is null or (d.granted_at,d.id)<(p_before_granted_at,p_before_id))
    order by d.granted_at desc,d.id desc limit p_limit;
end;
$$;
create function public.list_group_delegate_role_history(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(change_id uuid,delegate_id uuid,from_role text,to_role text,actor_profile_id uuid,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor,true);
  return query select c.id,c.delegate_id,c.from_role,c.to_role,c.actor_id,c.created_at
    from private.group_role_changes c join private.group_delegates d on d.id=c.delegate_id
    where d.group_id=p_group_id and (p_before_id is null or (c.created_at,c.id)<(p_before_created_at,p_before_id))
    order by c.created_at desc,c.id desc limit p_limit;
end;
$$;

create function public.list_group_authority_invitations(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(invitation_id uuid,group_id uuid,issuer_profile_id uuid,offered_role text,target_profile_id uuid,target_membership_id uuid,status text,created_at timestamptz,expires_at timestamptz,resolved_at timestamptz,resolved_by_profile_id uuid,accepted_delegate_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor,true);
  return query select i.id,i.group_id,i.issuer_id,i.offered_role,i.target_profile_id,i.target_membership_id,
    case when i.status='pending' and i.expires_at<=statement_timestamp() then 'expired' else i.status end,
    i.created_at,i.expires_at,i.resolved_at,i.resolved_by,i.accepted_delegate_id
    from private.group_authority_invitations i where i.group_id=p_group_id
      and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
    order by i.created_at desc,i.id desc limit p_limit;
end;
$$;

create function public.list_own_group_role_offers(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(invitation_id uuid,group_id uuid,issuer_profile_id uuid,offered_role text,target_profile_id uuid,target_membership_id uuid,status text,created_at timestamptz,expires_at timestamptz,resolved_at timestamptz,resolved_by_profile_id uuid,accepted_delegate_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  
  return query select i.id,i.group_id,i.issuer_id,i.offered_role,i.target_profile_id,i.target_membership_id,
    case when i.status='pending' and i.expires_at<=statement_timestamp() then 'expired' else i.status end,
    i.created_at,i.expires_at,i.resolved_at,i.resolved_by,i.accepted_delegate_id
    from private.group_authority_invitations i where i.target_profile_id=actor
      and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
    order by i.created_at desc,i.id desc limit p_limit;
end;
$$;

create function public.list_group_participant_invitation_history(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(invitation_id uuid,issuer_profile_id uuid,created_at timestamptz,revoked_at timestamptz,revoked_by_profile_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  perform private.require_group_manager(p_group_id,actor);
  return query select i.id,i.issuer_id,i.created_at,i.revoked_at,i.revoked_by from private.group_participant_invitations i
    where i.group_id=p_group_id and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
    order by i.created_at desc,i.id desc limit p_limit;
end;
$$;
create function public.list_managed_groups(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(group_id uuid,name text,group_kind text,publication_state text,directory_suppressed boolean,authority_role text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_created_at,p_before_id);
  return query select g.id,g.name,g.group_kind,g.publication_state,g.directory_suppressed,private.group_authority_role(g.id,actor),g.created_at
    from private.community_groups g where private.group_authority_role(g.id,actor) is not null
      and (g.publication_state<>'draft' or private.group_authority_role(g.id,actor)='creator')
      and (p_before_id is null or (g.created_at,g.id)<(p_before_created_at,p_before_id))
    order by g.created_at desc,g.id desc limit p_limit;
end;
$$;
create function public.get_group_structural_context(p_expected_profile_id uuid,p_group_id uuid)
returns table(group_id uuid,name text,description text,group_kind text,locality text,volunteering_focus boolean,publication_state text,directory_suppressed boolean,version bigint,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.require_group_manager(p_group_id,actor,true);
  return query select g.id,g.name,g.description,g.group_kind,g.locality,g.volunteering_focus,g.publication_state,g.directory_suppressed,g.version,g.created_at,g.updated_at
    from private.community_groups g where g.id=p_group_id;
end;
$$;
-- Creator APIs and their exact ownership/recovery contract remain unchanged.
create function private.group_structural_command(p_expected uuid,p_group uuid,p_key uuid,p_version bigint,p_content jsonb,p_state text) returns bigint
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected); authority text; g private.community_groups%rowtype;
  normalized jsonb; intent text; receipt private.community_group_command_receipts%rowtype;
begin
  if p_content is not null then normalized:=private.normalize_group_content(p_content); end if;
  if (p_content is null)=(p_state is null) or (p_state is not null and p_state not in ('draft','published','archived')) then
    raise exception using errcode='22023',message='Invalid group structural command.';
  end if;
  intent:=private.group_command_hash(case when p_content is not null then jsonb_build_array('managed_update',p_group,p_version,normalized)
    else jsonb_build_array('managed_state',p_group,p_version,p_state) end);
  perform private.lock_group_command(actor,p_key);
  select * into g from private.community_groups where id=p_group for update;
  perform private.require_group_actor(p_expected);
  authority:=private.group_authority_role(p_group,actor);
  if authority is null or authority not in ('creator','co_creator') then raise exception using errcode='42501',message='The group is unavailable.'; end if;
  select * into receipt from private.community_group_command_receipts where actor_id=actor and client_request_id=p_key;
  if found then
    if receipt.intent_hash<>intent then raise exception using errcode='22023',message='The accepted group command intent differs.'; end if;
    return receipt.accepted_version;
  end if;
  perform private.require_group_manager(p_group,actor,true);
  if p_version is null or p_version<>g.version then raise sqlstate 'PT409' using message='The group changed. Reload before editing.'; end if;
  if authority='co_creator' and ((p_content is not null and g.publication_state<>'published')
    or (p_state is not null and not ((g.publication_state='published' and p_state='archived') or (g.publication_state='archived' and p_state='draft')))) then
    raise exception using errcode='42501',message='The structural action is unavailable.';
  end if;
  if p_content is not null then
    if g.publication_state='archived' then raise exception using errcode='55000',message='Restore the group before editing.'; end if;
    if g.publication_state='published' and (char_length(normalized->>'name')<2 or char_length(normalized->>'description')<20) then
      raise exception using errcode='22023',message='Publication requires a name and purpose.';
    end if;
    if jsonb_build_object('name',g.name,'description',g.description,'group_kind',g.group_kind,'locality',g.locality,'volunteering_focus',g.volunteering_focus)<>normalized then
      update private.community_groups set name=normalized->>'name',description=normalized->>'description',group_kind=normalized->>'group_kind',
        locality=normalized->>'locality',volunteering_focus=(normalized->>'volunteering_focus')::boolean,version=version+1,updated_at=clock_timestamp()
        where id=p_group returning * into g;
      perform private.audit_group_change('group.updated',actor,p_group,g.version);
    end if;
  else
    if g.publication_state='archived' and p_state='published' then raise exception using errcode='55000',message='Restore the archived group to draft before publishing.'; end if;
    if p_state='published' and (char_length(g.name)<2 or char_length(g.description)<20) then raise exception using errcode='22023',message='Publication requires a name and purpose.'; end if;
    if g.publication_state<>p_state then
      update private.community_groups set publication_state=p_state,version=version+1,updated_at=clock_timestamp() where id=p_group returning * into g;
      perform private.audit_group_change('group.publication_changed',actor,p_group,g.version);
    end if;
  end if;
  insert into private.community_group_command_receipts(actor_id,client_request_id,group_id,intent_hash,accepted_version) values(actor,p_key,p_group,intent,g.version);
  return g.version;
end;
$$;
create function public.update_managed_group(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_expected_version bigint,p_content jsonb)
returns bigint language sql security definer set search_path='' as $$
  select private.group_structural_command(p_expected_profile_id,p_group_id,p_client_request_id,p_expected_version,p_content,null);
$$;
create function public.set_managed_group_publication_state(p_expected_profile_id uuid,p_group_id uuid,p_client_request_id uuid,p_expected_version bigint,p_publication_state text)
returns bigint language sql security definer set search_path='' as $$
  select private.group_structural_command(p_expected_profile_id,p_group_id,p_client_request_id,p_expected_version,null,p_publication_state);
$$;
create function public.recover_group_structural_command(p_expected_profile_id uuid,p_client_request_id uuid)
returns table(group_id uuid,accepted_version bigint)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  -- Metadata recovery after restore-to-draft never discloses draft content.
  return query select r.group_id,r.accepted_version from private.community_group_command_receipts r
    where r.actor_id=actor and r.client_request_id=p_client_request_id and private.group_authority_role(r.group_id,actor) in ('creator','co_creator');
end;
$$;
