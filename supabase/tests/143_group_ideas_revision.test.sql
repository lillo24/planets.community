begin;
select no_plan();
select has_column('private','group_discussions','kind','General uses canonical room identity');
select has_column('private','group_discussions','frozen_at','Conversion freezes the existing source');
select has_column('private','group_discussion_admissions','end_sequence','Former frontier is ordinal, not a mutable timestamp');
select has_column('private','community_groups','idea_creation_policy','Group owns reversible creation policy');
select has_index('private','group_discussions','group_discussion_one_general','Exactly one General per Group');
select has_table('private',t,'Revision owns scoped private state') from unnest(array[
 'group_discussion_views','group_discussion_preferences','group_discussion_invitation_links','group_discussion_events','group_discussion_notice_reads']) t;
select ok(relrowsecurity,relname||' enables RLS') from pg_class where relnamespace='private'::regnamespace and relname like 'group_discussion%' and relkind='r';
select ok(not has_table_privilege(r,t,p),r||' cannot directly '||p||' '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['private.group_discussion_views','private.group_discussion_preferences','private.group_discussion_invitation_links','private.group_discussion_events','private.group_discussion_notice_reads']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE']) p;
select ok(not has_function_privilege('anon',oid,'execute') and not has_function_privilege('service_role',oid,'execute'),proname||' denies API bypass')
from pg_proc where pronamespace='public'::regnamespace and (proname like '%group_discussion%' or proname='list_my_discussion_groups_v2');
select ok(not has_function_privilege('authenticated',oid,'execute'),proname||' is private') from pg_proc where pronamespace='private'::regnamespace
 and proname like '%group_discussion%' and proname<>'group_discussion_topic_allowed';
select ok(proconfig @> array['search_path=""'],proname||' fixes search path') from pg_proc
where pronamespace in ('public'::regnamespace,'private'::regnamespace) and proname like '%group_discussion%';
select has_trigger('private','group_discussion_admissions','a_group_discussion_capture_exit','Exit captures locked sequence and metadata snapshot');
select has_trigger('private','community_groups','community_groups_ensure_general','Publication creates General atomically');
select has_trigger('private','group_memberships','group_memberships_start_general','New Group membership starts independent General unread baseline');
set local role anon;
select throws_ok($$select public.get_group_discussion_v2(null,gen_random_uuid())$$,'42501',null,'Anonymous cannot discover private Group rooms');
select throws_ok($$select public.preview_group_discussion_invitation_link(null,repeat('a',64))$$,'42501',null,'Anonymous capability possession grants no Group entry');
select throws_ok($$select public.list_group_discussion_invitations_v2(null)$$,'42501',null,'Anonymous cannot read targeted consent context');
reset role;
select * from finish();
rollback;
