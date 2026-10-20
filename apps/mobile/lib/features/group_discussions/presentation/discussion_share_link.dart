import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../application/discussion_links_controller.dart';
import '../application/discussion_share_controller.dart';
import '../data/discussion_conversion_gateway.dart';
import '../domain/discussion_links.dart';
import '../domain/discussion_models.dart';

class DiscussionShareLinkButton extends ConsumerWidget {
  const DiscussionShareLinkButton({
    required this.controller,
    required this.link,
    required this.locked,
    super.key,
  });
  final DiscussionLinksController controller;
  final DiscussionLink link;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = controller,
        actor = c.actor,
        epoch = c.epoch,
        scope = (actor: c.actor, room: c.room),
        l = AppLocalizations.of(context);
    ref.watch(authSessionProvider);
    if (!c.current(link.admissionId, epoch)) {
      return const SizedBox.shrink();
    }
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
              key: ValueKey('discussion-share-${link.id}'),
              icon: const Icon(Icons.drive_file_move_outline),
              tooltip: l.discussionShareProjectLink,
              onPressed: locked
                  ? null
                  : () async {
                      final route = ModalRoute.of(context),
                          router = GoRouter.maybeOf(context),
                          origin = router?.routeInformationProvider.value.uri,
                          messenger = ScaffoldMessenger.of(context);
                      bool current() =>
                          context.mounted &&
                          c.current(link.admissionId, epoch) &&
                          ref.read(authSessionProvider).identity?.id == actor &&
                          router?.routeInformationProvider.value.uri ==
                              origin &&
                          (route?.isActive ?? true) &&
                          c.pager.rows.any(
                            (fresh) =>
                                fresh.id == link.id &&
                                fresh.version == link.version &&
                                fresh.name == link.name &&
                                fresh.url.value == link.url.value,
                          );
                      if (!current()) {
                        return;
                      }
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => Consumer(
                          builder: (context, dialogRef, _) {
                            dialogRef.watch(authSessionProvider);
                            final destination = dialogRef.watch(
                              discussionConversionProvider(scope),
                            );
                            return ListenableBuilder(
                              listenable: c,
                              builder: (context, _) {
                                final valid =
                                    current() &&
                                    destination.asData?.value.canShareLinks ==
                                        true &&
                                    destination.asData?.value.projectId ==
                                        value.projectId;
                                return AlertDialog(
                                  scrollable: true,
                                  title: Text(l.discussionShareProjectLink),
                                  content: Text(
                                    valid
                                        ? '${link.name}\n${link.url.value}\n\n${l.discussionShareProjectLinkHelp}'
                                        : l.discussionUnavailable,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: Text(
                                        MaterialLocalizations.of(context)
                                            .cancelButtonLabel,
                                      ),
                                    ),
                                    if (valid)
                                      FilledButton(
                                        key: const Key(
                                          'discussion-share-confirm',
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: Text(
                                          l.discussionShareProjectLink,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                      if (accepted != true ||
                          !context.mounted ||
                          !current() ||
                          route?.isCurrent == false) {
                        return;
                      }
                      if (!await requireGroupPolicy(context, ref, actor) ||
                          !context.mounted ||
                          !current()) {
                        return;
                      }
                      final commands = ref.read(
                            discussionShareCommandsProvider,
                          ),
                          slot =
                              'share/${c.room}/${link.id}/${link.admissionId}';
                      final result = await commands.run(slot, actor, {
                        'p_room_id': c.room,
                        'p_project_id': value.projectId,
                        'p_expected_access_id': link.admissionId,
                        'p_link_id': link.id,
                        'p_expected_version': link.version,
                      });
                      if (result != null) {
                        // Pending feedback can rebuild/dispose this lazy row.
                        // A confirmed receipt resolves the retained attempt
                        // independently of that row's BuildContext lifetime.
                        commands.forget(slot);
                        if (messenger.mounted &&
                            c.current(link.admissionId, epoch) &&
                            router?.routeInformationProvider.value.uri ==
                                origin &&
                            (route?.isActive ?? true)) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l.discussionShareProjectLinkDone),
                            ),
                          );
                        }
                      }
                    },
            ),
    );
  }
}
