# A01 — Personal-account-first group creation shortcut (original implementation plan)

**Status at archive:** Implemented through Batch A integration PR #243. This is a historical prompt reconstruction, not a new assignment.

## Goal

A first-time user completes the normal personal account/profile setup and may then choose to create a group. One personal Auth identity can create and later manage multiple registered groups; the group is not a separate login and no legal verification is claimed. The person who deliberately creates the group becomes its canonical Creator through existing group creation, not through the onboarding offer.

## Original work scope

Inspect the current personal profile setup save handler, startup/continuation coordinator, My groups and group editor routes, group admission/link onboarding, current Auth/policy tests and localization. Present a skippable “Do you represent a group?” invitation only **after a successful explicit first profile-completion save**. Offer Create a group and Not now. Create routes to the existing group editor, where saving/publishing remains an explicit separate operation; skip returns to normal app navigation. Profile → My groups → Create remains available later.

Retain the ordinary required personal-name rule. Do not require extra photo, gender, age, tax number, postcode or legal-entity proof. Do not generate duplicate groups, add new group credentials or invent a separate onboarding state machine.

## Critical continuation behavior

A pending Project/Tavolo join, group admission/authority invitation, return to report, policy or requested profile/photo step takes priority. Do not interrupt these journeys with an optional group-creation step. Completing personal setup must not automatically accept invitations, send a join request, create a group or change any role.

The offer is once per eligible setup completion, not on every login, later profile edit, tutorial replay or account restoration. Authentication changes or late profile-save responses must invalidate stale callbacks. Canceling the group editor preserves the completed personal profile.

## Required evidence

Ordinary signup, Create, Not now, returning-account suppression, failed save and retry, repeated tap, concurrent pending invitation, account switching, route cancellation, EN/IT, narrow layout and accessibility. Verify a confirmed group creation through canonical backend state and exactly one Creator, not a client-only success message.

## Delivery

Use a narrow Flutter change, feature tests and localized copy; preserve group backend semantics. In the original batch, this was A01's draft stacked PR, merged only through the final integration gate. See PR #238/#243 for actual implementation evidence.
