import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/people_posts_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';

class PeopleTopic {
  PeopleTopic.parse(Object? value) {
    final row = coCreationObject(value, {'topic_id', 'label'});
    id = TopicId.parse(row['topic_id']);
    label = peopleText(row['label'], 80, empty: false);
  }
  late final TopicId id;
  late final String label;
}

final peopleTopicsProvider = FutureProvider.autoDispose<List<PeopleTopic>?>((
  ref,
) async {
  final gateway = ref.watch(peoplePostsGatewayProvider);
  if (!await gateway.available()) return null;
  final raw = await gateway.rpc('list_cocreate_topics', {});
  if (raw is! List || raw.length > 100) {
    throw const FormatException('Invalid topic catalogue.');
  }
  final rows = raw.map(PeopleTopic.parse).toList(growable: false),
      ids = <String>{};
  for (final row in rows) {
    if (!ids.add(row.id.value)) {
      throw const FormatException('Duplicate curated topic.');
    }
  }
  return List.unmodifiable(rows);
});

class PeopleTopicPicker extends ConsumerWidget {
  const PeopleTopicPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final TopicId? selected;
  final void Function(TopicId?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref
        .watch(peopleTopicsProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(peopleTopicsProvider),
            child: Text(l.peopleError),
          ),
          data: (topics) {
            if (topics == null) return const SizedBox.shrink();
            return Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l.coCreationAllTopics),
                  selected: selected == null,
                  onSelected: enabled ? (_) => onChanged(null) : null,
                ),
                for (final topic in topics)
                  ChoiceChip(
                    label: Text(topic.label),
                    selected: selected?.value == topic.id.value,
                    onSelected: enabled ? (_) => onChanged(topic.id) : null,
                  ),
              ],
            );
          },
        );
  }
}
