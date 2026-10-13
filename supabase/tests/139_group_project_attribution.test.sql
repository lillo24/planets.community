begin;
select no_plan();
select has_column('public','projects',name,'Project anchor owns private publication provenance')
from unnest(array['attributed_group_id','attribution_version','attribution_assigned_by','attribution_assigned_at','first_published_at','attribution_published_by']) name;
select ok(not has_table_privilege(r,t,p),r||' cannot directly '||p||' '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['public.projects','private.project_attribution_receipts']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
select ok(prosecdef and proconfig @> array['search_path=""'],proname||' fixes the definer search path')
from pg_proc where pronamespace in ('public'::regnamespace,'private'::regnamespace)
and proname=any(array['require_project_group_representation','project_group_binding','assign_project_group','freeze_project_group_publication','protect_frozen_project_group','get_own_project_group','set_project_group','list_my_publishable_groups','get_public_project_groups','list_public_group_projects','create_group_editor_proposal_draft','create_group_editor_recurring_activity_draft','create_group_proposal_draft_from_template','publish_project_with_group']);
select ok(not has_function_privilege('service_role',oid,'execute'),proname||' has no service-role API bypass')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['get_own_project_group','set_project_group','list_my_publishable_groups','get_public_project_groups','list_public_group_projects','create_group_editor_proposal_draft','create_group_editor_recurring_activity_draft','create_group_proposal_draft_from_template','publish_project_with_group']);
select ok(not has_function_privilege('anon',oid,'execute'),proname||' private command denies guests')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['get_own_project_group','set_project_group','list_my_publishable_groups','create_group_editor_proposal_draft','create_group_editor_recurring_activity_draft','create_group_proposal_draft_from_template','publish_project_with_group']);
select ok(not exists(select 1 from pg_constraint where contype='f'
  and conrelid='private.project_attribution_receipts'::regclass),'Attribution receipts add no deletion-blocking references');
select ok(not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
  where c.contype='f' and c.conrelid='public.projects'::regclass
    and a.attname in ('attributed_group_id','attribution_assigned_by','attribution_published_by')),'Raw provenance adds no erasure/history cascade');
select has_index('public','projects','projects_group_publication_idx','Group feed has paired stable publication index');
select has_trigger('public','proposals','zz_proposals_freeze_group_publication','Every one-time source transition freezes/validates');
select has_trigger('public','recurring_activities','zz_recurring_freeze_group_publication','Every Tavolo source transition freezes/validates');
select has_trigger('public','projects','projects_protect_group_publication','Published provenance cannot be switched or cleared');
select has_trigger('private','project_attribution_receipts','project_attribution_receipts_append_only','Receipts are immutable');
set local role anon;
select is(public.get_public_project_groups(array[]::uuid[]),'[]'::jsonb,'Empty public batch is a valid domain result');
select throws_ok($$select public.get_public_project_groups(null)$$,'22023',null,'Null batch fails explicitly');
select throws_ok($$select public.get_public_project_groups(array_fill(gen_random_uuid(),array[51]))$$,'22023',null,'Batch bound enforced');
select throws_ok($$select public.list_public_group_projects(gen_random_uuid(),51)$$,'22023',null,'Feed bound enforced');
select throws_ok($$select public.list_public_group_projects(gen_random_uuid(),20,null,gen_random_uuid())$$,'22023',null,'Cursor components paired');
select throws_ok($$select public.list_public_group_projects(gen_random_uuid())$$,'42501',null,'Unavailable group is explicit');
reset role;
select * from finish();
rollback;
