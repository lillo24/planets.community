import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// The single runtime gate for all demo-only mobile presentation helpers.
final demoToolsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).demoToolsEnabled,
);
