# MODINT01 final restriction-copy widget review

These two PNGs are **synthetic widget-harness previews**, not native-device,
real-OTP, real-backend, browser-flow or founder-approval evidence.

Captured from the corrective runtime/localization source committed as
`ce942c10c316f7ea4754bf2a37cbbeb19ecfb809`; later documentation-only publication
does not change their pixels or runtime provenance.

- `restriction-copy-en-widget-preview.png`: corrected English private notice.
- `restriction-copy-it-widget-preview.png`: corrected Italian private notice.

The existing `OwnConsequencesBody` renders one active interaction-restriction
fixture with current generated localization and `AppTheme.light`, at 360×900
and normal text scale. The local Flutter SDK's Roboto/MaterialIcons fonts make
text readable; its debug banner is disabled only in the isolated harness.
The entire corrected effect sentence is in frame. Both renders passed bounds
and exception checks, and were visually inspected. There is no Auth session,
gateway or network/backend setup. The temporary capture harness/logs remain
local-only, not production/test dependencies or application controls.

Only the canonical `noticesRestrictionEffect` EN/IT values changed, exactly as
proposed in `PLANETS_MODINT01_final_copy_correction_PR154.md`. No other moderation
wording or domain rule changed. Exact source/CI/publication records are in the
[review packet](../../modint01-moderation-auth-integration-review.md) and PR #154.

The previous [28 actual MODINT01 captures](../modint01-continuation/README.md)
keep their historical source/run provenance and pre-correction text. They are
not replaced or relabelled as new live QA. The required Android/browser campaigns
are complete; founder wording/presentation approval remains pending. Existing
large-text/scroll/reduced-height tests are separately recorded in the packet;
these normal-scale previews do not prove physical-device or accessibility QA.
