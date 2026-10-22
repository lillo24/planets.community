import '../domain/co_creation_identity.dart';
import 'people_topic_picker.dart';
import '../application/people_attempt.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/people_private_gateway.dart';
import '../domain/people_private.dart';
import 'people_widgets.dart';

class PeopleOwnPostsScreen extends StatelessWidget {
  const PeopleOwnPostsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPeopleOwn,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleAccess(
            child: PeopleList<OwnPeoplePost>(
              load: (ref, actor, before) => ref
                  .read(peoplePrivateGatewayProvider)
                  .posts(actor!, before: before),
              row: (context, p, refresh) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(p.title),
                      Text(peopleStateLabel(l, p.state)),
                      if (p.suppressed) Text(l.coPeopleUnavailable),
                      Text(p.body),
                      Text(p.locality),
                      if (p.state != 'closed')
                        TextButton(
                          onPressed: () async {
                            await context.push('/people/compose', extra: p);
                            await refresh();
                          },
                          child: Text(l.coPeopleEdit),
                        ),
                      for (final operation in [
                        if (p.state == 'draft') 'publish',
                        if (p.state == 'open') 'close',
                        if (p.state != 'draft') 'renew',
                      ])
                        PeopleCommand(
                          slot: 'post/${p.id.value}',
                          rpc: 'mutate_cocreate_post',
                          intent: {
                            'p_operation': operation,
                            'p_post_id': p.id.value,
                            'p_expected_version': p.version,
                          },
                          label: switch (operation) {
                            'publish' => l.coPeoplePublish,
                            'close' => l.coPeopleClose,
                            _ => l.coPeopleRenew,
                          },
                          onSuccess: (_) => refresh(),
                        ),
                      TextButton(
                        onPressed: () => context.push(
                          '/messages/cocreate/requests',
                          extra: p.id,
                        ),
                        child: Text(l.coPeopleRequests),
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

/// Input stays on this route while auth/policy is pushed above it. Returning
/// never submits. A different established identity clears private input.
class PeopleComposerScreen extends ConsumerStatefulWidget {
  const PeopleComposerScreen({this.post, super.key});
  final OwnPeoplePost? post;
  @override
  ConsumerState<PeopleComposerScreen> createState() => _PeopleComposerState();
}

class _PeopleComposerState extends ConsumerState<PeopleComposerScreen> {
  final title = TextEditingController(),
      body = TextEditingController(),
      locality = TextEditingController();
  TopicId? topic;
  bool invalidated = false;
  @override
  void initState() {
    super.initState();
    topic = widget.post?.topicId;
    title.text = widget.post?.title ?? '';
    body.text = widget.post?.body ?? '';
    locality.text = widget.post?.locality ?? '';
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (
      prior,
      next,
    ) {
      if (prior != null && prior != next) {
        title.clear();
        body.clear();
        locality.clear();
        topic = null;
        if (widget.post != null) setState(() => invalidated = true);
      }
    });
    final l = AppLocalizations.of(context), p = widget.post;
    if (invalidated) {
      return PeoplePage(
        title: l.coPeopleOwn,
        child: Text(l.coPeopleUnavailable),
      );
    }
    final attempt = ref.watch(
      peopleAttemptsProvider,
    )[p == null ? 'post/create' : 'post/${p.id.value}'];
    final locked = attempt?.uncertain == true || attempt?.busy == true;
    return PeoplePage(
      title: l.coPeopleCompose,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coPeopleGuidance),
          TextField(
            controller: title,
            enabled: !locked,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.coPeopleTitle),
          ),
          TextField(
            controller: body,
            enabled: !locked,
            maxLength: 1000,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(labelText: l.coPeopleBody),
          ),
          TextField(
            controller: locality,
            enabled: !locked,
            maxLength: 100,
            decoration: InputDecoration(labelText: l.coPeopleLocality),
          ),
          PeopleTopicPicker(
            selected: topic,
            enabled: !locked,
            onChanged: (value) => setState(() => topic = value),
          ),
          PeopleAccess(
            child: ListenableBuilder(
              listenable: Listenable.merge([title, body, locality]),
              builder: (context, _) => PeopleCommand(
                slot: p == null ? 'post/create' : 'post/${p.id.value}',
                rpc: 'mutate_cocreate_post',
                intent: {
                  'p_operation': p == null ? 'create' : 'edit',
                  'p_post_id': p?.id.value,
                  'p_expected_version': p?.version,
                  'p_content': {
                    'title': title.text,
                    'body': body.text,
                    'locality': locality.text,
                    'topic_id': topic?.value,
                  },
                },
                label: l.coPeopleSave,
                onSuccess: (_) async {
                  title.clear();
                  body.clear();
                  locality.clear();
                  context.go('/people/mine');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
