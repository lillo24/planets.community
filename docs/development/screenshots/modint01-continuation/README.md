# MODINT01 continuation evidence

Actual synthetic local-app captures, not previews or physical-device evidence.
The [review packet](../../modint01-moderation-auth-integration-review.md) owns
case-level results, failed attempts, CI and remaining checks. No OTP, bearer URL,
privileged key or private-note body is included. Staff screenshots with private
notes in frame were withheld and retained outside Git, not redacted into false
proof of completed controls.

## Normal browser, October 6

Production Next runtime built from `b928e77f02e74109a2fd7ceaeb5ded54c5ff942c`;
Web/production backend trees are identical at tested source
`c4f5c6ad7bc10d946dfad0a108f63574f5a48f47`. Normal OTP/profile/Join controls use
the owned backend on 54611 and Mailpit 54614, not an injected browser session.
Captures exclude browser chrome/bearer links.

- `browser-participant-joined.jpg`: token-free participation confirmation,
  explicit read-only refresh and configured public fallback. No OS association
  or store-download pass is claimed.
- `browser-suspended-account.jpg`: Web's denied account setup for a valid
  suspended session. It is not the Mobile suspension screen.
- `browser-ordinary-private-denied.jpg`: ordinary account's private staff route
  is Page unavailable.
- `browser-hidden-preview.jpg`, `browser-elapsed-preview.jpg`,
  `browser-revoked-preview.jpg`, `browser-unknown-preview.jpg`: generic unavailable
  invitation states. Hidden rendered DOM separately excludes title/Project ID;
  elapsed means the canonical one-time Project end-time boundary, not token TTL.

## Partial native replay, October 6

All 16 files in `native/` were captured by failed device attempt 6 from
`59299bc7ff0ae2ee0c81b4cc5424c609ab8f0abf`, using that attempt's matching fresh
defines/APK on the owned API 35 AVD. Production Mobile/backend trees are identical
at corrected tested source `c4f5c6a`; that source additionally corrects C's
Settings exit→Home entry. The failure after C's setup is not concealed.

- `authqa01-normal-home-{en,it}.png`: actual ready Home.
- `modint01-safety-{active,removed}-{en,it}.png`,
  `modint01-interaction_restriction-{active,removed}-{en,it}.png`,
  `modint01-content_hide-{active,removed}-{en,it}.png`: actual own type/history
  cards, synthetic reasons shown verbatim; longer cards retain scroll framing.
- `modint01-personal-pair-en.png`: actual pair screen after canonical send/feed
  assertion. Its visible live-updates-unavailable banner is not a healthy socket
  delivery claim or resolution of the historical Realtime issue.
- `modint01-template-private-copy-en.png`: photo-free canonical private copy
  opened in the normal editor.

Missing: full corrected OTP and request driver passes, EN/IT active/removed
suspension and both Project/Resource request-form explanation captures. The fresh
October 7 compiled OTP APK is unused; it supplies no additional screenshot pass.
Founder wording/presentation review, accessibility and physical-device/iOS checks
remain separate.
