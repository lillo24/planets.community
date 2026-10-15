# D-R02 — Finish and qualify multi-group representative coordination

## Objective

Reuse existing D03 and complete its policy/implementation/native qualification. This is not a general channel/group-chat creation feature and does not inherit C's conversion or room history rules.

## Required invariants

Only correctly authorized human representatives may propose/join the approved collaboration audience. Ordinary members cannot claim a Group seat; no manager may consent on behalf of another human. Identify who represents which Group. Revalidate the current grant and actual group context after lock waits; Project publication provenance is not current representation.

Adding an external Group changes the private audience. Follow the exact disclosure and old-history decision resolved in D-R00. The existing conservative prototype uses a **fresh** conversation and a newly authored summary, not copied bilateral/C history; all selected humans confirm the exact audience version. Keep that a review candidate until approved, rather than saying C's “full earlier history” authorizes its opposite here.

If the exact-version model is approved, seat changes, substitutions, regrant, expired proposals or altered participants invalidate stale confirmations. Final activation is one transaction/receipt and creates only the agreed admissions. No partial consent can open body/roster/history. Bound seat/request counts and pages; no unlimited nested chat builders or recursive coordination proposals.

## History, links and independent domains

Do not copy earlier bilateral messages, Group Idea messages, private draft/workspace links, read states, report bodies or implied endorsements to newly added representatives. Source links/IDs/titles are visible only after independent source authorization. New room authorization is separate from original bilateral and Group/Project memberships; exit from one does not accidentally create or revive the other.

Role loss/replacement/leave/close/Block/group lifecycle follow the approved D contract, including how still-entitled peers read history. Do not silently choose C's read-only former access or old D's complete former denial. A manager's **Idea oversight** never admits them to this coordination room. Safe decline/leave/report cannot be trapped behind a lost content grant.

## Known evidence gap to repair

The last #254 report had partial real native interaction but no complete final native test result; driver loss and loading-only audience captures were not qualified. Reproduce with an owned emulator/backend and stable harness. Repair observable lifecycle/driver issues without weakening the audience checks or claiming a screenshot means acceptance occurred. Record injected fixtures and final source SHA.

Complete one full path with at least three synthetic Groups: bilateral request/accept, add third Group, claims/review/consent, declined or changed audience, lost final reply and recovery, resulting empty/fresh history, real send, private source denial, role loss/regrant, report/block and exit. Capture final EN/IT small-screen audience/composer/denied states after loads finish.

## Deliverables and gates

Retained/revised D03 code and types; decision-reference ledger; real-Auth/SQL race and populated-upgrade evidence; complete final-source native result; updated exact-message/report/notification compatibility docs. If audience/history approval is still missing, keep this dependent scope isolated and review-only while independent work continues. Tests cannot turn provisional policy into approval.
