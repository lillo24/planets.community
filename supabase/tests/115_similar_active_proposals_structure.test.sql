begin;
select no_plan();
select has_function('public','list_similar_active_proposals',
  array['uuid','text','uuid[]','text','text','uuid','integer'],'one narrow matching RPC');
select ok((select prosecdef and provolatile='s' and proconfig @> array['search_path=""']
  from pg_proc where oid='public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)'::regprocedure),
  'stable security-definer API with empty search path');
select ok(has_function_privilege('authenticated','public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)','EXECUTE'),
  'authenticated execution is granted');
select ok(not has_function_privilege(role_name,'public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)','EXECUTE'),
  role_name || ' has no execution')
from unnest(array['anon','service_role']) as roles(role_name);
select ok(not exists(select 1 from pg_proc p, lateral aclexplode(p.proacl) a
  where p.oid='public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)'::regprocedure
  and a.grantee=0 and a.privilege_type='EXECUTE'),'no implicit PUBLIC execution');
select ok(not has_function_privilege(role_name,'private.proposal_idea_lexemes(text)','EXECUTE'),
  role_name || ' cannot call raw normalizer')
from unnest(array['anon','authenticated','service_role']) as roles(role_name);
select is((select proargnames[8:23] from pg_proc
  where oid='public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)'::regprocedure),
  array['proposal_id','cover_object_path','title','summary','starts_at','ends_at','event_timezone',
    'country_code','locality','administrative_area','public_location_label','derived_status',
    'availability','title_evidence','shared_skill_ids','location_relation'],
  'exact public response allow-list: no counts, private content, identities or receipts');
select is((select provolatile::text from pg_proc where oid='private.proposal_idea_lexemes(text)'::regprocedure),
  'i','index normalizer is immutable');
select ok(exists(select 1 from pg_index i join pg_class c on c.oid=i.indexrelid
  join pg_am a on a.oid=c.relam where c.relname='proposals_published_idea_lexemes_idx'
  and a.amname='gin' and i.indpred is not null),'partial GIN narrows published title topics');
select is(private.proposal_idea_lexemes('  Repair, CAFÉ repair! di quartiere '),array['repair'],'distinct accent-folded topics');
select is(private.proposal_idea_lexemes('Progetto comunitario a Roma'),array['roma'],'generic activity words are removed');
select is(private.proposal_idea_lexemes('!!! % _ & | :* 12345 a the con di'),array[]::text[],'operators and common-only input are not topics');
select is(private.proposal_idea_lexemes('Murale comunitario'),array['murale'],'useful Italian topic');
select is(private.proposal_idea_lexemes('Community garden together'),array['garden'],'useful English topic');
select is(private.proposal_idea_lexemes('Laboratorio comunitario workshop condiviso'),array[]::text[],'generic workshop language cannot admit candidates');
select isnt(private.proposal_idea_lexemes('gardening'),private.proposal_idea_lexemes('garden'),'no undocumented stemming');
select throws_ok($$select public.list_similar_active_proposals(null,'murale')$$,'42501',null,'identity required even before input validation');
select * from finish();
rollback;
