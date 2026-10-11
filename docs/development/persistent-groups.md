# GRP01 persistent groups backend

GRP01 establishes durable registered group identities and canonical backend
commands. GRP02 now supplies mobile directory, registration and profile screens,
and protected web staff controls; see [the integration guide](grp02-groups-ui.md). Personal
login, registered groups, Project participation and Project chats are separate.
Groups may exist without Projects or members. Organization kind and volunteering
focus are manager declarations, never accreditation or legal/ETS verification.
Official starter-template attribution remains catalog provenance, outside this
directory.

## Records and exposure

All records live in `private`, enable RLS, and deny direct API-role privileges
(including service role). Narrow explicitly granted RPCs are the only client
boundary; fail-closed defaults and the security event trigger remain intact.

| Table                                 | Responsibility                                                                                                           |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `community_groups`                    | Stable UUID, content, owner state, staff suppression, original actor UUID, server timestamps and positive bigint version |
| `community_group_managers`            | Current accountable personal authority; one manager per group in GRP01, several groups per person                        |
| `community_group_command_receipts`    | Immutable actor/key intent hash, destination and accepted version                                                        |
| `community_group_suppression_actions` | Append-only effective staff changes with private actor/time/reason/version                                               |

Authority is separate from immutable creation provenance so later reviewed
multi-manager support can preserve group IDs. No client command assigns another
manager, transfers authority, grants staff access, or hard-deletes content.

Content is a complete JSON object, replaced atomically by each save:

| Field                | Contract                                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `name`               | Required trimmed string, 0–120 characters in draft; at least 2 when published; not globally unique                        |
| `description`        | Required trimmed plain-text string, 0–4,000 characters in draft; at least 20 when published                               |
| `group_kind`         | Required exact `informal` or `organization`                                                                               |
| `locality`           | Optional string/null; trimmed blank becomes null; up to 120 characters; broad city/territory, manager-supplied, no lookup |
| `volunteering_focus` | Required boolean, independent of group kind/legal status                                                                  |

Unknown keys, null required fields and incorrect types fail. Name validation
reserves PLANETS, names containing Planets Community, and names combining PLANETS with
official/ufficial wording, ignoring ASCII punctuation/spacing/case. This bounded
platform-name guard does not certify other organizations or adjudicate every
impersonation claim. Free text remains subject to reporting/manual review.
GRP02 must label locality as broad territory and avoid inviting exact addresses
or personal contact details. No phone/email/representative/URL/exact-address,
logo, verification or legal-proof field exists.

Public projections explicitly allow only `group_id`, `name`, `description`,
`group_kind`, `locality`, `volunteering_focus`, `version`, `created_at`,
`updated_at`. Manager IDs, private reasons/reports/authority/receipts, members
and counts are absent.

The existing generated-type nullability registry corrects pg-meta's missing
RETURNS TABLE nullability for optional `locality` in all four public/owner reads.
Generated contracts are regenerated through `db:types`, never hand-edited.

## Actors and canonical operations

| Actor                                  | Authority                                                                    |
| -------------------------------------- | ---------------------------------------------------------------------------- |
| Guest / signed-in person               | Bounded public list and eligible exact detail                                |
| Auth account without completed Profile | Public reads only                                                            |
| Completed accountable manager          | Create/recover, own read/list, edit, publish/unpublish/archive               |
| Another completed person               | Public reads and genuine reports; no owner projection                        |
| Active completed moderator/admin       | Protected inspection and suppression; owner editing only if also the manager |
| Inactive staff                         | Ordinary-person access only                                                  |

Group commands use expected identity, canonical Profile completion (nonnull
display name constrained by the Profile domain) and actual Auth-account
existence. No personal photo is required. Existing Project/photo rules and
POLICY01B client acceptance gating are unchanged. Staff authorization reuses the
current active moderator/admin helper, rechecked after lock waits.

| RPC                               | Inputs / result                                                                                                                  |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `create_group_draft`              | expected profile, request UUID, content → stable group UUID; atomic initial authority                                            |
| `recover_group_command`           | expected profile, request UUID → zero/one `{group_id, accepted_version}`                                                         |
| `get_own_group`                   | expected profile, group UUID → editing projection with state/suppression/version                                                 |
| `list_own_groups`                 | expected profile, bounded page/paired cursor → own projections, including archived                                               |
| `update_group`                    | expected profile, group/request UUIDs, expected version, full content → accepted version                                         |
| `set_group_publication_state`     | expected profile, group/request UUIDs, expected version, exact state → accepted version                                          |
| `list_public_groups`              | combined filters, bounded page/paired cursor → public allowlist                                                                  |
| `get_public_group`                | group UUID → zero/one public allowlist                                                                                           |
| `set_group_directory_suppression` | expected staff, group/request UUIDs, expected version, boolean, trimmed private reason of 10–4,000 characters → accepted version |
| `get_group_staff_context`         | expected active staff, group UUID → content, authority/provenance, eligibility, latest private suppression action                |
| `get_moderation_case_group`       | expected active staff, group case UUID → staff context plus report-time version/content-changed flag                             |

## Lifecycle, versions and retry recovery

Creation starts at draft, version 1. Publication is explicit and requires a name
and purpose. Managers may unpublish to draft or archive; archive restores to
draft before editing/publishing. No automatic publication or staff approval
workflow exists. Suppression is independent: managers can edit/change owner
state while suppressed but cannot clear it; staff restore never publishes a
draft/archived page.

Public eligibility requires published, nonsuppressed, a complete current manager
Profile and an existing Auth identity. List/detail share this rule. Missing,
draft, archived, suppressed and orphan exact reads all return `[]`.

Edit/state/suppression commands require current version. Effective changes
increment it and update server time; no-op commands keep the version and add no
duplicate audit/action. Stale changes fail `PT409`. Group-row locks serialize
editing, lifecycle, suppression and report target capture. Actor/key advisory
locks serialize deliveries before receipt decisions; authority is rechecked
after waits, including retries.

Every command requires an account-bound request UUID. Preserve the UUID and
original intent across retries. One namespace covers all group commands: never
reuse a UUID for a different operation/target. Normalized content/trimmed reason,
operation, target and expected version are hashed. Same actor/key/intent returns
the original destination/version without replaying changes, even after later
edits. Changed intent fails `22023`; another actor has an independent namespace.

Recovery waits for in-flight work. Empty recovery means no currently authorized
owner receipt. Staff recover by repeating their exact suppression call. On lost
response, GRP02 recovers/retries then reloads current `get_own_group`. On `PT409`,
reload and let the person reconcile their draft; never silently overwrite by
automatically adopting a new version. Identity changes clear client pending
state. A receipt cannot restore lost authority.

## Discovery and errors

Order is immutable `(created_at DESC, group_id DESC)`. Page size defaults to 25,
must be 1–50. `p_before_created_at` and `p_before_id` must both be absent or both
present; timestamps must be finite. Use the last row as the next cursor; empty
pages terminate. Keep filters fixed while paging and restart when they change.

`p_search` is literal case-insensitive substring search over name + description,
up to 120 characters: percent, underscore and backslash are literal. Null/empty
search adds no text restriction. Kind accepts only the two defined values,
volunteering is an optional boolean, and locality is an exact case-insensitive
nonblank trimmed territory string up to 120 characters. Filters combine with
AND. Unsupported future values fail. There is no verified-only subset,
popularity algorithm or geocoder. Directory/filter and authority indexes are
present; substring search may scan eligible candidates. The rollback-only
query-plan fixture records representative plans without a scale promise.

Validation uses `22023` (malformed UUID/timestamps may fail earlier during typed
API parsing). Identity/authority/unavailable protected reads use `42501`;
canonical incomplete Profile and archived-transition failures use `55000`;
stale versions use `PT409`. Unknown future RPC arguments fail PostgREST
signature resolution rather than becoming unfiltered reads.

## Reporting and audit

Call existing `submit_moderation_report` with target kind `group`, canonical group
UUID and no incident context. A completed person may report another manager's
eligible public group. The server derives its accountable subject and captures
page version under lock. Existing category/free-text explanation, reporter
privacy, receipt/status, immutable case identity, staff notes/events and manual
review remain canonical. Group retry keys reject changed target/category/text/
context; exact retries recover after hiding. Reports never automatically hide
groups and never trigger Project corroboration or Resource counterstatements.
Other targets, including official templates without human subjects, are retained.

Mobile's exhaustive parser accepts `group` for own report history. Existing admin
generic queue/detail accepts genuine group targets/subjects; separate protected
RPCs supply group-specific inspection. GRP02 provides the public report entry
point and protected group staff UI integration.

Real creation, initial authority, loss of the manager reference, edits, lifecycle and suppression write
identifier-only audit events (actor/group UUIDs and version). Group events keep
the existing nullable `audit_events.actor_user_id` empty and preserve actor UUID
in metadata, avoiding its RESTRICT FK as a new erasure blocker. Descriptions,
reasons, report text and URLs never enter generic audit/outbox metadata. No
outbox, notification, Realtime or job is added.

## Account lifecycle and deferred work

Manager Profile references use `ON DELETE SET NULL`. Original, appointment,
receipt and suppression actors are immutable UUID provenance without account
FKs. Removing an otherwise unreferenced Profile/Auth identity preserves group
content/history but hides it and removes owner authority. Recreating an account/
Profile does not acquire null authority automatically. Loss of profile completion
also hides it until the same existing identity completes its Profile again.

Actual group reports preserve the existing moderation subject FK/retention
behavior. Existing profile, generic audit and report relationships have their
own constraints. GRP01 adds no unconditional erasure blocker from group
relationships, no erasure/suspension platform and no retention period; it does
not promise deletion of accounts with other domain/report references.

Membership/invitations, group-authored Projects with human provenance, ownership
transfer, logos/media, legal verification/evidence, ETS/provincial imports and
Project conversion remain deferred. Future logos require group-specific Storage
authorization; private personal photos and arbitrary image URLs/storage paths
are not trusted group media. Provincial Section B must not acquire an ETS badge.

## Validation and deployment

Use a confirmed disposable local stack. `group:upgrade:verify:local` resets to
the predecessor, seeds fictional existing domains, snapshots every existing
column/row, applies migrations twice and verifies preservation. It requires
`PLANETS_DISPOSABLE_QA=1` or CI. `MAILPIT_URL` must match the selected local stack.
Run pgTAP after clean reset and before HTTP verifiers populate data.

```text
npm run group:upgrade:verify:local
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run group:verify:local
npm run db:types
npm run test:tooling
```

Both group verifiers run explicitly in Database CI/full `check:db`. Existing
moderation/corroboration/counterstatement checks protect old dispatch. No phone
QA is required for this backend stage. Shared deployment remains separately
authorized normal migration application, API/type parity readback and smoke
checks; this task applies no hosted migration or client deployment.

### Local execution record (2026-10-11)

Validation used the isolated `planets-grp01-qa` stack (API 59521, database 59522,
mailbox 59524), the locked CLI `2.118.0-beta.39`, and fictional fixtures only.
The alternate project/ports were temporary local configuration, not committed.
Set `MAILPIT_URL=http://127.0.0.1:59524` for these recorded HTTP commands and
`PLANETS_DISPOSABLE_QA=1` for the upgrade command.

| Command                                                                                                                                                                                 | Observed result                                                                                                                                                                                                 |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run group:upgrade:verify:local`                                                                                                                                                    | Passed; all old rows/columns in 106 tables preserved after rebasing onto `b7ed9bf`, including populated Profiles, Projects, chat, policy receipts, reports and official templates; second application harmless. |
| `npm run db:reset`                                                                                                                                                                      | Passed full clean replay.                                                                                                                                                                                       |
| `npm run db:lint` / `npm run db:advisors`                                                                                                                                               | Passed, no reported issues.                                                                                                                                                                                     |
| `npm run db:test`                                                                                                                                                                       | Final integrated pass: 132 files / 4,463 assertions.                                                                                                                                                            |
| `npm run db:test -- supabase/tests/129_persistent_groups.test.sql`                                                                                                                      | Final focused pass: 202 assertions.                                                                                                                                                                             |
| `npm run group:verify:local`                                                                                                                                                            | Final pass: real Auth/PostgREST, 12 concurrent creates, competing edits, 8 concurrent reports, retries, grants, privacy, paging, owner/staff state and orphan deletion.                                         |
| `npm run moderation:verify:local`                                                                                                                                                       | Passed existing moderation and TW02 (93 API assertions).                                                                                                                                                        |
| `npm run moderation:corroboration:verify:local` / `npm run moderation:counterstatement:verify:local`                                                                                    | Passed existing evidence workflows.                                                                                                                                                                             |
| `npm run db:types` (twice)                                                                                                                                                              | Passed; identical generated file hash, optional group locality represented as nullable.                                                                                                                         |
| `npm run test:tooling`                                                                                                                                                                  | Passed 97 tests.                                                                                                                                                                                                |
| `npm run test --workspace @planets/web -- --reporter=verbose`                                                                                                                           | Passed 341 tests; two existing opt-in integration/browser tests skipped.                                                                                                                                        |
| `npm run lint --workspace @planets/web` / `npm run typecheck --workspace @planets/web` / `npm run build --workspace @planets/web` / `npm run invitation:check --workspace @planets/web` | Passed individually (the components of `check:web`).                                                                                                                                                            |
| `npm run check:site`                                                                                                                                                                    | Passed tests, lint, typecheck, build and deployment dry run; no deployment.                                                                                                                                     |
| `flutter pub get` / `flutter gen-l10n` / `flutter analyze` (in `apps/mobile`)                                                                                                           | Passed.                                                                                                                                                                                                         |
| `flutter test test/features/moderation/domain/moderation_models_test.dart`                                                                                                              | Passed all four focused tests.                                                                                                                                                                                  |
| `npm run format:check:mobile`                                                                                                                                                           | Passed.                                                                                                                                                                                                         |

Representative query plans are repeatable with
`scripts/fixtures/grp01-query-plan.sql` through local `psql` (the fixture rolls
back). With 1,000 fictional published groups, default directory ordering used
`community_groups_directory_idx` (0.189 ms); combined literal search, kind,
volunteering, locality and paired cursor used
`community_groups_locality_directory_idx` (0.393 ms). The single owner of all
1,000 fixtures used sequential scans/hash join and a top-N sort (0.664 ms);
the manager lookup index exists, but that unselective owner fixture did not use
it. These are local observations, not a production latency/scale guarantee.

The complete local `check:db` and full Flutter suite were not run; hosted
Database/Mobile CI must cover them before merge. There was no running Flutter
app for hot reload; no UI/phone qualification is claimed or required here.
Local Node was 24.13.0; CI uses the repository-pinned 24.20.0. A locked `npm ci`
reported 22 existing dependency advisories and engine warnings; dependencies
and lockfile were not changed. No legal verification, registry import, hosted
configuration, migration or external deployment was performed.
