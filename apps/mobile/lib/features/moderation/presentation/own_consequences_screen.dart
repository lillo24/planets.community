import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/own_consequence_controller.dart';
import '../domain/own_consequence_models.dart';

class OwnConsequencesScreen extends ConsumerStatefulWidget {
  const OwnConsequencesScreen({super.key});

  @override
  ConsumerState<OwnConsequencesScreen> createState() =>
      _OwnConsequencesScreenState();
}

class _OwnConsequencesScreenState extends ConsumerState<OwnConsequencesScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final state = ref.watch(ownConsequenceProvider);
    final ready = session.phase == AuthSessionPhase.ready;
    if (ready && state.phase == OwnHistoryPhase.idle) {
      Future<void>.microtask(() async {
        if (mounted) await ref.read(ownConsequenceProvider.notifier).load();
      });
    }
    return OwnConsequencesBody(
      state: ready && state.profileId == session.identity?.id
          ? state
          : const OwnConsequenceState(phase: OwnHistoryPhase.loading),
      onRefresh: ready
          ? () => ref.read(ownConsequenceProvider.notifier).load()
          : null,
      onMore: ready
          ? () => ref.read(ownConsequenceProvider.notifier).loadMore()
          : null,
    );
  }
}

// Pure presentation also supports synthetic previews without an Auth backend.
class OwnConsequencesBody extends StatelessWidget {
  const OwnConsequencesBody({
    super.key,
    required this.state,
    this.onRefresh,
    this.onMore,
  });

  final OwnConsequenceState state;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading =
        state.phase == OwnHistoryPhase.loading ||
        state.phase == OwnHistoryPhase.idle;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noticesTitle),
        actions: [
          IconButton(
            key: const Key('notices-refresh'),
            tooltip: l10n.noticesRefresh,
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: loading
                ? LoadingState(message: l10n.noticesLoading)
                : RefreshIndicator(
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      itemCount: state.items.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.medium,
                            ),
                            child: Text(l10n.noticesIntroduction),
                          );
                        }
                        if (index <= state.items.length) {
                          return OwnConsequenceCard(
                            notice: state.items[index - 1],
                          );
                        }
                        if (state.failure != null) {
                          return Column(
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  state.failure == OwnHistoryFailure.forbidden
                                      ? l10n.noticesForbidden
                                      : state.items.isEmpty
                                      ? l10n.noticesLoadError
                                      : l10n.noticesPageError,
                                  key: const Key('notices-error'),
                                ),
                              ),
                              TextButton(
                                key: const Key('notices-retry'),
                                onPressed: state.items.isEmpty
                                    ? onRefresh
                                    : onMore,
                                child: Text(l10n.noticesRetry),
                              ),
                            ],
                          );
                        }
                        if (state.items.isEmpty) {
                          return Semantics(
                            liveRegion: true,
                            child: Column(
                              children: [
                                const Icon(Icons.inbox_outlined),
                                Text(
                                  l10n.noticesEmptyTitle,
                                  key: const Key('notices-empty'),
                                ),
                                Text(l10n.noticesEmptyBody),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            if (state.phase == OwnHistoryPhase.loadingMore)
                              LoadingState(message: l10n.noticesPageLoading)
                            else if (state.hasMore)
                              TextButton(
                                key: const Key('notices-load-more'),
                                onPressed: onMore,
                                child: Text(l10n.noticesLoadMore),
                              )
                            else
                              Text(l10n.noticesEnd),
                            Text(l10n.noticesTimeZone),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class OwnConsequenceCard extends StatelessWidget {
  const OwnConsequenceCard({super.key, required this.notice});

  final OwnConsequence notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = DateFormat.yMMMd(l10n.localeName).add_Hm();
    final (title, effect) = switch (notice.type) {
      OwnConsequenceType.safetyNotice => (
        l10n.noticesSafetyTitle,
        l10n.noticesSafetyEffect,
      ),
      OwnConsequenceType.interactionRestriction => (
        l10n.noticesRestrictionTitle,
        l10n.noticesRestrictionEffect,
      ),
      OwnConsequenceType.contentHide => (
        l10n.noticesHideTitle,
        l10n.noticesHideEffect,
      ),
      OwnConsequenceType.accountSuspension => (
        l10n.noticesSuspensionTitle,
        l10n.noticesSuspensionEffect,
      ),
    };
    return Card(
      key: Key('notice-${notice.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              notice.isActive ? l10n.noticesActive : l10n.noticesRemoved,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              l10n.noticesAppliedOn(format.format(notice.appliedAt.toLocal())),
            ),
            if (notice.contentKind case final kind?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(switch (kind) {
                'one_time' => l10n.noticesProject,
                'recurring' => l10n.noticesTavolo,
                _ => l10n.noticesResource,
              }),
              if (notice.contentTitle case final contentTitle?)
                Text(contentTitle),
            ],
            const SizedBox(height: AppSpacing.small),
            Text(effect),
            const SizedBox(height: AppSpacing.small),
            Text(
              l10n.noticesApplyReason,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SelectableText(
              notice.applyReason,
              key: Key('notice-apply-reason-${notice.id}'),
            ),
            if (notice.revokedAt case final revoked?) ...[
              const SizedBox(height: AppSpacing.medium),
              Text(l10n.noticesRemovedOn(format.format(revoked.toLocal()))),
              Text(
                l10n.noticesRemoveReason,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SelectableText(
                notice.revokeReason!,
                key: Key('notice-remove-reason-${notice.id}'),
              ),
              Text(l10n.noticesRemovalEffect),
            ],
          ],
        ),
      ),
    );
  }
}

@Preview(name: 'Private notices EN', group: 'Moderation', size: Size(360, 720))
Widget ownNoticesEnglishPreview() => _preview(const Locale('en'));

@Preview(
  name: 'Avvisi privati IT / large text',
  group: 'Moderation',
  size: Size(320, 720),
)
Widget ownNoticesItalianPreview() =>
    _preview(const Locale('it'), largeText: true);

Widget _preview(Locale locale, {bool largeText = false}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
    child: child!,
  ),
  home: OwnConsequencesBody(
    state: OwnConsequenceState(
      phase: OwnHistoryPhase.ready,
      items: [
        OwnConsequence(
          id: '00000000-0000-4000-8000-000000000001',
          type: OwnConsequenceType.safetyNotice,
          isActive: false,
          appliedAtWire: '2026-10-01T12:00:00.123456Z',
          appliedAt: DateTime.utc(2026, 10, 1, 12),
          applyReason: 'Synthetic user-facing reason. Testo sintetico destinato alla persona interessata.',
          revokedAt: DateTime.utc(2026, 10, 2, 12),
          revokeReason:
              'Synthetic removal reason. Motivo sintetico della rimozione.',
        ),
      ],
    ),
  ),
);
