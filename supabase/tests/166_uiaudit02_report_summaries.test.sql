begin;
select plan(13);

-- Generic People summaries require no source join or private evidence read.
select is(private.moderation_target_summary(
  jsonb_populate_record(null::private.moderation_cases, jsonb_build_object('target_kind', kind))
), summary, 'FO1 bounded summary: ' || kind)
from (values
  ('cocreate_post', 'Find People post'),
  ('cocreate_interest', 'Find People request'),
  ('cocreate_contact_message', 'Find People private message'),
  ('cocreate_room_message', 'Find People group message'),
  ('cocreate_community_proposal', 'Find People community proposal')
) as expected(kind, summary);

select is(private.moderation_target_summary(
  jsonb_populate_record(null::private.moderation_cases, jsonb_build_object('target_kind', kind))
), summary, 'FO1 legacy summary: ' || kind)
from (values
  ('resource_request', 'Resource request'),
  ('group_discussion_message', 'Group discussion message'),
  ('member_contact_request', 'Personal conversation request'),
  ('member_contact_message', 'Personal conversation message')
) as expected(kind, summary);

select is(has_function_privilege('anon',
  'private.moderation_target_summary(private.moderation_cases)', 'execute'), false,
  'anon cannot call the private summary');
select is(has_function_privilege('authenticated',
  'private.moderation_target_summary(private.moderation_cases)', 'execute'), false,
  'ordinary users cannot call the private summary');
select is(has_function_privilege('authenticated',
  'private.pre_uiaudit02_moderation_target_summary(private.moderation_cases)', 'execute'), false,
  'copied predecessor remains private');
select is((select proconfig from pg_proc where oid =
  'private.moderation_target_summary(private.moderation_cases)'::regprocedure),
  array['search_path=""']::text[], 'empty search_path is preserved');

select * from finish();
rollback;
