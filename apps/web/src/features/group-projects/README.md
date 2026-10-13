# Public group Project attribution

This feature shares the canonical publication-provenance contract with mobile.
It adds no web authoring, private planning, group authority or participation rule.

- `group-project-models.ts` parses only allowlisted current/neutral badges and
  bounded public Project rows.
- `group-project-server.ts` performs one public badge batch for a server page.
- `project-group-badge.tsx` renders the public group link or neutral unavailable
  label, including inside public invitation/share/confirmation cards.
- `group-project-feed.tsx` owns explicit cursor paging, retry and stale-response
  rejection on the existing group landing page.
- `group-projects.test.tsx` checks public payload/identity privacy, batches and
  page retries without treating fixtures as browser or hosted proof.
