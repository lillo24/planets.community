# Product Decisions

**Status:** Accepted product decisions that supersede older tentative wording until the owning implementation plans fold them into canonical domain documentation.

## Proposal chat

Current product direction:

- A proposal/project group chat is created automatically by the system. There is no user-facing manual **Create chat** action.
- Chat creation is **not gated by a fixed three-person threshold**. Participation or activation thresholds may exist for other project rules, but future plans must not assume that `3` controls chat availability.
- The exact canonical participation event that triggers automatic chat creation will be finalized together with plans 05/07. The operation must be idempotent and create at most one chat for a proposal.
- A proposal/project ending or becoming historical does **not** delete its chat or messages. For now they are retained as historical canonical data.
- Authorization after a participant leaves, is removed, blocked, or suspended remains a separate decision for plan 07. Retention after project completion is already decided; completion alone must not delete chat history.

This decision supersedes the older tentative `chat after at least three people` wording in `docs/architecture/system-design.md` and the threshold-gated chat wording in `docs/implementation/roadmap.md`. Future implementation plans must use this decision unless it is explicitly revised.
