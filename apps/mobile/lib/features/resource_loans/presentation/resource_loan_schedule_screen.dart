import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/presentation/messages_routes.dart';
import '../application/resource_loan_controllers.dart';
import '../domain/resource_loan_models.dart';

class ResourceLoanScheduleScreen extends ConsumerStatefulWidget {
  const ResourceLoanScheduleScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<ResourceLoanScheduleScreen> createState() =>
      _ResourceLoanScheduleScreenState();
}

class _ResourceLoanScheduleScreenState
    extends ConsumerState<ResourceLoanScheduleScreen>
    with WidgetsBindingObserver {
  String? _requestedIdentity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestedIdentity = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ownerId = _requestedIdentity;
    if (state == AppLifecycleState.resumed && ownerId != null) {
      ref
          .read(resourceLoanScheduleProvider.notifier)
          .handleAppResumed(ownerId, widget.listingId);
    }
  }

  Future<void> _load() async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null) return;
    _requestedIdentity = identity.id;
    await ref
        .read(resourceLoanScheduleProvider.notifier)
        .load(expectedOwnerProfileId: identity.id, listingId: widget.listingId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(resourceLoanScheduleProvider);
    if (identity != null && _requestedIdentity != identity.id) {
      _requestedIdentity = identity.id;
      Future<void>.microtask(_load);
    }
    final matches =
        state.expectedOwnerProfileId == identity?.id &&
        state.listingId == widget.listingId;
    final items = matches ? state.items : const <ResourceLoanReservation>[];
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.resourceLoanScheduleTitle)),
      body: SafeArea(
        child:
            identity == null ||
                !matches ||
                (state.phase == ResourceLoanPhase.loading && items.isEmpty)
            ? LoadingState(message: l10n.resourceLoading)
            : state.phase == ResourceLoanPhase.failure && items.isEmpty
            ? ErrorState(
                message: state.failure == ResourceLoanFailure.forbidden
                    ? l10n.resourceLoanScheduleForbidden
                    : l10n.resourceLoanScheduleUnavailable,
                onRetry: _load,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  itemCount: items.isEmpty ? 2 : items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.small),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.resourceLoanScheduleChronological),
                          if (state.phase == ResourceLoanPhase.failure) ...[
                            const SizedBox(height: AppSpacing.small),
                            Text(l10n.resourceLoanScheduleRefreshFailed),
                          ],
                        ],
                      );
                    }
                    if (items.isEmpty) {
                      return EmptyState(
                        title: l10n.resourceLoanScheduleEmptyTitle,
                        message: l10n.resourceLoanScheduleEmptyMessage,
                        icon: Icons.event_available_outlined,
                      );
                    }
                    return _ReservationCard(reservation: items[index - 1]);
                  },
                ),
              ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});

  final ResourceLoanReservation reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale);
    final time = DateFormat.Hm(locale);
    String format(DateTime value) {
      final local = value.toLocal();
      return '${date.format(local)}, ${time.format(local)}';
    }

    final period = l10n.resourceLoanSchedulePeriod(
      format(reservation.startsAt),
      format(reservation.endsAt),
    );
    final lifecycle = switch (reservation.agreementLifecycle) {
      ResourceLoanLifecycle.agreed => l10n.resourceLoanTermsAgreed,
      ResourceLoanLifecycle.inProgress => l10n.resourceLoanExchangeInProgress,
    };
    return Semantics(
      label: l10n.resourceLoanScheduleRowSemantics(
        reservation.requesterDisplayName,
        period,
        lifecycle,
      ),
      child: Card(
        key: Key('resource-loan-${reservation.agreementId}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.requesterDisplayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(l10n.resourceLoanStart(format(reservation.startsAt))),
              Text(l10n.resourceLoanExpectedReturn(format(reservation.endsAt))),
              Text(lifecycle),
              if (reservation.isOverdue) ...[
                const SizedBox(height: AppSpacing.small),
                Text(l10n.resourceLoanReturnOverdue),
                Text(l10n.resourceLoanReturnOverdueExplanation),
              ],
              if (reservation.isAtRisk) ...[
                const SizedBox(height: AppSpacing.small),
                Text(l10n.resourceLoanAtRisk),
                Text(l10n.resourceLoanAtRiskExplanation),
                Text(l10n.resourceLoanAtRiskStillValid),
              ],
              const SizedBox(height: AppSpacing.small),
              OutlinedButton(
                key: Key('resource-loan-open-${reservation.requestId}'),
                onPressed: () => context.push(
                  resourceRequestMessageRoute(reservation.requestId),
                ),
                child: Text(l10n.resourceLoanOpenRequest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
