# NAVUI01 native evidence

Captured on 2026-10-09 from implementation `ea8862746bd933c0d03c98dde568816b942bac0c`,
based on main `19465e1d87412cdc4fc50ec85e87a846bed94e23`.

Task-owned Android API 35 Google APIs x86_64 emulator
`PLANETS_NAVUI01_TUT05_QA_API35`, 720x1600 at 280dpi, Flutter 3.47.2 debug build.
The actual app/router/widgets use deterministic fake gateways and a synthetic OTP
identity. No hosted database, real messages, email delivery or founder app state
was accessed.

The native `navigation_header_smoke_test.dart` passed (one journey plus teardown),
with driver exit 0. It verified root Home/Projects without arrows, Project detail
textual Close, actual Android KEYCODE_BACK on detail and Messages Requests, Chats
return with the scope toggle retained, nested Help Close, OTP Use a different
email and Auth Close. The host log listener filters the running probe PID and
responds only to its explicit Back checkpoints. Screenshots are illustrative UI
proof, not performance measurements or authenticated backend evidence.

- [Home](home.png)
- [Projects](projects.png)
- [Project detail](detail-close.png)
- [Requests / Chats return](requests-chats.png)
- [Nested Help](help-contact.png)
- [OTP](otp-close.png)

`npm run check:mobile` passed: localization, format, analysis, **1,960 tests**
and two existing skipped tests. This includes the full source header inventory,
Android/iOS-themed guarded exit tests, EN/IT 320dp/200% actions, editor departure,
OTP retry/session preservation, policy, invitations, crop, chat/request return,
account changes and Help/tutorial replay. Earlier failed layout/finder runs were
corrected before this complete passing run; they are not counted as passes.

Native iOS swipe/VoiceOver and physical Android accessibility/device QA were not
run (no connected physical device/iOS host). iOS-themed widget tests do not
establish native gesture behavior. The on-screen textual exits are independently
available. No unresolved navigation exception needs founder review.

Reproduction commands and inventory: [navigation headers](../../navigation-headers.md).
