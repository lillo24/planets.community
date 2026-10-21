import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../mock_mode/application/mock_mode_coordinator.dart';

abstract interface class ProjectInviteSharing {
  Future<void> copy(String value);
  Future<void> share(String value, {Rect? origin});
}

class PlatformProjectInviteSharing implements ProjectInviteSharing {
  const PlatformProjectInviteSharing();

  @override
  Future<void> copy(String value) =>
      Clipboard.setData(ClipboardData(text: value));

  @override
  Future<void> share(String value, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: value, sharePositionOrigin: origin),
    );
  }
}

final projectInviteSharingProvider = Provider<ProjectInviteSharing>((ref) {
  if (ref.watch(activeMockRealmProvider)) return const _UnavailableSharing();
  return const PlatformProjectInviteSharing();
});

class _UnavailableSharing implements ProjectInviteSharing {
  const _UnavailableSharing();
  @override
  Future<void> copy(String value) async =>
      throw StateError('External sharing is unavailable in Mock mode.');
  @override
  Future<void> share(String value, {Rect? origin}) async =>
      throw StateError('External sharing is unavailable in Mock mode.');
}
