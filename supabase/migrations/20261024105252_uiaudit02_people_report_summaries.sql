-- FO1: People reporting extended the target vocabulary without extending this
-- shared safe summary. All supported own-report readers call it. Keep the
-- existing identity/ownership/pagination and legacy summary chain unchanged.
do $$
declare
  definition text := pg_get_functiondef(
    'private.moderation_target_summary(private.moderation_cases)'::regprocedure
  );
begin
  if strpos(definition, 'FUNCTION private.moderation_target_summary(') = 0 then
    raise exception 'The predecessor moderation summary is missing.';
  end if;
  execute replace(
    definition,
    'FUNCTION private.moderation_target_summary(',
    'FUNCTION private.pre_uiaudit02_moderation_target_summary('
  );
end;
$$;

create or replace function private.moderation_target_summary(
  p_case private.moderation_cases
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case p_case.target_kind
    when 'cocreate_post' then 'Find People post'
    when 'cocreate_interest' then 'Find People request'
    when 'cocreate_contact_message' then 'Find People private message'
    when 'cocreate_room_message' then 'Find People group message'
    when 'cocreate_community_proposal' then 'Find People community proposal'
    else private.pre_uiaudit02_moderation_target_summary(p_case)
  end;
$$;

-- CREATE OR REPLACE preserves the existing helper's privileges. The copied
-- predecessor is internal too; no new callable API or evidence lookup is added.
revoke all on function private.pre_uiaudit02_moderation_target_summary(
  private.moderation_cases
) from public, anon, authenticated, service_role;
