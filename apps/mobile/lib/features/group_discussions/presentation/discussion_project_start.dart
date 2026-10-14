import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../group_projects/domain/group_project_creation_return.dart';
import '../application/discussion_controllers.dart';
import '../application/discussion_project_handoff.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';

class DiscussionProjectStart extends ConsumerStatefulWidget {
  const DiscussionProjectStart({
    required this.controller,
    required this.source,
    required this.enabled,
    super.key,
  });
  final DiscussionChatController controller;
  final DiscussionRoom source;
  final bool enabled;
  @override
  ConsumerState<DiscussionProjectStart> createState() =>
      _DiscussionProjectStartState();
}

class _DiscussionProjectStartState
    extends ConsumerState<DiscussionProjectStart> {
  bool opening = false;
  Future<void> start() async {
    if (opening || !widget.enabled) return;
    final c = widget.controller,
        source = widget.source,
        route = ModalRoute.of(context);
    bool current() =>
        mounted &&
        !c.disposed &&
        c.authorized() &&
        ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
        ref.read(authSessionProvider).identity?.id == c.actor &&
        c.room?.admissionId == source.admissionId &&
        c.room?.canPublish == true &&
        route?.isCurrent == true;
    setState(() => opening = true);
    try {
      if (!await requireGroupPolicy(context, ref, c.actor) || !current()) {
        return;
      }
      final fresh = await checkDiscussionProjectHandoff(
        c.gateway,
        c.actor,
        source,
        current,
      );
      if (!mounted || !current()) return;
      await context.push<Object?>(
        Uri(
          path: '/proposals/create',
          queryParameters: {'group': fresh.groupId},
        ).toString(),
        extra: GroupProjectCreationReturn(c.actor),
      );
      // Source content/scroll remain in the retained room. Its own current grant
      // controls any return; Project creation and publication are independent.
    } catch (error) {
      if (mounted &&
          ref.read(authSessionProvider).identity?.id == c.actor &&
          discussionFailure(error) == DiscussionFailure.denied) {
        // An authoritative source denial must not leave its old private window
        // on screen. A still-entitled reader receives fresh role metadata.
        ref.invalidate(discussionChatProvider(c.roomId));
      }
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discussionErrorText(AppLocalizations.of(context), error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('discussion-create-project'),
    tooltip: AppLocalizations.of(context).discussionCreateProject,
    onPressed: opening || !widget.enabled ? null : start,
    icon: opening
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add_circle_outline),
  );
}
