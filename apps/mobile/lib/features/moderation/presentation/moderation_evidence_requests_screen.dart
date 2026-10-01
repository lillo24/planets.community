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
import '../application/moderation_evidence_controllers.dart';
import '../domain/moderation_evidence_models.dart';
import 'moderation_routes.dart';

class ModerationEvidenceRequestsScreen extends ConsumerStatefulWidget {
  const ModerationEvidenceRequestsScreen({super.key});

  @override
  ConsumerState<ModerationEvidenceRequestsScreen> createState() =>
      _ModerationEvidenceRequestsScreenState();
}

class _ModerationEvidenceRequestsScreenState
    extends ConsumerState<ModerationEvidenceRequestsScreen> {
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
    await ref.read(moderationEvidenceRequestsProvider.notifier).load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(moderationEvidenceRequestsProvider);
    if (profileId != null && profileId != _requestedProfileId) {
      Future<void>.microtask(_load);
    }
    final items = state.expectedProfileId == profileId
        ? state.items
        : const <ModerationEvidenceSummary>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationReviewRequestsTitle)),
      body: SafeArea(
        child: state.isLoading && items.isEmpty
            ? LoadingState(message: l10n.moderationReviewRequestsLoading)
            : state.failure != null && items.isEmpty
            ? ErrorState(
                message: l10n.moderationReviewRequestsError,
                onRetry: _load,
              )
            : items.isEmpty
            ? EmptyState(
                icon: Icons.fact_check_outlined,
                title: l10n.moderationReviewRequestsEmptyTitle,
                message: l10n.moderationReviewRequestsEmptyDescription,
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
                        l10n.moderationReviewRequestsError,
                        key: const Key('moderation-evidence-refresh-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                    final offset = state.failure == null ? index : index - 1;
                    return _EvidenceRequestCard(request: items[offset]);
                  },
                ),
              ),
      ),
    );
  }
}

class _EvidenceRequestCard extends StatelessWidget {
  const _EvidenceRequestCard({required this.request});

  final ModerationEvidenceSummary request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = request.respondedAt != null
        ? l10n.corroborationStatusSubmitted
        : request.canRespond
        ? l10n.corroborationStatusPending
        : l10n.corroborationStatusClosed;
    final kindLabel = switch (request.kind) {
      ModerationEvidenceKind.groupCorroboration =>
        l10n.moderationEvidenceKindGroup,
      ModerationEvidenceKind.resourceCounterstatement =>
        l10n.moderationEvidenceKindCounterstatement,
    };
    return Card(
      key: Key(
        'moderation-evidence-request-${request.kind.wireValue}-${request.requestId}',
      ),
      child: InkWell(
        onTap: () => context.push(switch (request.kind) {
          ModerationEvidenceKind.groupCorroboration =>
            ModerationRoutes.corroborationDetail(request.requestId),
          ModerationEvidenceKind.resourceCounterstatement =>
            ModerationRoutes.counterstatementDetail(request.requestId),
        }),
        borderRadius: AppRadii.large,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kindLabel, style: Theme.of(context).textTheme.labelLarge),
              Text(
                request.targetSummary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (request.contextSummary case final contextSummary?)
                Text(contextSummary),
              const SizedBox(height: AppSpacing.small),
              Wrap(
                spacing: AppSpacing.small,
                children: [Chip(label: Text(status))],
              ),
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
