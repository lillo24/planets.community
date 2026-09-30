import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
  return const PlatformProjectInviteSharing();
});
