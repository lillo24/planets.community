import '../../auth/application/auth_session_controller.dart';
import 'people_topic_picker.dart';
import '../application/people_attempt.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../data/people_posts_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';
import 'people_widgets.dart';
import 'co_creation_event_widgets.dart';

class PeopleBrowseScreen extends ConsumerStatefulWidget {
  const PeopleBrowseScreen({super.key});
  @override
  ConsumerState<PeopleBrowseScreen> createState() => _PeopleBrowseScreenState();
}

class _PeopleBrowseScreenState extends ConsumerState<PeopleBrowseScreen> {
  final search = TextEditingController(), locality = TextEditingController();
  String query = '', place = '';
  TopicId? topic;
  @override
  void dispose() {
    search.dispose();
    locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPeopleLive,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton(
            onPressed: () => context.push('/people/demo'),
            child: Text(l.coPeopleDemo),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => context.go('/people/hubs'),
                child: Text(l.coCreationHubs),
              ),
              TextButton(
                onPressed: () => context.push('/people/compose'),
                child: Text(l.coPeopleCompose),
              ),
              TextButton(
                onPressed: () => context.push('/people/mine'),
                child: Text(l.coPeopleOwn),
              ),
            ],
          ),
          TextField(
            controller: search,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.coPeopleSearch),
          ),
          TextField(
            controller: locality,
            maxLength: 100,
            decoration: InputDecoration(labelText: l.coPeopleLocality),
          ),
          FilledButton(
            onPressed: () => setState(() {
              query = search.text.trim();
              place = locality.text.trim();
            }),
            child: Text(l.coPeopleSearch),
          ),
          PeopleTopicPicker(
            selected: topic,
            onChanged: (value) => setState(() => topic = value),
          ),
          PeopleList<PublicPeoplePost>(
            key: ValueKey((query, place, topic?.value)),
            private: false,
            load: (ref, actor, before) => ref
                .read(peoplePostsGatewayProvider)
                .page(
                  search: query,
                  locality: place,
                  topicId: topic,
                  cursor: before?.cursor,
                ),
            row: (context, p, refresh) => Card(
              child: ListTile(
                title: Text(p.title),
                subtitle: Text(p.locality),
                onTap: () async {
                  await context.push(CoCreationRoutes.post(p.id));
                  await refresh();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PeoplePostScreen extends ConsumerStatefulWidget {
  const PeoplePostScreen({required this.postId, super.key});
  final PostId postId;
  @override
  ConsumerState<PeoplePostScreen> createState() => _PeoplePostScreenState();
}

class _PeoplePostScreenState extends ConsumerState<PeoplePostScreen> {
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (
      prior,
      next,
    ) {
      if (prior != null && prior != next) note.clear();
    });
    final attempt = ref.watch(
      peopleAttemptsProvider,
    )['interest/${widget.postId.value}'];
    final locked = attempt?.pending == true || attempt?.busy == true;
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPeopleLive,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleList<PublicPeoplePost>(
            private: false,
            load: (ref, actor, before) async {
              final p = await ref
                  .read(peoplePostsGatewayProvider)
                  .detail(widget.postId);
              return p == null ? [] : [p];
            },
            row: (context, p, refresh) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(p.title, style: Theme.of(context).textTheme.headlineSmall),
                Text(p.locality),
                Text(p.body),
                CoPostEventReference(post: p.id),
                Text(l.coPeopleConsent),
                TextButton(
                  onPressed: () => ModerationRoutes.openReport(
                    context,
                    ModerationReportTarget(
                      kind: ModerationTargetKind.cocreatePost,
                      id: p.id.value,
                      label: p.title,
                    ),
                  ),
                  child: Text(l.coPeopleReport),
                ),
                PeopleAccess(
                  child: Column(
                    children: [
                      TextField(
                        controller: note,
                        enabled: !locked,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: l.coPeopleNote),
                      ),
                      ListenableBuilder(
                        listenable: note,
                        builder: (context, _) => PeopleCommand(
                          slot: 'interest/${p.id.value}',
                          rpc: 'mutate_cocreate_interest',
                          intent: {
                            'p_operation': 'request',
                            'p_post_id': p.id.value,
                            'p_note': note.text,
                          },
                          label: l.coPeopleInterest,
                          onSuccess: (_) async {
                            note.clear();
                            await context.push('/messages/cocreate/requests');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
