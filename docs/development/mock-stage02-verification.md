> Historical MOCK02 evidence: superseded access policy. These passes do not qualify the open-access correction.

# MOCK02 stage qualification

This draft stage is stacked on MOCK01 commit
`51974ce38e973655a54a52338fb763482dd09853`. Its minimal real-session picker is
the interface completed in MOCK03; this is not a deployed feature claim.

- Focused existing/new mobile suite: **789 passed** (Settings, bootstrap, Auth,
  router, Profile/media, Messages, C/D/M, discussions and workspace recovery).
- Subsequent focused configuration/session/persistence/UI/journal suite:
  **61 passed**. These overlap the first run and must not be added together.
- `flutter analyze --no-pub`: **no issues** after the final source fixes.
- Node boundary/runtime tests: **9 passed**.
- Four component PNGs captured with the SDK's real Roboto/Material fonts:
  EN/IT, light/dark, 320dp, 2x text. Inspected IT light and EN dark; no overflow.
  These are widget renders, not native or hosted evidence. The external evidence
  directory is `C:/Users/leona/Documents/Codex/mock-qualification-evidence/mock02`.

Earlier development runs caught an incorrect storage-error classification and
a test's incorrect English substring assumption. The implementation now reports
storage failure explicitly; the test checks the actual localized unavailable
copy. No semantic product assertion was weakened. The new focused suite was
rerun successfully after these repairs.

Session cancellation review also added a bounded server tombstone when retire
overtakes an as-yet-unclaimed issue. The two-realm qualifier now tests that a
delayed issue cannot revive the cancelled request. This control source update
must pass genuine backend CI and is not yet installed on the disabled hosted
mock. Retired tombstones follow the existing seven-day maintenance retention.

The MOCK01 head separately passed all Validation jobs (Database, Web, Site,
Mobile), run `39595694099`, and the genuine two-realm qualifier at its preceding
runtime-equal head (`39595113413`: 9 unit tests and 144 real checks). Those
results do not qualify the changed MOCK02 source; its own draft CI and the final
cumulative MOCK03 gate supply that evidence.

Native release-mode, full final-source mobile/web/database, artifact scans and
the complete account selector remain MOCK03 gates. Hosted Auth settings, secrets,
approved issuer/UUID tester roster, seed/media and hosted smoke remain pending;
ordinary staging and the protected physical device were not modified.
