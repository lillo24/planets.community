# UIPOLISH03: detail sections, Groups and Resource chat

This pass follows UIPOLISH02 main `94af1c2eb707446baf7b7e027dff6ea997c9813e`.
Before PR delivery it rebased onto MAPUI03 main
`15a378b8fdc207d521db4503f6570b3dfc72b70f`, retaining its independent city fallback
and map attribution changes. All 148 affected tests passed again after rebase.
It changes Flutter presentation. No migration, provider/controller contract,
agreement lifecycle, navigation shell, release or Drafts loading repair belongs
to this pass.

## Presentation boundaries

Project details use a short calendar/skills/material heading, UIPOLISH01's
canonical event-zone schedule, and UIPOLISH02's skill display resolver. The
calendar is supplied once by the heading (`EventSchedule.showIcon: false`);
other callers keep the default icon. Skills retain complete labels under
Required/Useful groups. The authoring explanations remain unchanged; only the
detail screen uses the short hints. Each public material renders its title once,
followed by its complete optional description, including safety text and links.

The short resource Manage action stays in its material section, below the
heading to accommodate long translations and 2x text. The exact existing
`identity.id == creatorProfileId` guard and `ProjectResourceNeedRoutes.manage`
destination remain. Co-creator authority does not grant creator-only resources.
Shared resource loading/retry, optional heading/empty behavior and tutorial keys
remain. An otherwise empty owner section still exposes its local Manage action.
Deferred participation reads now check that their lazy detail context is still
mounted: scrolling through the new section heights reproduced an unsafe deferred
`ref.read` after the participation widget had left the viewport. This guard does
not change role, meeting visibility or participation rules.

Groups keep a short search label (with its complete name/description scope in
semantics) visible and disclose kind, volunteering and territory through
the shared Filters control. Disclosure retains selections and issues no request.
The existing 350ms debounce, canonical whitespace normalization, exact territory
matching, validation, sorting, cursors and deliberate-scroll paging remain.
Reset is offered for entered values; active-filter indication reflects effective
query values. A debounce is shown as pending, never as a successful empty page.
Successful public unfiltered, filtered and own empty results have distinct copy.
Create is primary, My groups secondary; pull-to-refresh and an accessible app-bar
Refresh remain. Public and own RPC scopes are unchanged.

Resource chat keeps its existing message controller, lazy center slivers,
read-boundary viewport, paging, subscriptions and text controller. A compact
full-width agreement summary retains the canonical status and primary action;
History and eligible cancellation move to a labelled menu. Milestone progress
stays visible with its existing event-history disable rule. Warnings retain their
timeline/failure/refresh precedence and safe messages in `ResourceExchangeFeedback`
above the summary. New failures return only the summary scroll to its start.
They never move message history or discard a composer draft.

Summary and composer use scrollable maximum shares of the available body height
(45% each), leaving an independently scrollable message viewport even with a
short landscape or keyboard constraint. These are maximums, so normal content
uses its natural height. No text scale is reduced. Scaffold resizes for the IME
and removes the body's keyboard inset. Composer padding is constant and no
longer redundantly consults that inset.
The authorized counterpart name is primary, role secondary, with the complete
long name in its tooltip/semantics. Block/report identity and capabilities remain.
Empty chat has a small icon and the existing genuine-empty guidance.

## Reproduction

From `apps/mobile`, use the repository-pinned Flutter SDK:

```text
flutter test --concurrency=1 test/features/proposals/presentation/uipolish03_details_groups_chat_test.dart test/features/groups test/features/project_resource_needs/presentation test/features/messages/presentation/messages_flow_test.dart test/features/resource_chat test/features/resource_exchange test/features/participation/presentation test/features/proposals/presentation/proposal_needs_screen_test.dart test/core/widgets/event_schedule_test.dart
```

For each native phase, start the capture helper in one PowerShell terminal, then
the drive command in another (use a fresh log). Both terminals use the same log
and phase; the before drive runs in exported main with the copied fixture.

```powershell
# Terminal 1; change before to after for the implementation run.
./integration_test/uipolish03_capture.ps1 -AdbPath "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" -LogPath "$env:TEMP/uipolish03-before.log" -OutputDirectory "$env:TEMP/planets-uipolish-runtime" -Phase before
# Terminal 2; omit UIPOLISH_BEFORE for the implementation run and use its after log.
flutter drive -d emulator-5584 --disable-dds --host-vmservice-port=62023 --driver integration_test/uipolish01_driver.dart --target integration_test/uipolish03_smoke_test.dart --dart-define=UIPOLISH_BEFORE=true *> "$env:TEMP/uipolish03-before.log"
```

`test_support/uipolish03_fixture.dart` supplies synthetic identities and replaces
every accessed data boundary with a fake. Native before runs use exported main
with the same harness and optional-name fake extension; production source stays
unchanged. Baseline-only RenderFlex overflow diagnostics are explicitly recorded
and reported; all other exceptions fail. After runs use the normal strict error
handler. Each phase captures 14 Italian frames: 360px/light/1x and 320px/dark/2x,
plus 720x412 logical landscape and the native IME-open viewport at 1x.
Native 2x IME and landscape remain unverified: opening the IME or resizing the
surface repeatedly terminated the task-owned emulator, including with direct
ADB capture. The widget matrix validates those 2x constraints instead. The task-owned
AVD enables `show_ime_with_hard_keyboard=1`; the harness explicitly waits for a
nonzero native view inset before its keyboard capture and zero before landscape.
Landscape changes the Flutter logical surface to 720x412 while the emulator stays
in portrait; physical Android rotation is not validated by this harness.
Portrait scenes use the device's actual logical height, retaining narrow-width
letterboxing without rescaling native keyboard insets against a taller surface.
The task-owned API 36 AVD uses 2048MB, headless SwiftShader, a 720x1280 display
override at density 240, and disabled system animations. Launch it with
`-avd PLANETS_UIPOLISH_QA -port 5584 -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader -memory 2048`.
Wait for `sys.boot_completed=1` and an unobscured app window: a focus-stealing OS
dialog fails the native IME assertion and is not counted as app validation.
The ADB collector writes `%TEMP%/planets-uipolish-runtime`, includes the real IME,
and acknowledges each frame through the debug app's private temporary directory.
It validates the task AVD and app foreground before every capture. It avoids the
ImageReader screenshot path; neither capture method resolved the emulator's
2x IME/surface-resize exit, so those native steps are explicitly excluded. It does not suppress app
errors. Native build processes
use `GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2` to bound
host memory without changing checked-in build settings.

The widget matrix also covers EN/IT, both themes, 320/360/412px, 1x/2x, owner,
non-owner and Co-creator, material failure/retry, Groups loading/error/empty,
exact filters and request counts, both chat roles and all canonical agreement
stages, read-only history, long names/history, deliberate paging, read boundaries,
draft retention and failures. Existing message-flow assertions now open the
secondary menu and assert name/role separately, reflecting the requested layout;
their authorization, mutation and lifecycle expectations remain.
Existing Project-detail tests now expect short hints and separate importance
groups instead of the removed explanatory paragraphs/prefixed labels. The Tavolo
date test settles its lazy section between scroll targets and retains both date
and restricted-location assertions. The long-history probe uses repeated genuine
drags to reach the paging threshold rather than assuming one fixed drag distance.

Run `npm run check:mobile` from the repository root for complete mobile
formatting, analysis and tests. No real account/session, shared database reset,
production deployment or store/release build is exercised by synthetic QA.
Physical Android and iOS checks are separate and have not been run.

## Validation record

The local full mobile command passed formatting (700 files) and static analysis,
then reported 3,481 passing tests, two skipped and seven failures. Those failures
were the superseded detail-copy assertions, insufficient history-test scrolling
and an unsettled lazy Tavolo section. After their fixes, the complete affected
four-file rerun passed all 148 tests:

```text
flutter test --no-pub --concurrency=1 test/features/proposals/presentation/proposal_flow_test.dart test/features/proposals/presentation/uipolish03_details_groups_chat_test.dart test/features/messages/presentation/messages_flow_test.dart test/features/recurring_activities/presentation/recurring_activity_flow_test.dart
```

The first full local command is not recorded as passing. Final static analysis
passed with no issues. The PR's fresh full mobile CI gate is required before merge.

## Synthetic visual evidence

The final native baseline passed both scenarios and teardown, collecting all 14
frames with zero recorded RenderFlex warnings. Earlier interrupted runs are
superseded by this bounded harness; the separate native 2x IME/landscape limitation
remains explicit above. The evidence uses fictional identities and
`example.invalid` content. Black margins are the test surface's letterboxing;
the images are direct Android compositor captures. The baseline uses UIPOLISH02
main; the after build also includes the subsequently merged MAPUI03 city fallback.
The strict after run also passed both scenarios and teardown with all 14 captures.
Visual inspection confirms a separate message viewport, an unobscured native-IME
composer/send action, complete safety text, and compact default Groups controls.

| Scene                                | Before                                                                       | After                                                                      |
| ------------------------------------ | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Project skills, 320px / 2x           | [Before](evidence/uipolish03/uipolish03-before-320-2x-project-skills.png)    | [After](evidence/uipolish03/uipolish03-after-320-2x-project-skills.png)    |
| Complete material, 320px / 2x        | [Before](evidence/uipolish03/uipolish03-before-320-2x-project-materials.png) | [After](evidence/uipolish03/uipolish03-after-320-2x-project-materials.png) |
| Groups default, 320px / 2x           | [Before](evidence/uipolish03/uipolish03-before-320-2x-groups-default.png)    | [After](evidence/uipolish03/uipolish03-after-320-2x-groups-default.png)    |
| Groups filters, 320px / 2x           | [Before](evidence/uipolish03/uipolish03-before-320-2x-groups-filters.png)    | [After](evidence/uipolish03/uipolish03-after-320-2x-groups-filters.png)    |
| Groups empty, 320px / 2x             | [Before](evidence/uipolish03/uipolish03-before-320-2x-groups-empty.png)      | [After](evidence/uipolish03/uipolish03-after-320-2x-groups-empty.png)      |
| Chat agreement, 320px / 2x           | [Before](evidence/uipolish03/uipolish03-before-320-2x-chat-agreement.png)    | [After](evidence/uipolish03/uipolish03-after-320-2x-chat-agreement.png)    |
| Chat native keyboard, 360px / 1x     | [Before](evidence/uipolish03/uipolish03-before-360-1x-chat-keyboard.png)     | [After](evidence/uipolish03/uipolish03-after-360-1x-chat-keyboard.png)     |
| Chat logical landscape, 720x412 / 1x | [Before](evidence/uipolish03/uipolish03-before-360-1x-chat-landscape.png)    | [After](evidence/uipolish03/uipolish03-after-360-1x-chat-landscape.png)    |

The same directory also holds the six 360px / 1x portrait scene pairs.
