-- Closed D01 clients cannot parse extra meeting fields. Keep their installed
-- readers/OIDs/ACLs, with a non-actionable nine-field card for dated requests.
-- New readers retain the same episode/history/ACK checks and full dated card.
create function private.cocreate_recruitment_projection_legacy(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb:=private.cocreate_recruitment_projection(p_id);
begin
 if result ? 'meeting_id' then
  return (result-'meeting_id'-'starts_at')||jsonb_build_object(
   'available',false,'state','unavailable','capacity',null,'occupied',null);
 end if;
 return result;
end; $$;
revoke all on function private.cocreate_recruitment_projection_legacy(uuid)
 from public,anon,authenticated,service_role;

do $$ declare old_name text; new_name text; signature text; source text;
begin
 for old_name,new_name,signature in values
  ('get_own_cocreate_recruitment','get_own_cocreate_recruitment_v2','uuid,uuid,uuid'),
  ('get_cocreate_recruitment','get_cocreate_recruitment_v2','uuid,uuid,uuid,uuid'),
  ('get_cocreate_room_page_v2','get_cocreate_room_page_v3','uuid,uuid,uuid,integer,bigint')
 loop
  source:=pg_get_functiondef(('public.'||old_name||'('||signature||')')::regprocedure);
  if strpos(source,'private.cocreate_recruitment_projection(')=0
   or strpos(source,'FUNCTION public.'||old_name||'(')=0
   or to_regprocedure('public.'||new_name||'('||signature||')') is not null then
   raise exception 'Unknown scheduled-card reader predecessor: %',old_name;
  end if;
  execute replace(source,'FUNCTION public.'||old_name||'(','FUNCTION public.'||new_name||'(');
  execute replace(source,'private.cocreate_recruitment_projection(',
   'private.cocreate_recruitment_projection_legacy(');
 end loop;
end; $$;

revoke all on function public.get_own_cocreate_recruitment_v2(uuid,uuid,uuid),
 public.get_cocreate_recruitment_v2(uuid,uuid,uuid,uuid),
 public.get_cocreate_room_page_v3(uuid,uuid,uuid,integer,bigint)
 from public,anon,authenticated,service_role;
grant execute on function public.get_own_cocreate_recruitment_v2(uuid,uuid,uuid),
 public.get_cocreate_recruitment_v2(uuid,uuid,uuid,uuid),
 public.get_cocreate_room_page_v3(uuid,uuid,uuid,integer,bigint) to authenticated;
