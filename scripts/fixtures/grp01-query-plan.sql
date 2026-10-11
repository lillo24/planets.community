-- Representative fictional plans, not a production scale/throughput promise.
begin;
insert into auth.users(id,email) values ('e7900000-0000-4000-8000-000000000001','grp-plan@planets.invalid');
insert into public.profiles(id,display_name) values ('e7900000-0000-4000-8000-000000000001','Fictional query-plan owner');
insert into private.community_groups(name,description,group_kind,locality,volunteering_focus,publication_state,original_actor_id,created_at)
select 'Fictional group '||n,'Fictional local garden cooperation.',case when n%3=0 then 'organization' else 'informal' end,
  case when n%5=0 then 'Trento' else 'Other territory' end,n%2=0,'published','e7900000-0000-4000-8000-000000000001',
  '2026-01-01'::timestamptz+n*interval '1 second' from generate_series(1,1000) n;
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
select id,'e7900000-0000-4000-8000-000000000001','e7900000-0000-4000-8000-000000000001'
from private.community_groups where original_actor_id='e7900000-0000-4000-8000-000000000001';
analyze private.community_groups;
analyze private.community_group_managers;
explain (analyze,buffers) select g.id from private.community_groups g
join private.community_group_managers m on m.group_id=g.id
join public.profiles p on p.id=m.profile_id and p.display_name is not null
join auth.users a on a.id=p.id
where g.publication_state='published' and not g.directory_suppressed
order by g.created_at desc,g.id desc limit 25;
explain (analyze,buffers) select g.id from private.community_groups g
join private.community_group_managers m on m.group_id=g.id
join public.profiles p on p.id=m.profile_id and p.display_name is not null
join auth.users a on a.id=p.id
where g.publication_state='published' and not g.directory_suppressed
and lower(g.locality)='trento' and g.group_kind='informal' and g.volunteering_focus
and strpos(lower(g.name||' '||g.description),'garden')>0
and (g.created_at,g.id)<('2026-01-01 00:12:00+00','ffffffff-ffff-ffff-ffff-ffffffffffff')
order by g.created_at desc,g.id desc limit 25;
explain (analyze,buffers) select g.id from private.community_groups g
join private.community_group_managers m on m.group_id=g.id
where m.profile_id='e7900000-0000-4000-8000-000000000001'
order by g.created_at desc,g.id desc limit 25;
rollback;
