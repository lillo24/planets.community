begin;

select no_plan();

select ok(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ) like '%raise sqlstate ''pt409''%',
  'membership commitment stale snapshots use the PostgREST conflict marker'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ) not like '%40001%',
  'membership commitment code does not author a serialization failure'
);

select ok(
  lower(
    pg_get_functiondef(
      'public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure
    )
  ) like '%raise sqlstate ''pt409''%',
  'already-covered requirement claims use the PostgREST conflict marker'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure
    )
  ) not like '%40001%',
  'requirement claim code does not author a serialization failure'
);

select ok(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
    )
  ) like '%raise sqlstate ''pt409''%',
  'actual-contribution stale snapshots use the PostgREST conflict marker'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
    )
  ) not like '%40001%',
  'actual-contribution code does not author a serialization failure'
);

select * from finish();

rollback;
