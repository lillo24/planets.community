-- SIM01: read-only, authenticated upcoming Proposal idea lookup.
-- The lexical normalizer is immutable because it is also a GIN expression.
-- Changing its rules requires rebuilding the index in a forward migration.
create function private.proposal_idea_lexemes(p_text text)
returns text[]
language sql
immutable
security invoker
set search_path = ''
as $$
  select coalesce(array_agg(word order by word), array[]::text[])
  from (
    select distinct token as word
    from pg_catalog.regexp_split_to_table(
      pg_catalog.translate(pg_catalog.lower(coalesce(p_text, '')),
        'àáâäãåèéêëìíîïòóôöõùúûüçñ',
        'aaaaaaeeeeiiiiooooouuuucn'),
      '[^[:alnum:]]+'
    ) as parts(token)
    where pg_catalog.char_length(token) >= 4
      and token ~ '[[:alpha:]]'
      and token <> all(array[
        'about','after','also','anche','ancora','attivita','activity','activities',
        'before','cafe','caffe','city','club','come','community','comunitario',
        'comunitaria','comunitari','comunitarie','condivisa','condiviso','condivise',
        'condivisi','con','dalla','dalle','dallo','degli','della','delle','dello',
        'dentro','dopo','during','each','event','events','evento','eventi','fare',
        'from','friday','giorno','insieme','initiative','iniziativa','iniziative',
        'join','local','locale','locali','lunedi','martedi','meeting','meetup',
        'mercoledi','monday','near','neighborhood','neighbourhood','nostra','nostro',
        'oggi','ogni','oltre','open','other','people','per','prima','project',
        'projects','progetto','progetti','proposal','proposals','proposta','proposte',
        'public','pubblico','pubblica','quartiere','quartieri','sabato','saturday',
        'senza','shared','some','sopra','sotto','sunday','that','their','there',
        'these','this','those','thursday','together','tuesday','tutti','tutto',
        'unico','venerdi','week','weekend','welcome','wednesday','with','your',
        'domenica','giovedi','laboratorio','laboratori','workshop','workshops',
        'incontro','incontri','collaborative','collaborativo','collaborativa',
        'collaborazione','organize','organizzare','giornata','session','sessione',
        'sessioni','work','lavoro','volunteer','volontariato'
      ]::text[])
  ) as words;
$$;

revoke all on function private.proposal_idea_lexemes(text)
  from public, anon, authenticated, service_role;

create index proposals_published_idea_lexemes_idx
  on public.proposals using gin (private.proposal_idea_lexemes(title))
  where lifecycle_state = 'published';

comment on index public.proposals_published_idea_lexemes_idx is
  'SIM01 literal distinct title topics; combines with the existing published starts_at index. No clock-dependent index predicate.';

create function public.list_similar_active_proposals(
  p_expected_profile_id uuid,
  p_title text,
  p_skill_ids uuid[] default null,
  p_country_code text default null,
  p_locality text default null,
  p_excluded_proposal_id uuid default null,
  p_limit integer default 5
)
returns table (
  proposal_id uuid,
  cover_object_path text,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  availability text,
  title_evidence text,
  shared_skill_ids uuid[],
  location_relation text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  reference_time timestamptz := pg_catalog.statement_timestamp();
  country text := pg_catalog.upper(pg_catalog.btrim(p_country_code));
  locality_hint text := nullif(pg_catalog.lower(pg_catalog.regexp_replace(
    pg_catalog.btrim(p_locality), '[[:space:]]+', ' ', 'g')), '');
  selected_skills uuid[];
  idea_words text[];
begin
  perform private.require_expected_identity(p_expected_profile_id);
  if p_title is null or pg_catalog.char_length(p_title) > 100 then
    raise exception using errcode = '22023',
      message = 'Idea title is required and must contain at most 100 characters.';
  end if;
  if p_limit is null or p_limit not between 1 and 10 then
    raise exception using errcode = '22023',
      message = 'Similar Proposal limit must be between 1 and 10.';
  end if;
  if p_country_code is not null and country !~ '^[A-Z]{2}$' then
    raise exception using errcode = '22023',
      message = 'Rough country code must contain two letters.';
  end if;
  if pg_catalog.char_length(p_locality) > 120 then
    raise exception using errcode = '22023',
      message = 'Rough locality must contain at most 120 characters.';
  end if;
  if p_skill_ids is not null and (
    pg_catalog.cardinality(p_skill_ids) > 50
    or coalesce(pg_catalog.array_ndims(p_skill_ids), 1) <> 1
  ) then
    raise exception using errcode = '22023',
      message = 'Selected skills must be a one-dimensional list of at most 50 IDs.';
  end if;
  if exists (
    select 1 from pg_catalog.unnest(p_skill_ids) as selected(id)
    where selected.id is null or not exists (
      select 1 from public.skills as skill where skill.id = selected.id
    )
  ) then
    raise exception using errcode = '22023',
      message = 'Selected skills must be known non-null controlled IDs.';
  end if;
  select coalesce(array_agg(distinct selected.id order by selected.id), array[]::uuid[])
    into selected_skills from pg_catalog.unnest(p_skill_ids) as selected(id);
  select coalesce(array_agg(word order by word), array[]::text[]) into idea_words
    from pg_catalog.unnest(private.proposal_idea_lexemes(p_title)) as words(word)
    where word <> all(private.proposal_idea_lexemes(p_locality));
  -- Weak input exits before candidate reads. Skills cannot admit rows.
  if pg_catalog.cardinality(idea_words) = 0 then return; end if;

  -- SIM01 candidate query: the plan verifier explains this exact query.
  return query
  with admitted as materialized (
    select proposal.*,
      topics.words as candidate_words,
      evidence.words as matching_words
    from public.proposals as proposal
    join public.projects as project on project.id = proposal.id
      and project.project_kind = 'one_time'
    cross join lateral (
      select coalesce(array_agg(word order by word), array[]::text[]) as words
      from pg_catalog.unnest(private.proposal_idea_lexemes(proposal.title)) as terms(word)
      where word <> all(private.proposal_idea_lexemes(proposal.locality))
        and word <> all(private.proposal_idea_lexemes(proposal.administrative_area))
    ) as topics
    cross join lateral (
      select coalesce(array_agg(word order by word), array[]::text[]) as words
      from pg_catalog.unnest(topics.words) as terms(word)
      where word = any(idea_words)
    ) as evidence
    where proposal.lifecycle_state = 'published'
      and proposal.starts_at > reference_time
      and pg_catalog.isfinite(proposal.starts_at)
      and pg_catalog.isfinite(proposal.ends_at)
      and proposal.ends_at > proposal.starts_at
      and private.derive_proposal_status(proposal.starts_at, proposal.ends_at, reference_time) = 'upcoming'
      and (p_excluded_proposal_id is null or proposal.id <> p_excluded_proposal_id)
      and private.proposal_idea_lexemes(proposal.title) && idea_words
      and pg_catalog.cardinality(evidence.words) > 0
      and private.is_project_publicly_viewable(proposal.id)
  ),
  ranked as (
    select candidate.*,
      pg_catalog.cardinality(candidate.matching_words)::numeric /
        greatest(pg_catalog.cardinality(idea_words), pg_catalog.cardinality(candidate.candidate_words)) as title_rank,
      shared.ids as shared_ids,
      case when capacity.registration_capacity is null then 'capacity_unknown'
        when capacity.is_full then 'full' else 'available' end as capacity_state,
      case when locality_hint is not null
        and (country is null or candidate.country_code = country)
        and pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(candidate.locality), '[[:space:]]+', ' ', 'g')) = locality_hint
        then 'same_locality'
        when country is not null and candidate.country_code = country then 'same_country'
        when country is null and locality_hint is null then 'not_provided'
        else 'other' end as rough_relation
    from admitted as candidate
    cross join lateral private.project_registration_capacity_snapshot(candidate.id) as capacity
    cross join lateral (
      select coalesce(array_agg(skill.skill_id order by skill.skill_id), array[]::uuid[]) as ids
      from public.proposal_skills as skill
      where skill.proposal_id = candidate.id and skill.skill_id = any(selected_skills)
    ) as shared
  )
  select candidate.id, cover.object_path, candidate.title, candidate.summary,
    candidate.starts_at, candidate.ends_at, candidate.event_timezone,
    candidate.country_code, candidate.locality, candidate.administrative_area,
    candidate.public_location_label, 'upcoming'::text, candidate.capacity_state,
    case when pg_catalog.cardinality(candidate.matching_words) > 1
      then 'multiple_title_terms' else 'title_topic' end,
    candidate.shared_ids, candidate.rough_relation
  from ranked as candidate
  left join public.project_covers as cover on cover.project_id = candidate.id
  order by candidate.title_rank desc,
    pg_catalog.cardinality(candidate.shared_ids) desc,
    case candidate.capacity_state when 'available' then 0 when 'capacity_unknown' then 1 else 2 end,
    case candidate.rough_relation when 'same_locality' then 0 when 'same_country' then 1 else 2 end,
    candidate.starts_at, candidate.id
  limit p_limit;
end;
$$;

revoke all on function public.list_similar_active_proposals(uuid, text, uuid[], text, text, uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.list_similar_active_proposals(uuid, text, uuid[], text, text, uuid, integer)
  to authenticated;

comment on function public.list_similar_active_proposals(uuid, text, uuid[], text, text, uuid, integer) is
  'SIM01 expected-actor read-only top 1-10 upcoming public one-time matches. Distinct literal title topics admit; overlap/max-topic-count, shared skills, known availability, rough locality, start/UUID rank deterministically. No private input persistence, counts, relationship or join authority. See docs/development/similar-active-proposals.md.';
