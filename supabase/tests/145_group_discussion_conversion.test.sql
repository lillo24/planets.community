begin;
select no_plan();
select has_table('private',t,'Conversion provenance is private') from unnest(array['group_discussion_conversions','group_discussion_project_invitations','group_discussion_conversion_receipts']) t;
select ok(not has_table_privilege(r,'private.'||t,p),r||' cannot directly '||p||' '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['group_discussion_conversions','group_discussion_project_invitations','group_discussion_conversion_receipts']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
select ok(prosecdef and proconfig @> array['search_path=""'],proname||' fixes privileged search path') from pg_proc
where pronamespace='public'::regnamespace and proname=any(array['get_group_discussion_conversion','request_group_discussion_publication','review_group_discussion_publication','create_group_discussion_project_draft','list_my_discussion_project_invitations','respond_discussion_project_invitation','get_project_discussion_origin','share_discussion_link_to_project']);
select ok(not has_function_privilege(r,oid,'execute'),r||' cannot invoke '||proname) from pg_proc
cross join unnest(array['anon','service_role']) r
where pronamespace='public'::regnamespace and proname=any(array['get_group_discussion_conversion','request_group_discussion_publication','review_group_discussion_publication','create_group_discussion_project_draft','list_my_discussion_project_invitations','respond_discussion_project_invitation','get_project_discussion_origin','share_discussion_link_to_project']);
select has_trigger('public','proposals','zzz_proposals_freeze_discussion_publication','Legacy and current publishers share conversion guard');
select has_trigger('private','group_discussion_conversions','discussion_conversion_provenance','Origin and published boundary cannot be reassigned');
select has_trigger('private','group_discussion_conversion_receipts','discussion_conversion_receipts_immutable','Accepted conversion commands are immutable');
select has_index('private','group_discussion_project_invitations','discussion_project_invitation_actor_page','Invitation paging has actor/time/id index');
select ok(not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
  where c.contype='f' and c.conrelid in ('private.group_discussion_conversions'::regclass,'private.group_discussion_project_invitations'::regclass)
  and a.attname in ('proposed_by','publisher_id','recipient_id','reviewed_by')),'Raw human provenance adds no deletion blocker');
select * from finish();
rollback;
