import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/participation_controllers.dart';
import '../domain/participation_models.dart';
import 'participation_routes.dart';
import 'project_participation_section.dart';

class JoinRequestScreen extends ConsumerStatefulWidget {
  const JoinRequestScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends ConsumerState<JoinRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  late final String? _expectedProfileId;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final expectedProfileId = _expectedProfileId;
    if (expectedProfileId == null ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final succeeded = await ref
        .read(participationCommandProvider.notifier)
        .requestToJoin(
          expectedProfileId: expectedProfileId,
          projectId: widget.projectId,
          projectKind: widget.projectKind,
          message: _messageController.text,
        );
    if (!succeeded ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    _messageController.clear();
    context.go(
      ParticipationRoutes.detail(widget.projectKind, widget.projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final command = ref.watch(participationCommandProvider);
    final isThisCommand = command.projectId == widget.projectId;
    final isBusy = isThisCommand && command.isBusy;
    final failure = isThisCommand ? command.failure : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.participationJoinTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.participationJoinDescription),
                const SizedBox(height: AppSpacing.small),
                Text(l10n.participationMessagePrivateNote),
                const SizedBox(height: AppSpacing.large),
                TextFormField(
                  key: const Key('participation-message-field'),
                  controller: _messageController,
                  enabled: !isBusy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: participationRequestMessageMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.participationOptionalMessage,
                    hintText: l10n.participationOptionalMessageHint,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      (value ?? '').trim().length >
                          participationRequestMessageMaxLength
                      ? l10n.participationInvalidMessage
                      : null,
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.small),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      participationFailureMessage(l10n, failure),
                      key: const Key('participation-join-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                FilledButton(
                  key: const Key('participation-send-request'),
                  onPressed: isBusy ? null : _submit,
                  child: isBusy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.participationSendRequest),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
