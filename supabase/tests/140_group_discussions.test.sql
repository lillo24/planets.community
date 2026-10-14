begin;
select no_plan();
select has_table('private',t,'C01 owns a private domain table') from unnest(array[
  'group_discussions','group_discussion_admissions','group_discussion_invitations','group_discussion_messages','group_discussion_receipts']) t;
select ok(relrowsecurity,relname||' enables RLS') from pg_class where relnamespace='private'::regnamespace and relname like 'group_discussion%' and relkind='r';
select ok(not has_table_privilege(r,t,p),r||' cannot directly '||p||' '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['private.group_discussions','private.group_discussion_admissions','private.group_discussion_invitations','private.group_discussion_messages','private.group_discussion_receipts']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
select ok(not has_function_privilege('anon',oid,'execute') and not has_function_privilege('service_role',oid,'execute'),proname||' denies API bypass')
from pg_proc where pronamespace='public'::regnamespace and (proname like '%group_discussion%' or proname='list_my_discussion_groups');
select ok(not has_function_privilege('authenticated',oid,'execute'),proname||' is not a private command endpoint')
from pg_proc where pronamespace='private'::regnamespace and proname like '%group_discussion%' and proname<>'group_discussion_topic_allowed';
select ok(proconfig @> array['search_path=""'],proname||' fixes search path')
from pg_proc where pronamespace in ('public'::regnamespace,'private'::regnamespace) and proname like '%group_discussion%';
select ok(not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
  where c.contype='f' and c.conrelid in ('private.group_discussions'::regclass,'private.group_discussion_admissions'::regclass,'private.group_discussion_invitations'::regclass,'private.group_discussion_messages'::regclass,'private.group_discussion_receipts'::regclass)
    and a.attname in ('actor_id','profile_id','creator_id','sender_id','inviter_id','recipient_id','source_id')),'New raw actor provenance adds no deletion-blocking foreign keys');
select has_trigger('private','group_discussion_messages','group_discussion_messages_immutable','Messages are immutable');
select has_trigger('private','group_discussion_receipts','group_discussion_receipts_immutable','Receipts are immutable');
select has_trigger('private','group_memberships','group_memberships_end_discussion_source','Group leave ends concrete admission');
select has_trigger('private','group_delegates','group_delegates_end_discussion_source','Role revocation ends concrete admission');
select has_column('private','moderation_cases','target_group_discussion_message_id','Reports are genuine typed cases');
select has_trigger('private','moderation_cases','moderation_cases_discussion_identity','New evidence is immutable');
set local role anon;
select throws_ok($$select public.get_group_discussion(null,gen_random_uuid())$$,'42501',null,'Guest cannot read room');
select throws_ok($$select public.create_group_discussion(null,gen_random_uuid(),gen_random_uuid(),'Parco')$$,'42501',null,'Guest cannot create room');
reset role;
select * from finish();
rollback;
