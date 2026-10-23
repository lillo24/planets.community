import 'co_creation_identity.dart';
import 'co_creation_rooms.dart';
import 'people_post.dart';
import 'people_private.dart';

String coCategoryId(Object? value) {
  final id = peopleText(value, 31, empty: false);
  if (!RegExp(r'^[a-z][a-z_]{1,30}$').hasMatch(id)) {
    throw const FormatException('Invalid co-creation category.');
  }
  return id;
}

class CoCategory {
  CoCategory.parse(Object? value) {
    final r = coCreationObject(value, {
      'category_id',
      'label_en',
      'label_it',
      'icon',
      'sort_order',
    });
    id = coCategoryId(r['category_id']);
    english = peopleText(r['label_en'], 60, empty: false);
    italian = peopleText(r['label_it'], 60, empty: false);
    icon = peopleState(r['icon'], {
      'games',
      'concerts',
      'sports',
      'travel',
      'art',
      'other',
    });
    order = peopleCount(r['sort_order']);
  }
  late final String id, english, italian, icon;
  late final int order;
  String label(String language) => language == 'it' ? italian : english;
}

class CoCommunityProposal {
  CoCommunityProposal.parse(Object? value) {
    final r = coCreationObject(value, {
      'proposal_id',
      'category_id',
      'name',
      'locality',
      'explanation',
      'state',
      'interested_count',
      'activation_threshold',
      'hub_id',
      'version',
      'created_at',
      'expires_at',
    });
    id = peopleUuid(r['proposal_id']);
    category = coCategoryId(r['category_id']);
    name = peopleText(r['name'], 80, empty: false);
    locality = peopleText(r['locality'], 100, empty: false);
    explanation = peopleText(r['explanation'], 500);
    state = peopleState(r['state'], {
      'pending',
      'activated',
      'cancelled',
      'rejected',
      'expired',
    });
    interested = peopleCount(r['interested_count']);
    threshold = coPositive(r['activation_threshold']);
    version = coPositive(r['version']);
    hub = r['hub_id'] == null ? null : HubId.parse(r['hub_id']);
    createdAt = coCreationDate(r['created_at']);
    expiresAt = coCreationDate(r['expires_at']);
    if (threshold < 3 ||
        threshold > 10 ||
        !expiresAt.isAfter(createdAt) ||
        (state == 'activated') != (hub != null)) {
      throw const FormatException('Inconsistent community proposal.');
    }
  }
  late final String id, category, name, locality, explanation, state;
  late final int interested, threshold, version;
  late final HubId? hub;
  late final DateTime createdAt, expiresAt;
}

class CoCommunityEntry {
  CoCommunityEntry.parse(Object? value, String expectedCategory) {
    final r = coCreationObject(value, {
      'category_id',
      'kind',
      'hub',
      'proposal',
    });
    if (coCategoryId(r['category_id']) != expectedCategory) {
      throw const FormatException('Foreign community category.');
    }
    final kind = peopleState(r['kind'], {'hub', 'proposal'});
    hub = r['hub'] == null ? null : PublicCoHub.parse(r['hub']);
    proposal = r['proposal'] == null
        ? null
        : CoCommunityProposal.parse(r['proposal']);
    if ((kind == 'hub') != (hub != null) ||
        (kind == 'proposal') != (proposal != null) ||
        proposal != null && proposal!.category != expectedCategory) {
      throw const FormatException('Invalid community entry.');
    }
  }
  late final PublicCoHub? hub;
  late final CoCommunityProposal? proposal;
  String get id => hub?.id.value ?? proposal!.id;
  DateTime get createdAt => hub?.createdAt ?? proposal!.createdAt;
}

class CoOwnCommunityInterest {
  CoOwnCommunityInterest.parse(Object? value) {
    final r = coCreationObject(value, {
      'proposal',
      'is_proposer',
      'interested',
      'ready_to_join',
    });
    proposal = CoCommunityProposal.parse(r['proposal']);
    isProposer = peopleBool(r['is_proposer']);
    interested = peopleBool(r['interested']);
    ready = peopleBool(r['ready_to_join']);
    if (ready != (interested && proposal.state == 'activated')) {
      throw const FormatException('Invalid community invitation.');
    }
  }
  late final CoCommunityProposal proposal;
  late final bool isProposer, interested, ready;
}
