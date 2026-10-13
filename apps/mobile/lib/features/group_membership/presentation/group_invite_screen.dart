import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/data/group_gateway.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/group_relationship_controller.dart';
import '../domain/group_relationships.dart';
import 'group_membership_widgets.dart';

class GroupInviteScreen extends ConsumerStatefulWidget {
  const GroupInviteScreen({
    required this.token,
    this.authority = false,
    super.key,
  });
  final String token;
  final bool authority;
  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  Future<PublicGroup?>? publicRead;
  String? publicId;
  String get returnTo =>
      '/${widget.authority ? 'invite' : 'join'}/group/${widget.token}';
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    await ref
        .read(groupInvitationControllerProvider)
        .open(widget.token, widget.authority);
  }

  Future<void> accept({bool reenter = false}) async {
    final controller = ref.read(groupInvitationControllerProvider),
        actor = ref.read(authSessionProvider).identity?.id;
    final preview = controller.preview;
    final pending = controller.pendingAttempt;
    if (actor == null || (preview == null && pending == null)) return;
    final consent = pending?.consentVersion ?? preview!.consentVersion;
    if (widget.authority &&
        !await confirmGroupAction(
          context,
          actor,
          AppLocalizations.of(context).groupAcceptAuthority,
          explanation:
              (pending?.role ?? preview?.role) == GroupAuthority.coCreator
              ? AppLocalizations.of(context).groupCoCreatorWarning
              : AppLocalizations.of(context).groupIndependentRoles,
        )) {
      return;
    }
    if (!mounted || !await requireGroupPolicy(context, ref, actor)) return;
    if (!mounted ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready) {
      return;
    }
    await controller.accept(
      actor,
      consentVersion: consent,
      policyAllows: () => groupPolicyAllows(ref, actor),
      reenter: reenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        session = ref.watch(authSessionProvider),
        controller = ref.watch(groupInvitationControllerProvider);
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => Future.microtask(load),
    );
    return Scaffold(
      appBar: groupAppBar(context, l.groupInvitationTitle),
      body: GroupBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final current =
                controller.token == widget.token &&
                controller.authority == widget.authority &&
                controller.account == session.identity?.id;
            if (!current) {
              return const Center(child: CircularProgressIndicator());
            }
            final preview = controller.preview,
                busy = controller.busy || controller.loading;
            if (preview?.available == true && publicId != preview!.groupId) {
              publicId = preview.groupId;
              publicRead = ref
                  .read(groupGatewayProvider)
                  .publicDetail(publicId!);
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: Icon(Icons.groups_outlined, size: 56)),
                const SizedBox(height: 16),
                if (preview?.available == true) ...[
                  Text(
                    preview!.name!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(groupKindLabel(l, preview.kind!)),
                  if (publicRead != null)
                    FutureBuilder(
                      future: publicRead,
                      builder: (context, snapshot) => snapshot.hasError
                          ? GroupLoadError(
                              error: snapshot.error,
                              retry: () => setState(
                                () => publicRead = ref
                                    .read(groupGatewayProvider)
                                    .publicDetail(publicId!),
                              ),
                            )
                          : Text(snapshot.data?.content.description ?? ''),
                    ),
                  const SizedBox(height: 16),
                  Text(widget.authority ? l.groupSevenDays : l.groupReusable),
                  if (widget.authority) ...[
                    Text(groupRoleLabel(l, preview.role)),
                    if (preview.role == GroupAuthority.coCreator)
                      Text(l.groupCoCreatorWarning),
                  ],
                ] else if (!controller.loading && controller.failure == null)
                  Text(l.groupInviteUnavailable),
                if (busy) const LinearProgressIndicator(),
                GroupActionFailure(controller.failure),
                if (controller.receipt != null) ...[
                  Text(
                    controller.statusFailed
                        ? l.groupStatusUnknown
                        : controller.confirmed
                        ? (widget.authority
                              ? l.groupRoleConfirmed
                              : l.groupJoinedConfirmed)
                        : l.groupReceiptHistorical,
                    key: const Key('group-invite-status'),
                  ),
                  OutlinedButton(
                    key: const Key('group-invite-status-retry'),
                    onPressed: busy ? null : controller.refreshStatus,
                    child: Text(l.groupRetryStatus),
                  ),
                  if (controller.confirmed)
                    FilledButton(
                      onPressed: () =>
                          context.go('/groups/${controller.receipt!.groupId}'),
                      child: Text(l.groupsTitle),
                    ),
                  if (!widget.authority &&
                      !controller.confirmed &&
                      controller.current != null &&
                      preview?.available == true)
                    FilledButton(
                      key: const Key('group-invite-reenter'),
                      onPressed: busy ? null : () => accept(reenter: true),
                      child: Text(l.groupReenter),
                    ),
                ] else if (controller.pendingAttempt != null &&
                    session.phase == AuthSessionPhase.ready) ...[
                  FilledButton(
                    key: const Key('group-invite-accept'),
                    onPressed: busy ? null : accept,
                    child: Text(l.groupRetryOriginal),
                  ),
                ] else if (preview?.available == true) ...[
                  if (session.identity == null)
                    FilledButton(
                      key: const Key('group-invite-sign-in'),
                      onPressed: () => context.push(
                        Uri(
                          path: '/auth',
                          queryParameters: {'returnTo': returnTo},
                        ).toString(),
                      ),
                      child: Text(l.groupSignIn),
                    ),
                  if (session.phase == AuthSessionPhase.profileSetupRequired)
                    FilledButton(
                      key: const Key('group-invite-profile'),
                      onPressed: () => context.push(
                        Uri(
                          path: '/profile/edit',
                          queryParameters: {'returnTo': returnTo},
                        ).toString(),
                      ),
                      child: Text(l.groupCompleteProfile),
                    ),
                  if (session.phase == AuthSessionPhase.ready)
                    FilledButton(
                      key: const Key('group-invite-accept'),
                      onPressed: busy ? null : accept,
                      child: Text(
                        widget.authority
                            ? l.groupAcceptAuthority
                            : l.groupJoinDirect,
                      ),
                    ),
                ],
                OutlinedButton(
                  key: const Key('group-invite-preview-retry'),
                  onPressed: busy ? null : load,
                  child: Text(l.groupsRetry),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
