import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../domain/map_discovery.dart';

class MapDiscoverySessions {
  final _sessions = <MapDiscoveryOrigin, MapDiscoveryPreferences>{};
  MapDiscoveryPreferences forOrigin(MapDiscoveryOrigin origin) =>
      _sessions.putIfAbsent(origin, () => MapDiscoveryPreferences(origin));
  void clear() => _sessions.clear();
}

// Preferences survive List/Map/detail navigation, never an identity/ABA change.
// Public rows remain exclusively in MAP04's active-route controller.
final mapDiscoverySessionsProvider = Provider<MapDiscoverySessions>((ref) {
  final sessions = MapDiscoverySessions();
  ref.listen(
    authSessionProvider.select((s) => (s.phase, s.identity?.id)),
    (_, _) => sessions.clear(),
  );
  return sessions;
});
