import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/corroboration_controllers.dart';
import '../application/moderation_evidence_controllers.dart';
import '../domain/corroboration_models.dart';
import 'moderation_routes.dart';

class CorroborationRequestsScreen extends ConsumerStatefulWidget {
  const CorroborationRequestsScreen({super.key});

  @override
  ConsumerState<CorroborationRequestsScreen> createState() =>
      _CorroborationRequestsScreenState();
}

class _CorroborationRequestsScreenState
    extends ConsumerState<CorroborationRequestsScreen> {
  String? _requestedProfileId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    _requestedProfileId = profileId;
    await ref.read(corroborationRequestsProvider.notifier).load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(corroborationRequestsProvider);
    if (profileId != null && profileId != _requestedProfileId) {
      Future<void>.microtask(_load);
    }
    final items = state.expectedProfileId == profileId
        ? state.items
        : const <GroupCorroborationSummary>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.corroborationRequestsTitle)),
      body: SafeArea(
        child: state.isLoading && items.isEmpty
            ? LoadingState(message: l10n.corroborationRequestsLoading)
            : state.failure != null && items.isEmpty
            ? ErrorState(
                message: l10n.corroborationRequestsError,
                onRetry: _load,
              )
            : items.isEmpty
            ? EmptyState(
                icon: Icons.fact_check_outlined,
                title: l10n.corroborationRequestsEmptyTitle,
                message: l10n.corroborationRequestsEmptyDescription,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  itemCount: items.length + (state.failure == null ? 0 : 1),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.medium),
                  itemBuilder: (context, index) {
                    if (state.failure != null && index == 0) {
                      return Text(
                        l10n.corroborationRequestsError,
                        key: const Key('corroboration-refresh-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                    final offset = state.failure == null ? index : index - 1;
                    return _CorroborationRequestCard(request: items[offset]);
                  },
                ),
              ),
      ),
    );
  }
}

class _CorroborationRequestCard extends StatelessWidget {
  const _CorroborationRequestCard({required this.request});

  final GroupCorroborationSummary request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = request.responseChoice != null
        ? l10n.corroborationStatusSubmitted
        : request.canRespond
        ? l10n.corroborationStatusPending
        : l10n.corroborationStatusClosed;
    return Card(
      key: Key('corroboration-request-${request.requestId}'),
      child: InkWell(
        onTap: () => context.push(
          ModerationRoutes.corroborationDetail(request.requestId),
        ),
        borderRadius: AppRadii.large,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.targetSummary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (request.contextSummary case final contextSummary?)
                Text(contextSummary),
              const SizedBox(height: AppSpacing.small),
              Chip(label: Text(status)),
              Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(request.createdAt.toLocal()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CorroborationDetailScreen extends ConsumerStatefulWidget {
  const CorroborationDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<CorroborationDetailScreen> createState() =>
      _CorroborationDetailScreenState();
}

class _CorroborationDetailScreenState
    extends ConsumerState<CorroborationDetailScreen> {
  final _explanationController = TextEditingController();
  CorroborationChoice? _choice;
  String? _choiceError;
  String? _explanationError;
  String? _requestedProfileId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    _requestedProfileId = profileId;
    await ref
        .read(corroborationDetailProvider(widget.requestId).notifier)
        .load(profileId);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.read(authSessionProvider).identity?.id;
    final choice = _choice;
    final explanation = _explanationController.text;
    setState(() {
      _choiceError = choice == null ? l10n.corroborationChoiceRequired : null;
      _explanationError = isValidCorroborationExplanation(explanation)
          ? null
          : l10n.corroborationExplanationInvalid;
    });
    if (profileId == null || choice == null || _explanationError != null) {
      return;
    }
    final succeeded = await ref
        .read(corroborationDetailProvider(widget.requestId).notifier)
        .submit(
          expectedProfileId: profileId,
          choice: choice,
          explanation: explanation,
        );
    if (succeeded && mounted) {
      ref.invalidate(corroborationRequestsProvider);
      ref.invalidate(moderationEvidenceRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(corroborationDetailProvider(widget.requestId));
    if (profileId != null && profileId != _requestedProfileId) {
      Future<void>.microtask(_load);
    }
    final belongs = state.expectedProfileId == profileId;
    final detail = belongs ? state.detail : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.corroborationDetailTitle)),
      body: SafeArea(
        child: state.isLoading && detail == null
            ? LoadingState(message: l10n.corroborationRequestsLoading)
            : detail == null
            ? ErrorState(
                message: l10n.corroborationRequestsError,
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  Text(
                    detail.targetSummary,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (detail.contextSummary case final contextSummary?)
                    Text(contextSummary),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    l10n.corroborationOriginalExplanationTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(detail.explanation),
                  const SizedBox(height: AppSpacing.large),
                  Text(l10n.corroborationPrivacyDisclosure),
                  const SizedBox(height: AppSpacing.small),
                  Text(l10n.corroborationWitnessDisclosure),
                  const SizedBox(height: AppSpacing.large),
                  if (detail.responseChoice case final responseChoice?) ...[
                    _SubmittedResponse(
                      choice: responseChoice,
                      explanation: detail.responseExplanation,
                    ),
                  ] else if (!detail.canRespond) ...[
                    Text(
                      l10n.corroborationClosedDescription,
                      key: const Key('corroboration-closed'),
                    ),
                  ] else ...[
                    Text(
                      l10n.corroborationChoiceLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    for (final choice in CorroborationChoice.values) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ChoiceChip(
                          key: Key('corroboration-choice-${choice.wireValue}'),
                          label: Text(_choiceLabel(l10n, choice)),
                          selected: _choice == choice,
                          onSelected: state.isSubmitting
                              ? null
                              : (_) => setState(() {
                                  _choice = choice;
                                  _choiceError = null;
                                }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                    if (_choiceError case final error?)
                      Text(error, style: _errorStyle(context)),
                    TextField(
                      key: const Key('corroboration-explanation'),
                      controller: _explanationController,
                      enabled: !state.isSubmitting,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: corroborationExplanationMaxLength,
                      decoration: InputDecoration(
                        labelText: l10n.corroborationExplanationLabel,
                        helperText: l10n.corroborationExplanationHelp,
                        errorText: _explanationError,
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (state.failure != null)
                      Text(
                        l10n.corroborationSubmitError,
                        key: const Key('corroboration-submit-error'),
                        style: _errorStyle(context),
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    FilledButton(
                      key: const Key('corroboration-submit'),
                      onPressed: state.isSubmitting ? null : _submit,
                      child: Text(
                        state.isSubmitting
                            ? l10n.corroborationSubmitting
                            : l10n.corroborationSubmitAction,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SubmittedResponse extends StatelessWidget {
  const _SubmittedResponse({required this.choice, this.explanation});

  final CorroborationChoice choice;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const Key('corroboration-submitted'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.corroborationSubmittedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(_choiceLabel(l10n, choice)),
            if (explanation case final body?) Text(body),
            const SizedBox(height: AppSpacing.small),
            Text(l10n.corroborationSubmittedDescription),
          ],
        ),
      ),
    );
  }
}

String _choiceLabel(AppLocalizations l10n, CorroborationChoice choice) =>
    switch (choice) {
      CorroborationChoice.agree => l10n.corroborationChoiceAgree,
      CorroborationChoice.disagree => l10n.corroborationChoiceDisagree,
      CorroborationChoice.unsure => l10n.corroborationChoiceUnsure,
    };

TextStyle _errorStyle(BuildContext context) =>
    TextStyle(color: Theme.of(context).colorScheme.error);
