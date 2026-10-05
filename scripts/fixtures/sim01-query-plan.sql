-- Local-only scale fixture, executed inside the verifier's rollback transaction.
-- Meaningful upcoming/control sources use canonical domain commands.
do $$
declare
  actor uuid := current_setting('request.jwt.claim.sub')::uuid;
  id uuid;
  topic text;
begin
  for n in 1..1120 loop
    topic := case when n <= 60 then 'Clockwork repair'
      when n <= 120 then 'Community garden' else 'Woodworking bookcase' end;
    id := public.create_proposal_draft(actor,topic,'SIM01 scale public preview',
      'Synthetic scale description','2098-02-01T10:00:00Z','2098-02-01T12:00:00Z',
      'Europe/Rome','IT','Trento','TN','Rough area','LOCAL_ONLY','participants',
      array[]::uuid[],array[]::text[],4,false);
    perform public.publish_proposal(actor,id);
  end loop;
  id := public.create_proposal_draft(actor,'Clockwork community project',
    'SIM01 scale public preview','Synthetic scale description',
    '2098-12-01T10:00:00Z','2098-12-01T12:00:00Z','Europe/Rome','IT','Trento','TN',
    'Rough area','LOCAL_ONLY','participants',array[]::uuid[],array[]::text[],4,false);
  perform public.publish_proposal(actor,id);
  perform set_config('test.sim01_best',id::text,true);
end;
$$;

-- Trusted SQL creates only synthetic historical/cancelled negatives. These
-- intentionally represent legacy rows without client publication/photo history.
-- No actual source or committed production seed is modified.
insert into public.proposals(creator_profile_id,lifecycle_state,title,summary,
  description,starts_at,ends_at,event_timezone,country_code,locality,
  public_location_label,published_at,cancelled_at)
select current_setting('request.jwt.claim.sub')::uuid,
  case when n<=6000 then 'published' else 'cancelled' end,
  case when n<=6000 then 'Community garden' else 'Clockwork repair' end,
  'SIM01 scale negative','Synthetic scale negative',
  case when n<=6000 then '2020-01-01T10:00:00Z'::timestamptz else '2098-02-01T10:00:00Z'::timestamptz end,
  case when n<=6000 then '2020-01-01T12:00:00Z'::timestamptz else '2098-02-01T12:00:00Z'::timestamptz end,
  'Europe/Rome','IT','Trento','Rough area',now(),
  case when n>6000 then clock_timestamp() else null end
from generate_series(1,10000) as population(n);
