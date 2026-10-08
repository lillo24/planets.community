# Public Help

Home's question-mark opens `/help` for guests and every account readiness state.
The routes live in the central app router; direct entry has a safe Home/Help Back.

- `presentation/help_screen.dart` owns the four choices, creator contact and honest
  contextual person-report guidance. It performs no moderation lookups or writes.
- `presentation/help_routes.dart` owns public route names.
- `presentation/bug_report_screen.dart` owns a reviewable, memory-only technical
  bug draft. Only entered description/steps/expected outcome appear in email/copy.
  Leaving the screen discards it; external composer return retains it. Identity or
  session phase changes clear it and invalidate pending callbacks. Token refresh
  with the same ready identity retains it. Clipboard copying is explicit.
- `presentation/support_mail_action.dart` owns the external handoff and honest
  unavailable/opened status. Opening a composer is never proof of sending; users
  choose Send or Cancel in their mail app, and neither outcome is observable here.
- `application/support_mail.dart` owns the injectable mail launcher, safe mailto
  encoding and nullable public destination. The default mailbox is
  `developer.planets.community@gmail.com`, already founder-approved and public in
  `apps/site/src/site-content.ts`. Keep both public configurations aligned if the
  address changes. Null/invalid configuration displays unavailable support while
  bug review/copy remains usable. No provider secret or backend resource is needed.

Tutorial replay uses `TutorialRoutes.replay(context, returnTo: HelpRoutes.path)`.
Finish/Skip/Back return to Help without altering first-run completion/dismissal.
The existing contextual moderation forms and eligibility remain their own feature.
