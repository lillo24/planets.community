import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/discussion_conversion_gateway.dart';
import '../domain/discussion_links.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';

class DiscussionShareLinkButton extends ConsumerStatefulWidget {
  const DiscussionShareLinkButton({
    required this.actor,
    required this.link,
    super.key,
  });
  final String actor;
  final DiscussionLink link;
  @override
  ConsumerState<DiscussionShareLinkButton> createState() => _ShareLinkState();
}

class _ShareLinkState extends ConsumerState<DiscussionShareLinkButton> {
  bool busy = false;
  Map<String, dynamic>? pending;
  bool get current =>
      mounted && ref.read(authSessionProvider).identity?.id == widget.actor;
  @override
  void didUpdateWidget(covariant DiscussionShareLinkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor ||
        oldWidget.link.id != widget.link.id ||
        oldWidget.link.admissionId != widget.link.admissionId) {
      pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authSessionProvider).identity?.id != widget.actor) {
      return const SizedBox.shrink();
    }
    final scope = (actor: widget.actor, room: widget.link.roomId),
        l = AppLocalizations.of(context);
    final conversion = ref.watch(discussionConversionProvider(scope));
    return conversion.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => discussionFailure(error) == DiscussionFailure.denied
          ? const SizedBox.shrink()
          : IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l.discussionRetry,
              onPressed: () =>
                  ref.invalidate(discussionConversionProvider(scope)),
            ),
      data: (value) => !value.canShareLinks
          ? const SizedBox.shrink()
          : IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              tooltip: l.discussionShareProjectLink,
              onPressed: busy
                  ? null
                  : () async {
                      final link = widget.link, actor = widget.actor;
                      if (pending == null) {
                        final accepted = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l.discussionShareProjectLink),
                            content: Text(
                              '${link.name}\n${link.url.value}\n\n${l.discussionShareProjectLinkHelp}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  MaterialLocalizations.of(context)
                                      .cancelButtonLabel,
                                ),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(l.discussionShareProjectLink),
                              ),
                            ],
                          ),
                        );
                        if (accepted != true ||
                            !current ||
                            actor != widget.actor) {
                          return;
                        }
                        pending = Map.unmodifiable({
                          'p_expected_profile_id': actor,
                          'p_client_request_id': const Uuid().v4(),
                          'p_room_id': link.roomId,
                          'p_project_id': value.projectId,
                          'p_expected_access_id': link.admissionId,
                          'p_link_id': link.id,
                          'p_expected_version': link.version,
                        });
                      }
                      setState(() => busy = true);
                      try {
                        await ref
                            .read(discussionConversionGatewayProvider)
                            .rpc('share_discussion_link_to_project', pending!);
                        if (current && actor == widget.actor) {
                          pending = null;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.discussionShareProjectLinkDone),
                            ),
                          );
                        }
                      } catch (e) {
                        if (current && actor == widget.actor) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(discussionErrorText(l, e))),
                          );
                        }
                      } finally {
                        if (current && actor == widget.actor) {
                          setState(() => busy = false);
                        }
                      }
                    },
            ),
    );
  }
}
