import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../geographic_discovery/domain/public_map_camera.dart';
import '../../settings/application/activities_split_preference_controller.dart';

/// RAM-only rendered view; filters belong to ExternalActivitiesController.
class ExternalMapSession {
  final camera = PublicMapCamera();
  String? selectedIdentity;
}

final externalMapSessionProvider = Provider<ExternalMapSession>((ref) {
  ref.watch(authSessionProvider.select((s) => (s.phase, s.identity?.id)));
  ref.watch(activitiesSplitPreferenceProvider.select((s) => s.enabled));
  return ExternalMapSession();
}, dependencies: [activitiesSplitPreferenceProvider]);
