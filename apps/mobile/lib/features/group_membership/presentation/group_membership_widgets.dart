import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../groups/application/group_controllers.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../../policies/presentation/policy_acceptance_screen.dart';
import '../domain/group_relationships.dart';

String groupRoleLabel(AppLocalizations l, GroupAuthority? role) =>
    switch (role) {
      GroupAuthority.creator => l.groupCreator,
      GroupAuthority.coCreator => l.groupCoCreator,
      GroupAuthority.coOrganizer => l.groupCoOrganizer,
      null => l.groupMember,
    };
String groupRelationshipStatus(AppLocalizations l, String? status) =>
    switch (status) {
      'current' => l.groupStatusCurrent,
      'left' => l.groupStatusLeft,
      'removed' => l.groupStatusRemoved,
      'pending' => l.groupStatusPending,
      'accepted' => l.groupStatusAccepted,
      'rejected' => l.groupStatusRejected,
      'withdrawn' => l.groupStatusWithdrawn,
      'declined' => l.groupStatusDeclined,
      'revoked' => l.groupStatusRevoked,
      'expired' => l.groupStatusExpired,
      'co_creator' => l.groupCoCreator,
      'co_organizer' => l.groupCoOrganizer,
      _ => l.groupStatusUnknown,
    };
bool groupPolicyAllows(WidgetRef ref, String actor) => ref
    .read(policyAcceptanceProvider)
    .allows(actor, ref.read(policyVersionProvider));
Future<bool> requireGroupPolicy(
  BuildContext context,
  WidgetRef ref,
  String actor,
) async {
  if (ref.read(authSessionProvider).identity?.id != actor) return false;
  if (groupPolicyAllows(ref, actor)) return true;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const PolicyAcceptanceScreen(returnToPreviousPage: true),
    ),
  );
  return context.mounted &&
      ref.read(authSessionProvider).identity?.id == actor &&
      groupPolicyAllows(ref, actor);
}

Future<bool> confirmGroupAction(
  BuildContext context,
  String actor,
  String title, {
  String? explanation,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _GroupConfirmation(
        actor: actor,
        title: title,
        explanation: explanation,
      ),
    ) ==
    true;

class _GroupConfirmation extends ConsumerWidget {
  const _GroupConfirmation({
    required this.actor,
    required this.title,
    this.explanation,
  });
  final String actor, title;
  final String? explanation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, next) {
      if (next != actor && context.mounted) Navigator.of(context).pop(false);
    });
    return AlertDialog(
      title: Text(title),
      content: explanation == null
          ? null
          : SingleChildScrollView(child: Text(explanation!)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.groupCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ref.read(authSessionProvider).identity?.id == actor,
          ),
          child: Text(l.groupConfirm),
        ),
      ],
    );
  }
}

class GroupActionFailure extends StatelessWidget {
  const GroupActionFailure(this.failure, {super.key});
  final GroupFailure? failure;
  @override
  Widget build(BuildContext context) => failure == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              groupFailureLabel(AppLocalizations.of(context), failure!),
            ),
          ),
        );
}

class GroupBody extends StatelessWidget {
  const GroupBody({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    ),
  );
}
