import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../settings/application/co_creation_preference_controller.dart';
import '../data/co_creation_examples.dart';

/// A separate preview tree: no gateway, mutation, ACK or canonical identity.
class DemoPage extends ConsumerWidget {
  const DemoPage({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(coCreationPreferenceProvider).enabled) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Text(
                  l.coCreationDemo,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(l.coCreationDemoNotice),
                const SizedBox(height: AppSpacing.medium),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoCreationDemoBrowseScreen extends ConsumerStatefulWidget {
  const CoCreationDemoBrowseScreen({super.key});
  @override
  ConsumerState<CoCreationDemoBrowseScreen> createState() => _BrowseState();
}

class _BrowseState extends ConsumerState<CoCreationDemoBrowseScreen> {
  final search = TextEditingController();
  bool hubs = false;
  String? topic;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final query = search.text.trim().toLowerCase();
    final posts = demoPosts.where(
      (p) =>
          (topic == null || topic == p.hubId) &&
          [
            p.title.inLanguage(language),
            p.body.inLanguage(language),
            p.locality,
          ].join(' ').toLowerCase().contains(query),
    );
    final communities = demoHubs.where(
      (h) =>
          (topic == null || topic == h.id) &&
          [
            h.title.inLanguage(language),
            h.locality,
          ].join(' ').toLowerCase().contains(query),
    );
    return DemoPage(
      title: l.coCreationTitle,
      children: [
        Wrap(
          spacing: AppSpacing.small,
          children: [
            ChoiceChip(
              label: Text(l.coCreationPosts),
              selected: !hubs,
              onSelected: (_) => setState(() => hubs = false),
            ),
            ChoiceChip(
              label: Text(l.coCreationHubs),
              selected: hubs,
              onSelected: (_) => setState(() => hubs = true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        TextField(
          key: const Key('co-creation-search'),
          controller: search,
          decoration: InputDecoration(
            labelText: l.coCreationSearch,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.small),
        DropdownButtonFormField<String>(
          key: ValueKey(topic),
          initialValue: topic,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(labelText: l.coCreationAllTopics),
          items: [
            DropdownMenuItem(value: null, child: Text(l.coCreationAllTopics)),
            for (final h in demoHubs)
              DropdownMenuItem(
                value: h.id,
                child: Text(h.title.inLanguage(language)),
              ),
          ],
          onChanged: (value) => setState(() => topic = value),
        ),
        if (!hubs)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('co-creation-compose'),
              onPressed: () => context.push('/people/demo/compose'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.coCreationCompose),
            ),
          ),
        if (hubs ? communities.isEmpty : posts.isEmpty) Text(l.coCreationEmpty),
        if (hubs)
          for (final h in communities)
            Card(
              child: ListTile(
                key: Key(h.id),
                title: Text(h.title.inLanguage(language)),
                subtitle: Text(h.locality),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/people/demo/hubs/${h.id}'),
              ),
            ),
        if (!hubs)
          for (final p in posts)
            Card(
              child: ListTile(
                key: Key(p.id),
                title: Text(p.title.inLanguage(language)),
                subtitle: Text(p.locality),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/people/demo/posts/${p.id}'),
              ),
            ),
      ],
    );
  }
}

class CoCreationDemoPostScreen extends StatelessWidget {
  const CoCreationDemoPostScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final p = demoPostById(id);
    return DemoPage(
      title: l.coCreationPosts,
      children: p == null
          ? [Text(l.coCreationUnknown)]
          : [
              Text(
                p.title.inLanguage(language),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(p.locality),
              const SizedBox(height: AppSpacing.medium),
              Text(p.body.inLanguage(language)),
            ],
    );
  }
}

class CoCreationDemoHubScreen extends StatelessWidget {
  const CoCreationDemoHubScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = demoHubById(id);
    return DemoPage(
      title:
          h?.title.inLanguage(Localizations.localeOf(context).languageCode) ??
          l.coCreationHubs,
      children: h == null
          ? [Text(l.coCreationUnknown)]
          : [
              Text(h.locality),
              Text(l.coCreationHubNotice),
              TextButton(
                key: const Key('demo-general'),
                onPressed: () => context.push('/people/demo/hubs/$id/general'),
                child: Text(l.coCreationGeneral),
              ),
              for (final number in [1, 2])
                Card(
                  child: ListTile(
                    key: Key('demo-group-$number'),
                    title: Text(l.coCreationGroup(number)),
                    subtitle: Text(
                      '${l.coCreationSeats(number == 1 ? 5 : 4, 5)}\n'
                      '${number == 1 ? l.coCreationFull : l.coCreationOneSeat}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/people/demo/hubs/$id/groups/$number'),
                  ),
                ),
            ],
    );
  }
}

class CoCreationDemoRoomScreen extends StatelessWidget {
  const CoCreationDemoRoomScreen({required this.hubId, this.number, super.key});
  final String hubId;
  final int? number;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = demoHubById(hubId);
    return DemoPage(
      title: number == null ? l.coCreationGeneral : l.coCreationGroup(number!),
      children: h == null || (number != null && number != 1 && number != 2)
          ? [Text(l.coCreationUnknown)]
          : [
              Text(
                '${h.title.inLanguage(Localizations.localeOf(context).languageCode)} · ${h.locality}',
              ),
              Text(l.coCreationRoomNotice),
              if (number != null)
                Text(l.coCreationSeats(number == 1 ? 5 : 4, 5)),
              Text(l.coCreationMessagesNotice),
            ],
    );
  }
}

class CoCreationDemoComposer extends ConsumerStatefulWidget {
  const CoCreationDemoComposer({super.key});
  @override
  ConsumerState<CoCreationDemoComposer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<CoCreationDemoComposer> {
  final title = TextEditingController();
  final body = TextEditingController();
  final locality = TextEditingController();
  bool preview = false;
  bool invalid = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Input belongs to the current identity even though no write exists.
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      title.clear();
      body.clear();
      locality.clear();
      setState(() {
        preview = false;
        invalid = false;
      });
    });
    final l = AppLocalizations.of(context);
    return DemoPage(
      title: l.coCreationCompose,
      children: [
        Text(l.coCreationGuidance),
        TextField(
          key: const Key('demo-post-title'),
          controller: title,
          maxLength: 120,
          decoration: InputDecoration(labelText: l.coCreationPostTitle),
          onChanged: (_) => setState(() => preview = false),
        ),
        TextField(
          key: const Key('demo-post-body'),
          controller: body,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: l.coCreationPostBody),
          onChanged: (_) => setState(() => preview = false),
        ),
        TextField(
          key: const Key('demo-post-locality'),
          controller: locality,
          maxLength: 100,
          decoration: InputDecoration(labelText: l.coCreationLocality),
          onChanged: (_) => setState(() => preview = false),
        ),
        if (invalid) Text(l.coCreationRequired),
        TextButton(
          key: const Key('demo-post-preview'),
          onPressed: () => setState(() {
            invalid = [title, body, locality].any((c) => c.text.trim().isEmpty);
            preview = !invalid;
          }),
          child: Text(l.coCreationPreview),
        ),
        if (preview)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.coCreationNotPublished),
                  Text(title.text.trim()),
                  Text(locality.text.trim()),
                  Text(body.text.trim()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
