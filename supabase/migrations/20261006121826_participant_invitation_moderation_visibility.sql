-- MODINT01: main's PI01 lifecycle predicate predates integration with content
-- hides. Reuse the canonical public visibility boundary without altering
-- private management or read-only admission receipts for existing members.
create or replace function private.project_accepts_participant_invitations(p_project_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
    left join public.recurring_activities activity on activity.id = p.id and p.project_kind = 'recurring'
    where p.id = p_project_id
      and private.is_project_publicly_viewable(p.id)
      and (
        (p.project_kind = 'one_time' and proposal.lifecycle_state = 'published'
          and clock_timestamp() < proposal.ends_at)
        or (p.project_kind = 'recurring' and activity.lifecycle_state = 'published')
      )
  );
$$;
comment on function private.project_accepts_participant_invitations(uuid) is
  'Public participant-link preview/fresh admission requires canonical visibility plus open lifecycle. A hidden Project reveals no title/ID. Existing own action receipt recovery remains read-only and uses the separate expected-account gate.';
