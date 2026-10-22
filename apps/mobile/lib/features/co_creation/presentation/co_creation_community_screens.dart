import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../application/people_attempt.dart';
import '../data/co_creation_communities_gateway.dart';
import '../domain/co_creation_communities.dart';
import '../domain/co_creation_identity.dart';
import 'people_widgets.dart';

IconData coCategoryIcon(String icon) => switch (icon) {
  'games' => Icons.sports_esports_outlined,
  'concerts' => Icons.music_note_outlined,
  'sports' => Icons.directions_run,
  'travel' => Icons.travel_explore,
  'art' => Icons.palette_outlined,
  _ => Icons.interests_outlined,
};

class CoCommunityCategories extends StatelessWidget {
  const CoCommunityCategories({
    required this.search,
    required this.locality,
    super.key,
  });
  final String search, locality;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return PeopleList<CoCategory>(
      private: false,
      load: (ref, actor, before) async => before == null
          ? ref.read(coCreationCommunitiesGatewayProvider).categories()
          : [],
      row: (context, c, refresh) => Card(
        child: ExpansionTile(
          key: PageStorageKey('co-category-${c.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: largeText ? null : Icon(coCategoryIcon(c.icon)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (largeText) Icon(coCategoryIcon(c.icon)),
              Text(c.label(Localizations.localeOf(context).languageCode)),
            ],
          ),
          childrenPadding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 8,
            bottom: 8,
          ),
          children: [
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.coCommunityPropose),
              onPressed: () => context.push(
                Uri(
                  path: '/people/categories/${c.id}/propose',
                  queryParameters: {'locality': locality, 'name': search},
                ).toString(),
              ),
            ),
            PeopleList<CoCommunityEntry>(
              key: ValueKey((c.id, search, locality)),
              private: false,
              load: (ref, actor, before) => ref
                  .read(coCreationCommunitiesGatewayProvider)
                  .communities(
                    c.id,
                    search: search,
                    locality: locality,
                    before: before,
                  ),
              row: (context, entry, reload) => ListTile(
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 12,
                  end: 4,
                ),
                leading: Icon(
                  entry.hub == null
                      ? Icons.pending_outlined
                      : Icons.forum_outlined,
                ),
                title: Text(entry.hub?.topic ?? entry.proposal!.name),
                subtitle: Text(
                  entry.hub?.locality ??
                      '${entry.proposal!.locality} · ${l.coCommunityProposed} · ${l.coCommunityInterested(entry.proposal!.interested)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push(
                    entry.hub == null
                        ? '/people/community-proposals/${entry.proposal!.id}'
                        : CoCreationRoutes.hub(entry.hub!.id),
                  );
                  await reload();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoCommunityComposeScreen extends ConsumerStatefulWidget {
  const CoCommunityComposeScreen({
    required this.category,
    this.initialName = '',
    this.initialLocality = '',
    super.key,
  });
  final String category, initialName, initialLocality;
  @override
  ConsumerState<CoCommunityComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends ConsumerState<CoCommunityComposeScreen> {
  late final name = TextEditingController(text: widget.initialName);
  late final locality = TextEditingController(text: widget.initialLocality);
  final explanation = TextEditingController();
  Timer? debounce;
  String query = '', place = '';
  bool preview = false;
  @override
  void initState() {
    super.initState();
    final attempt = ref.read(
      peopleAttemptsProvider,
    )['community-propose/${widget.category}'];
    if (attempt?.pending == true) {
      name.text = attempt!.intent['p_name'] as String;
      locality.text = attempt.intent['p_locality'] as String;
      explanation.text = attempt.intent['p_explanation'] as String;
      preview = true;
    }
    name.addListener(changed);
    locality.addListener(changed);
    if (attempt?.pending != true) changed();
  }

  void changed() {
    debounce?.cancel();
    if (preview) setState(() => preview = false);
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          query = name.text.trim();
          place = locality.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    name.dispose();
    locality.dispose();
    explanation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slot = 'community-propose/${widget.category}';
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.identity?.id != null &&
          previous?.identity?.id != next.identity?.id) {
        debounce?.cancel();
        name.clear();
        locality.clear();
        explanation.clear();
        setState(() {
          preview = false;
          query = '';
          place = '';
        });
      }
    });
    final pending = ref.watch(peopleAttemptsProvider)[slot]?.pending == true;
    return PeoplePage(
      title: l.coCommunityPropose,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coCommunitySafety),
          TextField(
            controller: name,
            enabled: !pending,
            maxLength: 80,
            decoration: InputDecoration(labelText: l.coCommunityName),
          ),
          TextField(
            controller: locality,
            enabled: !pending,
            maxLength: 100,
            decoration: InputDecoration(labelText: l.coPeopleLocality),
          ),
          TextField(
            controller: explanation,
            enabled: !pending,
            maxLength: 500,
            maxLines: 4,
            onChanged: (_) {
              if (preview) setState(() => preview = false);
            },
            decoration: InputDecoration(labelText: l.coCommunityExplanation),
          ),
          if (query.length >= 2) ...[
            Text(l.coCommunityMatches),
            PeopleList<CoCommunityEntry>(
              key: ValueKey((query, place, widget.category)),
              private: false,
              load: (ref, actor, before) => ref
                  .read(coCreationCommunitiesGatewayProvider)
                  .communities(
                    widget.category,
                    search: query,
                    locality: place,
                    before: before,
                  ),
              row: (context, r, refresh) => ListTile(
                title: Text(r.hub?.topic ?? r.proposal!.name),
                subtitle: Text(r.hub?.locality ?? r.proposal!.locality),
                onTap: () => context.push(
                  r.hub != null
                      ? CoCreationRoutes.hub(r.hub!.id)
                      : '/people/community-proposals/${r.proposal!.id}',
                ),
              ),
            ),
          ],
          OutlinedButton(
            onPressed: pending ? null : () => setState(() => preview = true),
            child: Text(l.coCommunityPreview),
          ),
          if (preview || pending) ...[
            Text(
              name.text.trim(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(locality.text.trim()),
            Text(explanation.text.trim()),
            Text(l.coCommunityActivationNotice),
            PeopleAccess(
              child: PeopleCommand(
                slot: slot,
                rpc: 'propose_cocreate_community',
                gateway: (ref) =>
                    ref.read(coCreationCommunitiesGatewayProvider),
                intent: {
                  'p_category_id': widget.category,
                  'p_name': name.text,
                  'p_locality': locality.text,
                  'p_explanation': explanation.text,
                },
                label: l.coCommunityPropose,
                onSuccess: (r) async {
                  await context.push(
                    r['hub_id'] != null
                        ? CoCreationRoutes.hub(HubId.parse(r['hub_id']))
                        : '/people/community-proposals/${r['proposal_id']}',
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CoCommunityProposalScreen extends ConsumerStatefulWidget {
  const CoCommunityProposalScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<CoCommunityProposalScreen> createState() => _ProposalState();
}

class _ProposalState extends ConsumerState<CoCommunityProposalScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slot = 'community-interest/${widget.id}';
    final attempt = ref.watch(peopleAttemptsProvider)[slot];
    final pending = attempt?.pending == true;
    return PeoplePage(
      title: l.coCommunityProposed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleList<CoCommunityProposal>(
            key: ValueKey((widget.id, revision)),
            private: false,
            load: (ref, actor, before) async {
              final p = await ref
                  .read(coCreationCommunitiesGatewayProvider)
                  .proposal(widget.id);
              return p == null ? [] : [p];
            },
            row: (context, p, refresh) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(p.locality),
                Text(p.explanation),
                Text(l.coCommunityInterested(p.interested)),
                Text(l.coCommunityThreshold(p.threshold)),
                Text(l.coCommunityActivationNotice),
                if (p.hub != null) ...[
                  Text(l.coCommunityReady),
                  TextButton(
                    onPressed: () => context.push(CoCreationRoutes.hub(p.hub!)),
                    child: Text(l.coCommunityReviewJoin),
                  ),
                ],
                if (p.state == 'pending' && !pending)
                  PeopleAccess(
                    child: Column(
                      children: [
                        PeopleCommand(
                          slot: 'community-interest/${p.id}',
                          rpc: 'mutate_cocreate_community_interest',
                          gateway: (ref) =>
                              ref.read(coCreationCommunitiesGatewayProvider),
                          intent: {
                            'p_proposal_id': p.id,
                            'p_operation': 'interest',
                          },
                          label: l.coCommunityInterest,
                          onSuccess: (_) => refresh(),
                        ),
                        PeopleCommand(
                          slot: 'community-interest/${p.id}',
                          rpc: 'mutate_cocreate_community_interest',
                          gateway: (ref) =>
                              ref.read(coCreationCommunitiesGatewayProvider),
                          intent: {
                            'p_proposal_id': p.id,
                            'p_operation': 'withdraw',
                          },
                          label: l.coCommunityWithdraw,
                          onSuccess: (_) => refresh(),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(l.coPeopleReport),
                  onPressed: () => ModerationRoutes.openReport(
                    context,
                    ModerationReportTarget(
                      kind: ModerationTargetKind.cocreateCommunityProposal,
                      id: p.id,
                      label: p.name,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Recovery does not depend on the public proposal still being pending
          // or visible after a successful write whose reply was lost.
          if (pending)
            PeopleAccess(
              child: PeopleCommand(
                slot: slot,
                rpc: 'mutate_cocreate_community_interest',
                gateway: (ref) =>
                    ref.read(coCreationCommunitiesGatewayProvider),
                intent: Map<String, dynamic>.from(attempt!.intent),
                label: l.coPeopleRetry,
                onSuccess: (_) async => setState(() => revision++),
              ),
            ),
        ],
      ),
    );
  }
}

class CoCommunityInterestsScreen extends ConsumerWidget {
  const CoCommunityInterestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final attempts = ref.watch(peopleAttemptsProvider);
    return PeoplePage(
      title: l.coCommunityYourInterests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleAccess(
            child: PeopleList<CoOwnCommunityInterest>(
              load: (ref, actor, before) => ref
                  .read(coCreationCommunitiesGatewayProvider)
                  .own(actor!, before: before),
              row: (context, i, refresh) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        i.proposal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(i.proposal.locality),
                      Text(l.coCommunityInterested(i.proposal.interested)),
                      Text(l.coCommunityThreshold(i.proposal.threshold)),
                      if (i.ready) ...[
                        Text(l.coCommunityReady),
                        Text(l.coCommunityActivationNotice),
                        FilledButton(
                          onPressed: () => context.push(
                            CoCreationRoutes.hub(i.proposal.hub!),
                          ),
                          child: Text(l.coCommunityReviewJoin),
                        ),
                      ] else
                        Text(
                          i.proposal.state == 'pending'
                              ? l.coCommunityProposed
                              : l.coPeopleClosed,
                        ),
                      TextButton(
                        onPressed: () => context.push(
                          '/people/community-proposals/${i.proposal.id}',
                        ),
                        child: Text(l.coRecruitmentReview),
                      ),
                      if (attempts['community-interest/${i.proposal.id}']
                              ?.pending ==
                          true)
                        PeopleCommand(
                          slot: 'community-interest/${i.proposal.id}',
                          rpc: 'mutate_cocreate_community_interest',
                          gateway: (ref) =>
                              ref.read(coCreationCommunitiesGatewayProvider),
                          intent: Map<String, dynamic>.from(
                            attempts['community-interest/${i.proposal.id}']!
                                .intent,
                          ),
                          label: l.coPeopleRetry,
                          onSuccess: (_) => refresh(),
                        )
                      else if (i.isProposer && i.proposal.state == 'pending')
                        PeopleCommand(
                          slot: 'community-interest/${i.proposal.id}',
                          rpc: 'mutate_cocreate_community_interest',
                          gateway: (ref) =>
                              ref.read(coCreationCommunitiesGatewayProvider),
                          intent: {
                            'p_proposal_id': i.proposal.id,
                            'p_operation': 'cancel',
                          },
                          label: l.coCommunityCancel,
                          onSuccess: (_) => refresh(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
