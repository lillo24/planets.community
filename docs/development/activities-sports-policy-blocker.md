# Activities/Sports source-policy resolution and hosted hold

The source blocker introduced by [STAGING-AUTO03 #306](https://github.com/lillo24/planets.community/pull/306)
was resolved through the **separate, independently validated policy prerequisite
[#310](https://github.com/lillo24/planets.community/pull/310)**, merged at
`34649049db675b1b436e6a0ce0aefefaf4a0a4a0`. All five required checks passed in
[Validation 39967502645](https://github.com/lillo24/planets.community/actions/runs/39967502645).
The cumulative feature implementation stays in [#298](https://github.com/lillo24/planets.community/pull/298),
which includes that merged main and supplies its own final CI/merge record.

The original source rejection at trusted base `52e301bb` was 005 line 2:

```sql
drop index private.external_activity_one_enabled_source;
```

ACTSRC02 deliberately retires the MVP's one-enabled-source restriction. It
deletes no catalogue rows and retains independent source rights/publication,
private RLS, source/upstream identity, V1 compatibility and leased atomic imports.
Generic `DROP` remains source-blocking. Only canonical version `20261023093757`,
file `20261023093757_external_activity_multi_source.sql`, SHA-256
`0fec4437bf512a14c6218c3f7e7bc3b810c5414dcc44d8d2c2db72010b742fd6`
selects the new **source-only** contract. The pin alone is insufficient: actual
catalog proof must find the unique btree `(enabled) WHERE enabled` index on the
expected private table, retain all other indexes/constraints and identity keys,
and preserve raw-role denials, owners, column grants, RLS and populated rows.
Wrong predecessors or unrelated contract loss remain fatal.

Independent real PostgreSQL controls passed three wrong definitions, unrelated
index loss, grant widening and RLS-disable denials. Distinct source/upstream IDs
and per-source lease fences survive; all original catalog/rows match after
rollback. Policy-only local tooling: 258 PASS; focused: 72 PASS. The independently
verified CI ZIP digest is
`7bd2ff912bbbd0c19543e976c36df908e4cc385a0c46ceb10f2538acfd08a82b`, artifact
`12508515489`: exact reviewed tree, 123→143 migrations, 200 original tables /
1,394 rows, 20 per-file inventory/preservation/effect witnesses, Auth, Storage,
types, no-op retry, writer/startup and negative controls passed.

**Hosted application remains withheld.** This migration's witness is forced to
`review-required-for-hosted`; the hosted authorizer separately rejects the exact
pending migration even if a witness incorrectly promotes it. Other required
hosted contracts remain:

- 002: new direct client projection grants.
- 005: importer/source configuration and other privileged effects beyond the
  narrowly reviewed index retirement.
- 007: existing-table/geographic effects.
- 010: existing-table index and operations effects.

These source-valid holds withhold the whole hosted chain. Owner fingerprint
comments are historical technical audit under the current policy, never an
authorization bypass. No policy/validator/dependency changes occur in the feature
PR, no published migration was rewritten, and no hosted schema/configuration,
source, scheduler or deployment was changed to resolve the source rejection.

See [progress and qualification](activities-sports-progress.md) for actual-main
143→147 preservation, 176 pgTAP files / 8,503 assertions, 287 tooling tests,
mobile/Android, rendered and actual 116-record municipal evidence. Phone review,
release signing/configuration, ODH coverage and guarded checkout cleanup remain
independent limits, with precise next actions in the progress/runbook.
