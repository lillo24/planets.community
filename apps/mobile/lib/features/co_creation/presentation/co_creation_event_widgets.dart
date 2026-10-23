import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/public_external_link.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../external_activities/domain/external_activity.dart';
import '../../external_activities/presentation/external_activity_widgets.dart';
import '../../settings/application/co_creation_preference_controller.dart';
import '../data/co_creation_events_gateway.dart';
import '../data/people_posts_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../application/people_signals.dart';
import 'people_widgets.dart';

final coCreationEventAvailabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  ref.watch(peopleSignalsProvider);
  return ref.watch(peoplePostsGatewayProvider).available();
});

/// Optional action on ACTAPI01's real public detail, independent from provider
/// importing and from any native event participation.
class CoEventPeopleAction extends ConsumerWidget {
  const CoEventPeopleAction({required this.item, super.key});
  final ExternalActivity item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(coCreationPreferenceProvider).enabled ||
        item.status != 'scheduled') {
      return const SizedBox.shrink();
    }
    return ref
        .watch(coCreationEventAvailabilityProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(coCreationEventAvailabilityProvider),
            child: Text(AppLocalizations.of(context).coPeopleError),
          ),
          data: (enabled) => !enabled
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () => context.push(
                    '/people/from-event/${item.id.toLowerCase()}',
                  ),
                  child: Text(AppLocalizations.of(context).coEventFindPeople),
                ),
        );
  }
}

class CoEventDraftContext extends StatelessWidget {
  const CoEventDraftContext({required this.event, super.key});
  final ExternalActivity event;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.coEventReview),
        Text(event.title),
        Text(l.activitiesSourceLabel(event.sourceName)),
        Text(event.attribution),
        if (event.stale) Text(l.activitiesExternalStaleRecord),
        for (final o in event.occurrences)
          Text(externalOccurrenceLabel(o, locale, l)),
      ],
    );
  }
}

class CoPostEventReference extends StatelessWidget {
  const CoPostEventReference({required this.post, super.key});
  final PostId post;
  @override
  Widget build(BuildContext context) => PeopleList<CoPublicEventReference>(
    key: ValueKey(post.value),
    private: false,
    emptyVisible: false,
    load: (ref, actor, before) async {
      final r = await ref.read(coCreationEventsGatewayProvider).reference(post);
      return r == null ? [] : [r];
    },
    row: (context, r, refresh) => _EventReference(reference: r),
  );
}

class _EventReference extends ConsumerWidget {
  const _EventReference({required this.reference});
  final CoPublicEventReference reference;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), r = reference;
    Future<void> open(PublicExternalLink link) async {
      final ok = await ref.read(publicExternalLinkLauncherProvider).open(link);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.activitiesLinkFailed)));
      }
    }

    if (!r.available) return Text(l.coEventUnavailable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.title!),
        Text(l.activitiesSourceLabel(r.source!)),
        Text(r.attribution!),
        if (r.status == 'cancelled') Text(l.activitiesExternalCancelled),
        if (r.stale!) Text(l.activitiesExternalStaleRecord),
        TextButton(
          onPressed: () => open(r.official!),
          child: Text(l.activitiesOfficialEvent),
        ),
        TextButton(
          onPressed: () => open(r.license!),
          child: Text(l.activitiesSourceLicense),
        ),
      ],
    );
  }
}
