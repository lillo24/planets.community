-- Additive C-aware summary. Installed summaries and strict chat projections
-- retain their released contracts and audiences.
-- Recheck live identity after locks for exit/decline, which correctly bypass
-- content entitlement but must never bypass account existence.
do $$ declare definition text:=pg_get_functiondef('private.group_discussion_command(uuid,uuid,text,uuid,uuid,jsonb)'::regprocedure);
  marker text:='  select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_key;';
begin
  if strpos(definition,marker)=0 then raise exception 'The C01 command boundary is missing.'; end if;
  execute replace(definition,marker,'  perform private.require_group_identity(p_actor);'||chr(10)||marker);
end; $$;
create function public.get_own_message_unread_summary_with_discussions(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); base jsonb; rooms bigint;
begin
  base:=public.get_own_message_unread_summary(actor);
  select count(distinct m.room_id) into rooms from private.group_discussion_messages m
    join private.group_discussion_admissions a on a.id=private.group_discussion_admission(m.room_id,actor)
    where m.sender_id<>actor and m.sequence>greatest(a.frontier,a.read_sequence);
  return jsonb_build_object('total',(base->>'total')::bigint+rooms,'private',(base->>'private')::bigint,'groups',(base->>'groups')::bigint+rooms);
end; $$;
revoke all on function public.get_own_message_unread_summary_with_discussions(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_message_unread_summary_with_discussions(uuid) to authenticated;
create function public.get_group_discussion_message_page(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language sql stable security definer set search_path='' as $$
  select public.list_group_discussion_messages(p_expected_profile_id,p_room_id,p_limit,p_before_sequence)
    ||jsonb_build_object('profile_id',p_expected_profile_id,'room_id',p_room_id,'admission_id',private.require_group_discussion(p_room_id,p_expected_profile_id));
$$;
revoke all on function public.get_group_discussion_message_page(uuid,uuid,integer,bigint) from public,anon,authenticated,service_role;
grant execute on function public.get_group_discussion_message_page(uuid,uuid,integer,bigint) to authenticated;
create or replace function private.group_discussion_signal(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform realtime.send(jsonb_build_object('profile_id',p_actor),'changed','group-discussions:profile:'||p_actor::text,true);
  perform private.signal_message_unread(p_actor);
end; $$;

-- JSON display identities may be unavailable. Localization belongs to the
-- client; an English placeholder is not a canonical personal display name.
do $$ declare signature text; definition text; begin
  foreach signature in array array[
    'public.list_group_discussion_messages(uuid,uuid,integer,bigint)',
    'public.list_group_discussion_invitations(uuid,integer,timestamptz,uuid)',
    'public.list_group_discussion_people(uuid,uuid,integer,timestamptz,uuid)',
    'public.list_group_discussion_managed_invitations(uuid,uuid,integer,timestamptz,uuid)'
  ] loop
    definition:=pg_get_functiondef(signature::regprocedure);
    if strpos(definition,'coalesce(p.display_name,''Deleted account'')')=0 then raise exception 'The predecessor display contract is missing: %',signature; end if;
    execute replace(definition,'coalesce(p.display_name,''Deleted account'')','p.display_name');
  end loop;
end; $$;

-- Keep all legacy target summaries and add an explicit content-safe label.
do $$ declare definition text:=pg_get_functiondef('private.moderation_target_summary(private.moderation_cases)'::regprocedure); begin
  if strpos(definition,'FUNCTION private.moderation_target_summary(')=0 then raise exception 'The predecessor moderation summary is missing.'; end if;
  execute replace(definition,'FUNCTION private.moderation_target_summary(','FUNCTION private.pre_discussion_moderation_target_summary(');
end; $$;
create or replace function private.moderation_target_summary(p_case private.moderation_cases) returns text
language sql stable security definer set search_path='' as $$
  select case when p_case.target_kind='group_discussion_message' then 'Group discussion message'
    else private.pre_discussion_moderation_target_summary(p_case) end;
$$;
revoke all on function private.pre_discussion_moderation_target_summary(private.moderation_cases) from public,anon,authenticated,service_role;
