import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_projects/domain/group_project_creation_return.dart';

/// Ordinary personal creation. The actor-bound return marker carries no Community
/// ownership, registered Group binding, participation or publishing authority.
class CoNativeProjectAction extends ConsumerWidget {
  const CoNativeProjectAction({required this.returnPath, super.key});
  final String returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final actor = session.identity?.id;
    if (session.phase != AuthSessionPhase.ready || actor == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('co-native-project'),
      tooltip: AppLocalizations.of(context).proposalCreateTitle,
      icon: const Icon(Icons.add_task_outlined),
      onPressed: () => context.push(
        '/proposals/create',
        extra: GroupProjectCreationReturn(actor, returnPath: returnPath),
      ),
    );
  }
}
