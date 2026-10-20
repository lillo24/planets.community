# Native host drivers

These files run on the development host while `flutter drive` runs a separate
integration target on an explicitly owned device. Targets own app/domain
assertions; drivers own artifact writing and their final exit status.

| File                                                            | Responsibility                                                                 |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `group_contact_screenshots.dart`                                | Representative/coordination PNGs and `build/group_contact_response_data.json`. |
| `member_contact_screenshots.dart`                               | Member-contact PNGs and `build/member_contact_response_data.json`.             |
| `contact_response_metadata.dart`                                | Shared contact result metadata without a second serialized copy of PNG bytes.  |
| `groups_screenshots.dart`, `batch_a_screenshots.dart`           | Existing Group and Batch A capture entry points.                               |
| `navigation_header_screenshots.dart`, `navigation_profile.dart` | Navigation captures and before/after profile evidence.                         |
| `tutorial_screenshots.dart`, `tutorial_visual_probe.dart`       | Tutorial captures and native visual-probe artifacts.                           |
| `map05_driver.dart`                                             | MAP05 captures in an explicitly selected evidence directory.                   |

Flutter's extended driver validates each screenshot callback before invoking its
response writer. Its default writer pretty-encodes the same image-byte arrays
again; the 40-frame member run exhausted the host heap there after all app
assertions passed. The contact callback retains names, byte counts, optional frame
arguments and all other response metadata. Original PNG callbacks and SDK pass/
fail checks are unchanged. Missing/malformed data fails explicitly; an early
failure before its first screenshot retains its original response metadata.

The pure helper is tested in `test/test_driver/contact_response_metadata_test.dart`,
including a large byte list that throws if reporting reads or serializes its
contents. PNGs and metadata complement one another; neither replaces a successful
complete driver exit and visual inspection. Fixture-bearing APKs and defines
remain private.

See [D native QA](../../../docs/development/group-contact-mobile.md) and
[M native QA](../../../docs/development/member-contact-mobile-native.md) for
resource ownership, fresh fixtures and qualification requirements.
