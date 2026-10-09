import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/counterstatement_controllers.dart';
import '../application/moderation_evidence_controllers.dart';
import '../domain/counterstatement_models.dart';
import '../domain/moderation_models.dart';

class CounterstatementDetailScreen extends ConsumerStatefulWidget {
  const CounterstatementDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<CounterstatementDetailScreen> createState() =>
      _CounterstatementDetailScreenState();
}

class _CounterstatementDetailScreenState
    extends ConsumerState<CounterstatementDetailScreen> {
  final _statementController = TextEditingController();
  String? _statementError;
  String? _requestedProfileId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    _requestedProfileId = profileId;
    await ref
        .read(counterstatementDetailProvider(widget.requestId).notifier)
        .load(profileId);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.read(authSessionProvider).identity?.id;
    final statement = _statementController.text;
    setState(() {
      _statementError = isValidCounterstatement(statement)
          ? null
          : l10n.counterstatementStatementInvalid;
    });
    if (profileId == null || _statementError != null) return;
    final succeeded = await ref
        .read(counterstatementDetailProvider(widget.requestId).notifier)
        .submit(expectedProfileId: profileId, statement: statement);
    if (succeeded && mounted) {
      ref.invalidate(moderationEvidenceRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(counterstatementDetailProvider(widget.requestId));
    if (profileId != null && profileId != _requestedProfileId) {
      Future<void>.microtask(_load);
    }
    final detail = state.expectedProfileId == profileId ? state.detail : null;

    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.counterstatementDetailTitle),
      ),
      body: SafeArea(
        child: state.isLoading && detail == null
            ? LoadingState(message: l10n.moderationReviewRequestsLoading)
            : detail == null
            ? ErrorState(
                message: l10n.moderationReviewRequestsError,
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  Text(
                    detail.contextSummary ?? detail.targetSummary,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(_categoryLabel(l10n, detail.category)),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    l10n.corroborationOriginalExplanationTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(detail.explanation),
                  const SizedBox(height: AppSpacing.large),
                  Text(l10n.counterstatementPrivacyDisclosure),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.counterstatementInferenceDisclosure),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.counterstatementManualReviewDisclosure),
                  const SizedBox(height: AppSpacing.large),
                  if (detail.statement case final statement?)
                    Card(
                      key: const Key('counterstatement-submitted'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.counterstatementSubmittedTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.small),
                            Text(statement),
                            const SizedBox(height: AppSpacing.small),
                            Text(l10n.counterstatementSubmittedDescription),
                          ],
                        ),
                      ),
                    )
                  else if (!detail.canRespond)
                    Text(
                      l10n.counterstatementClosedDescription,
                      key: const Key('counterstatement-closed'),
                    )
                  else ...[
                    TextField(
                      key: const Key('counterstatement-statement'),
                      controller: _statementController,
                      enabled: !state.isSubmitting,
                      minLines: 5,
                      maxLines: 12,
                      maxLength: counterstatementMaxLength,
                      decoration: InputDecoration(
                        labelText: l10n.counterstatementStatementLabel,
                        helperText: l10n.counterstatementStatementHelp,
                        errorText: _statementError,
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (state.failure != null)
                      Text(
                        _failureMessage(l10n, state.failure!),
                        key: const Key('counterstatement-submit-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    FilledButton(
                      key: const Key('counterstatement-submit'),
                      onPressed: state.isSubmitting ? null : _submit,
                      child: Text(
                        state.isSubmitting
                            ? l10n.counterstatementSubmitting
                            : l10n.counterstatementSubmitAction,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

String _failureMessage(
  AppLocalizations l10n,
  ModerationEvidenceFailureKind failure,
) => switch (failure) {
  ModerationEvidenceFailureKind.conflict => l10n.counterstatementConflictError,
  _ => l10n.counterstatementSubmitError,
};

String _categoryLabel(AppLocalizations l10n, ModerationCategory category) =>
    switch (category) {
      ModerationCategory.safetyConcern => l10n.moderationCategorySafety,
      ModerationCategory.harassmentAbuse => l10n.moderationCategoryHarassment,
      ModerationCategory.fraudScam => l10n.moderationCategoryFraud,
      ModerationCategory.inappropriateContentConduct =>
        l10n.moderationCategoryInappropriate,
      ModerationCategory.spam => l10n.moderationCategorySpam,
      ModerationCategory.other => l10n.moderationCategoryOther,
    };
