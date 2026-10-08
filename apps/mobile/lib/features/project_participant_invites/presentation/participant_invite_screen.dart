import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../application/participant_admission_controller.dart';
import '../data/participant_invitation_gateway.dart';
import '../domain/participant_invitation_models.dart';
import 'participant_invitation_routes.dart';
import 'participant_invite_messages.dart';

class ParticipantInviteScreen extends ConsumerStatefulWidget {
  const ParticipantInviteScreen({required this.token, super.key});
  final String token;
  @override
  ConsumerState<ParticipantInviteScreen> createState() =>
      _ParticipantInviteScreenState();
}

class _ParticipantInviteScreenState
    extends ConsumerState<ParticipantInviteScreen> {
  bool _chatLoading = false;
  String? _chatFailure;
  String? _scheduledKey;
  var _chatRevision = 0;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant ParticipantInviteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _chatRevision++;
      _chatFailure = null;
      _chatLoading = false;
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final state = ref.read(participantAdmissionProvider);
    if (state.isFor(widget.token, ref.read(authSessionProvider).identity?.id) &&
        state.loading) {
      return;
    }
    await ref.read(participantAdmissionProvider.notifier).load(widget.token);
  }

  void _continue(String path) {
    final destination = ParticipantInvitationRoutes.invite(widget.token);
    context.push(
      Uri(path: path, queryParameters: {'returnTo': destination}).toString(),
    );
  }

  Future<void> _openChat(ParticipantAdmissionState state) async {
    if (_chatLoading || state.account == null || state.projectId == null) {
      return;
    }
    final account = state.account!;
    final token = widget.token;
    final revision = ++_chatRevision;
    setState(() {
      _chatLoading = true;
      _chatFailure = null;
    });
    bool current() =>
        mounted &&
        revision == _chatRevision &&
        widget.token == token &&
        ref.read(authSessionProvider).accountAccessIdentityId == account;
    try {
      final chat = await ref
          .read(participantInvitationGatewayProvider)
          .currentChat(account, state.projectId!);
      if (!mounted || !current()) return;
      if (chat == null) {
        setState(
          () =>
              _chatFailure = AppLocalizations.of(context)
                  .participantInviteNoChat,
        );
        return;
      }
      context.push(projectChatRoute(chat));
    } catch (_) {
      if (current()) {
        setState(
          () =>
              _chatFailure = AppLocalizations.of(context)
                  .participantInviteChatFailure,
        );
      }
    } finally {
      if (current()) setState(() => _chatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    ref.listen(
      authSessionProvider.select(
        (s) => (s.identity?.id, s.accountAccessIdentityId),
      ),
      (_, _) {
        _chatRevision++;
        if (mounted) {
          setState(() {
            _chatLoading = false;
            _chatFailure = null;
          });
        }
      },
    );
    final state = ref.watch(participantAdmissionProvider);
    final current = state.isFor(widget.token, session.identity?.id);
    if (!current) {
      final key = '${widget.token}\u0000${session.identity?.id}';
      if (_scheduledKey != key) {
        _scheduledKey = key;
        Future<void>.microtask(() async {
          await _load();
          if (mounted) _scheduledKey = null;
        });
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.participantInviteTitle)),
      body: SafeArea(
        child: !current
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  if (state.loading || state.busy)
                    const LinearProgressIndicator(),
                  if (state.preview?.available == true) ...[
                    Text(
                      state.preview!.title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(l10n.participantInviteExplanation),
                    Text(l10n.participantInvitePendingRequest),
                  ] else if (!state.loading && state.failure == null)
                    Text(
                      l10n.participantInviteUnavailable,
                      key: const Key('participant-invite-unavailable'),
                    ),
                  if (state.failure case final failure?)
                    Text(
                      failure == ParticipantInviteFailure.network
                          ? state.result == null
                                ? l10n.participantInviteNetwork
                                : l10n.projectShareFailure
                          : participantInviteFailureMessage(l10n, failure),
                      key: const Key('participant-invite-error'),
                    ),
                  if (state.projectId != null && state.kind != null)
                    TextButton(
                      key: const Key('participant-invite-view-project'),
                      onPressed: () => context.push(
                        ProjectDelegateRoutes.detail(
                          state.kind!,
                          state.projectId!,
                        ),
                      ),
                      child: Text(l10n.participantInviteViewProject),
                    ),
                  if (state.result != null)
                    ..._result(state)
                  else if (state.preview?.available == true ||
                      state.hasAttempt) ...[
                    if (session.phase == AuthSessionPhase.signedOut)
                      FilledButton(
                        key: const Key('participant-invite-sign-in'),
                        onPressed: () => _continue('/auth'),
                        child: Text(l10n.projectInviteSignIn),
                      ),
                    if (session.phase ==
                            AuthSessionPhase.profileSetupRequired ||
                        state.failure ==
                            ParticipantInviteFailure.profileRequired)
                      FilledButton(
                        key: const Key('participant-invite-profile'),
                        onPressed: () => _continue('/profile/edit'),
                        child: Text(l10n.participantInviteProfile),
                      ),
                    if (session.phase == AuthSessionPhase.ready)
                      FilledButton(
                        key: const Key('participant-invite-join'),
                        onPressed: state.busy || state.loading
                            ? null
                            : () => ref
                                  .read(participantAdmissionProvider.notifier)
                                  .join(session.identity!.id),
                        child: Text(
                          state.hasAttempt
                              ? l10n.participantInviteRetryJoin
                              : l10n.participantInviteJoin,
                        ),
                      ),
                  ],
                  if (_chatFailure != null)
                    Text(
                      _chatFailure!,
                      key: const Key('participant-invite-chat-error'),
                    ),
                  OutlinedButton(
                    onPressed: state.busy || state.loading ? null : _load,
                    child: Text(l10n.retryAction),
                  ),
                  TextButton(
                    key: const Key('participant-invite-close'),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: Text(l10n.projectShareClose),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _result(ParticipantAdmissionState state) {
    final l10n = AppLocalizations.of(context);
    if (!state.participationLoaded) {
      return [
        Text(
          l10n.participantInviteReadFailure,
          key: const Key('participant-invite-read-error'),
        ),
        TextButton(
          key: const Key('participant-invite-refresh-status'),
          onPressed: state.busy
              ? null
              : ref
                    .read(participantAdmissionProvider.notifier)
                    .refreshParticipation,
          child: Text(l10n.participantInviteRefreshStatus),
        ),
      ];
    }
    final creator =
        state.result!.outcome == ParticipantAdmissionOutcome.creator;
    if (creator || state.currentMember) {
      return [
        Text(
          creator
              ? l10n.participantInviteCreator
              : l10n.participationParticipating,
          key: const Key('participant-invite-current'),
        ),
        FilledButton(
          key: const Key('participant-invite-open-chat'),
          onPressed: state.busy || _chatLoading ? null : () => _openChat(state),
          child: Text(l10n.participantInviteOpenChat),
        ),
        TextButton(
          onPressed: state.busy
              ? null
              : ref
                    .read(participantAdmissionProvider.notifier)
                    .refreshParticipation,
          child: Text(l10n.participantInviteRefreshStatus),
        ),
      ];
    }
    return [
      Text(
        l10n.participantInviteEnded,
        key: const Key('participant-invite-ended'),
      ),
      if (state.preview?.available == true)
        FilledButton(
          key: const Key('participant-invite-rejoin'),
          onPressed: state.busy
              ? null
              : () => ref
                    .read(participantAdmissionProvider.notifier)
                    .join(state.account!, reenter: true),
          child: Text(l10n.participantInviteJoinAgain),
        ),
    ];
  }
}
