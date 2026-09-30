import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/moderation_controllers.dart';
import '../domain/moderation_models.dart';

class OwnReportsScreen extends ConsumerStatefulWidget {
  const OwnReportsScreen({super.key});

  @override
  ConsumerState<OwnReportsScreen> createState() => _OwnReportsScreenState();
}

class _OwnReportsScreenState extends ConsumerState<OwnReportsScreen> {
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
    await ref.read(ownModerationReportsProvider.notifier).load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(ownModerationReportsProvider);
    if (profileId != null && profileId != _requestedProfileId) {
      Future<void>.microtask(_load);
    }
    final belongs = state.expectedProfileId == profileId;
    final items = belongs ? state.items : const <OwnModerationReport>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationOwnReportsTitle)),
      body: SafeArea(
        child: state.isLoading && items.isEmpty
            ? LoadingState(message: l10n.moderationReportsLoading)
            : state.failure != null && items.isEmpty
            ? ErrorState(message: l10n.moderationReportsError, onRetry: _load)
            : items.isEmpty
            ? EmptyState(
                icon: Icons.flag_outlined,
                title: l10n.moderationReportsEmptyTitle,
                message: l10n.moderationReportsEmptyDescription,
              )
            : Column(
                children: [
                  if (state.failure != null)
                    Padding(
                      key: const Key('moderation-reports-refresh-error'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        0,
                      ),
                      child: Text(
                        l10n.moderationReportsError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.large),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.medium),
                        itemBuilder: (context, index) =>
                            _OwnReportCard(report: items[index]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OwnReportCard extends StatelessWidget {
  const _OwnReportCard({required this.report});

  final OwnModerationReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: Key('moderation-report-${report.reportId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.targetSummary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Chip(label: Text(_statusLabel(l10n, report.state))),
            if (report.contextSummary case final context?) Text(context),
            const SizedBox(height: AppSpacing.small),
            Text(_categoryLabel(l10n, report.category)),
            Text(
              DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                  .add_Hm()
                  .format(report.createdAt.toLocal()),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(report.explanation),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, ModerationReviewState state) =>
    switch (state) {
      ModerationReviewState.received => l10n.moderationStatusReceived,
      ModerationReviewState.underReview => l10n.moderationStatusUnderReview,
      ModerationReviewState.completed => l10n.moderationStatusCompleted,
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
