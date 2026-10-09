# Mobile page headers (NAVUI01)

`core/widgets/page_app_bar.dart` is the shared arrow-free header. It disables
Flutter's implied leading control and preserves the supplied title and actions.
Pushed pages imply a localized textual Close, using `Navigator.maybePop` so the
existing PopScope/router onExit departure guards still decide whether to leave.
Branch roots keep their bottom navigation without an extra Close. At less than
480dp and text scaling above 20px for a 14px font, textual actions wrap in a reserved
112dp area below the title when multiple actions need room. Single Close and
icon-only bars keep the ordinary height; semantics and touch targets are retained.

Flow-owned exits override the implied callback:

| Surface | On-screen exit and existing behavior |
| --- | --- |
| Messages Requests | Chats text action returns to the retained scope; system Back consumes Requests first |
| Auth request / OTP | Close cancels the same Auth continuation; OTP keeps Use a different email and system Back; a verified profile-retry state has a textual Back with the original callback and no sign-out |
| Profile setup/edit | Cancel calls the original pop-or-cancel destination; Save stays separate |
| Help/contact/bug/person and policy/account pages | Close retains HelpScaffold's supplied callback or pop/fallback destination |
| Project organizer / participant invitations and unavailable link | Close pops a retained stack or returns Home on direct entry |
| Proposal scratch/edit | Close runs the same router-owned single draft departure coordinator as system Back |
| Tavolo / Resource editors, reports, joins, chats and other nested pages | Close uses the existing guarded route pop |
| Cover / profile-photo crop | Existing footer Cancel/Apply remains; no duplicate header exit |
| Tutorial custom registry | Close uses its original cancellation callback; bottom Previous stays |
| Interactive tutorial | Embedded page headers suppress implied Close via PageAppBarScope; Previous/Next/Skip own the flow |

This does not change route definitions, transitions, admission, policy acceptance,
Auth state, editor persistence or native-link authorization. A Material page's
platform swipe behavior is unchanged; the textual exits are available independently
of an iOS swipe. Native iOS gesture validation requires an iOS device/host.

## Inventory

All 65 former AppBar call sites in 54 files were converted; there were no SliverAppBars or Cupertino page headers.

- `app/foundation_screen.dart` (1)
- `app/router/app_router.dart` (1)
- `app/startup/tutorial_pages.dart` (1)
- `app/startup/tutorial_presentation.dart` (1)
- `app/startup/tutorial_screen.dart` (1)
- `features/auth/presentation/request_code_screen.dart` (1)
- `features/auth/presentation/verify_code_screen.dart` (1)
- `features/blocking/presentation/blocked_users_screen.dart` (1)
- `features/cover_media/presentation/cover_crop_view.dart` (1)
- `features/drafts/presentation/drafts_screen.dart` (1)
- `features/geographic_discovery/presentation/map_discovery_screen.dart` (1)
- `features/help/presentation/help_screen.dart` (1)
- `features/messages/presentation/messages_navigation.dart` (1)
- `features/messages/presentation/participation_request_message_screen.dart` (1)
- `features/moderation/presentation/corroboration_screens.dart` (2)
- `features/moderation/presentation/counterstatement_screen.dart` (1)
- `features/moderation/presentation/moderation_evidence_requests_screen.dart` (1)
- `features/moderation/presentation/own_reports_screen.dart` (1)
- `features/moderation/presentation/report_form_screen.dart` (1)
- `features/notifications/presentation/notifications_screen.dart` (1)
- `features/notifications/presentation/notification_preferences_screen.dart` (1)
- `features/participation/presentation/creator_participation_screen.dart` (2)
- `features/participation/presentation/join_request_screen.dart` (1)
- `features/profile/presentation/profile_edit_screen.dart` (2)
- `features/profile/presentation/profile_screen.dart` (2)
- `features/profile_photo/presentation/profile_photo_crop_view.dart` (1)
- `features/project_chat/presentation/project_chat_info_screen.dart` (1)
- `features/project_chat/presentation/project_chat_screen.dart` (1)
- `features/project_delegates/presentation/project_coorganizers_screen.dart` (1)
- `features/project_delegates/presentation/project_invite_screen.dart` (1)
- `features/project_delegates/presentation/project_manage_screen.dart` (1)
- `features/project_participant_invites/presentation/participant_invite_screen.dart` (1)
- `features/project_participant_invites/presentation/participant_link_management_screen.dart` (1)
- `features/project_request_chat/presentation/project_request_chat_screen.dart` (1)
- `features/project_resource_needs/presentation/project_resource_matches_screen.dart` (1)
- `features/project_resource_needs/presentation/project_resource_needs_screen.dart` (1)
- `features/project_workspace/presentation/project_workspace_screen.dart` (1)
- `features/proposals/presentation/own_proposals_screen.dart` (1)
- `features/proposals/presentation/proposal_creation_choice.dart` (1)
- `features/proposals/presentation/proposal_editor_screen.dart` (1)
- `features/proposals/presentation/public_proposals_screen.dart` (2)
- `features/recurring_activities/presentation/own_recurring_activities_screen.dart` (1)
- `features/recurring_activities/presentation/public_recurring_activities_screen.dart` (4)
- `features/recurring_activities/presentation/recurring_activity_editor_screen.dart` (1)
- `features/resource_chat/presentation/resource_chat_screen.dart` (1)
- `features/resource_listings/presentation/own_resource_listings_screen.dart` (1)
- `features/resource_listings/presentation/public_resource_listings_screen.dart` (2)
- `features/resource_listings/presentation/resource_listing_editor_screen.dart` (1)
- `features/resource_loans/presentation/resource_loan_schedule_screen.dart` (1)
- `features/resource_requests/presentation/resource_request_screen.dart` (1)
- `features/resource_saved_searches/presentation/resource_saved_searches_screen.dart` (1)
- `features/settings/presentation/navigation_selection_screen.dart` (1)
- `features/settings/presentation/settings_screen.dart` (2)
- `features/template_workshop/presentation/template_workshop_screens.dart` (2)

`test/core/widgets/page_app_bar_test.dart` checks the complete source inventory,
localized Close/guard behavior with Android and iOS themes, embedded previews,
and action layout/taps at 320dp and 200% text. Existing navigation, OTP, account
switch, policy, modal crop, participation and draft tests exercise the original
flow contracts; arrow-based test taps now use the textual action's stable key.

The opt-in native probe uses real Flutter routes/widgets with deterministic fake
gateways, not hosted accounts:

```powershell
$env:PLANETS_QA_ANDROID_SERIAL='emulator-5586'
flutter drive --no-dds --driver=test_driver/navigation_header_screenshots.dart --target=integration_test/navigation_header_smoke_test.dart -d $env:PLANETS_QA_ANDROID_SERIAL
```

The host driver listens to live, process-bound checkpoints and sends actual
Android KEYCODE_BACK for the two system-Back checkpoints. It saves PNGs to `build/navigation-header-screenshots`.
Run only on a task-owned emulator; the probe never contacts a real backend.
See [native evidence](evidence/navui01/README.md) for the recorded run and limits.
