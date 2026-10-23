-- Durable ready-to-join state belongs to interested rows, not Realtime delivery.
-- A withdrawn proposer can accumulate more than the activation threshold before
-- rejoining. Bound optional refresh invalidations; every interested actor still
-- sees the invitation on entry or the existing foreground 20-second refresh.
-- Ordinary three-person activation continues to invalidate all three actors.
do $$
declare
 source text := pg_get_functiondef(
  'public.mutate_cocreate_community_interest(uuid,uuid,uuid,text)'::regprocedure);
 needle text := 'for person in select actor_id from private.cocreate_community_interests where proposal_id=p.id and interested loop';
 replacement text := 'for person in select actor_id from private.cocreate_community_interests where proposal_id=p.id and interested order by actor_id limit 25 loop';
begin
 if strpos(source,needle)=0
  or strpos(source,'perform private.cocreate_signal(person);end loop;')=0
  or strpos(source,'private.cocreate_proposal_support(p.id)>=threshold')=0 then
  raise exception 'Unknown community activation predecessor; inspect before bounding refresh signals.';
 end if;
 -- CREATE OR REPLACE retains the canonical function OID, ACL and result shape.
 execute replace(source,needle,replacement);
end;
$$;
