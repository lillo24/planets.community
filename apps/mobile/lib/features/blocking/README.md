# Blocking feature

This folder owns the ordinary-user mobile experience for the canonical user
blocking domain. The client can read only the signed-in profile's outbound
status for an exact target or its paginated outbound management list. It never
receives or infers inbound/reciprocal block state.

- `domain/` defines safe outbound rows, pagination, and failure state.
- `data/` calls only `get_own_blocked_profile_status`,
  `list_own_blocked_profiles`, `block_user`, and `unblock_user`.
- `application/` owns identity-scoped exact-status caching, list pagination,
  duplicate-action protection, stale-operation rejection, and target photo
  invalidation.
- `presentation/` owns the reusable confirmation action and Profile management
  screen.

Blocking never filters public content, removes Project members/messages, or
closes accepted Scambio-Dona coordination. Pending request closure and all
symmetric interaction enforcement remain canonical PostgreSQL behavior.
