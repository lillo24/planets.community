import 'co_creation_identity.dart';

Map<String, Object?> coCreationObject(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected co-creation payload.');
  }
  return value.cast<String, Object?>();
}

String _text(Object? value, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw const FormatException('Invalid public post text.');
  }
  return value;
}

DateTime coCreationDate(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('An absolute post timestamp is required.');
  }
  final result = DateTime.tryParse(value);
  if (result == null) throw const FormatException('Invalid post timestamp.');
  final parts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (parts == null) throw const FormatException('Invalid post timestamp.');
  final year = int.parse(parts[1]!);
  final month = int.parse(parts[2]!);
  final day = int.parse(parts[3]!);
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      int.parse(parts[4]!) > 23 ||
      int.parse(parts[5]!) > 59 ||
      int.parse(parts[6]!) > 59) {
    throw const FormatException('Invalid post timestamp components.');
  }
  final offset = parts[8]!;
  if (offset != 'Z' &&
      (int.parse(offset.substring(1, 3)) > 23 ||
          int.parse(offset.substring(4, 6)) > 59)) {
    throw const FormatException('Invalid post timestamp offset.');
  }
  return result.toUtc();
}

/// Deliberately excludes author identity, private notes, requests and contacts.
class PublicPeoplePost {
  PublicPeoplePost.parse(Object? value) {
    final row = coCreationObject(value, {
      'post_id',
      'title',
      'body',
      'locality',
      'topic_id',
      'created_at',
      'expires_at',
    });
    id = PostId.parse(row['post_id']);
    title = _text(row['title'], 120);
    body = _text(row['body'], 1000);
    locality = _text(row['locality'], 100);
    topicId = row['topic_id'] == null ? null : TopicId.parse(row['topic_id']);
    createdAt = coCreationDate(row['created_at']);
    expiresAt = coCreationDate(row['expires_at']);
    if (!expiresAt.isAfter(createdAt)) {
      throw const FormatException('Invalid post expiry interval.');
    }
  }
  late final PostId id;
  late final String title;
  late final String body;
  late final String locality;
  late final TopicId? topicId;
  late final DateTime createdAt;
  late final DateTime expiresAt;
  PeoplePostCursor get cursor => PeoplePostCursor(createdAt, id);
}

class PeoplePostCursor {
  const PeoplePostCursor(this.createdAt, this.id);
  final DateTime createdAt;
  final PostId id;
  Map<String, Object?> get parameters => {
    'p_before_created_at': createdAt.toUtc().toIso8601String(),
    'p_before_id': id.value,
  };
}
