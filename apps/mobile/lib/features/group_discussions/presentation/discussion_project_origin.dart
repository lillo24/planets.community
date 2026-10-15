import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../groups/domain/group_models.dart';
import '../data/discussion_conversion_gateway.dart';
import '../application/discussion_controllers.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';

final _originProvider = FutureProvider.autoDispose
    .family<String?, ({String actor, String project})>((ref, scope) async {
      ref.watch(discussionSignalsProvider);
      final value = await ref.watch(discussionConversionGatewayProvider).rpc(
        'get_project_discussion_origin',
        {'p_expected_profile_id': scope.actor, 'p_project_id': scope.project},
      );
      if (value == null) return null;
      if (value is! Map ||
          value['profile_id'] != scope.actor ||
          value['project_id'] != scope.project) {
        throw const FormatException('Mismatched private Project origin.');
      }
      return groupUuid(value['room_id']);
    });

/// Safe continuity fallback: a separate read-only source view. No room/history
/// request occurs until the private resolver independently authorizes a route.
class DiscussionProjectOrigin extends ConsumerWidget {
  const DiscussionProjectOrigin({
    required this.actor,
    required this.projectId,
    super.key,
  });
  final String actor, projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authSessionProvider).identity?.id != actor) {
      return const SizedBox.shrink();
    }
    final scope = (actor: actor, project: projectId),
        l = AppLocalizations.of(context);
    return ref
        .watch(_originProvider(scope))
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) => DiscussionError(
            error,
            retry: () => ref.invalidate(_originProvider(scope)),
          ),
          data: (room) => room == null
              ? const SizedBox.shrink()
              : TextButton.icon(
                  key: const Key('project-planning-origin'),
                  icon: const Icon(Icons.history),
                  label: Text(l.discussionConversionHistory),
                  onPressed: () async {
                    // Re-resolve at activation, so a stale route cannot carry a revoked
                    // source grant across a role/account change while Project access stays.
                    ref.invalidate(_originProvider(scope));
                    try {
                      final fresh = await ref.read(
                        _originProvider(scope).future,
                      );
                      if (!context.mounted ||
                          ref.read(authSessionProvider).identity?.id != actor ||
                          fresh == null) {
                        return;
                      }
                      await context.push<Object?>(discussionRoute(fresh));
                    } catch (_) {
                      /* The provider renders this explicit failure with Retry. */
                    }
                  },
                ),
        );
  }
}
