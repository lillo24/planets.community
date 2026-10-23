import 'co_creation_identity.dart';
import 'people_post.dart';

String peopleUuid(Object? value) => PostId.parse(value).value;
String peopleText(Object? value, int maximum, {bool empty = true}) {
  if (value is! String ||
      value.runes.length > maximum ||
      (!empty && value.trim().isEmpty)) {
    throw const FormatException('Invalid co-creation text.');
  }
  return value;
}

int peopleCount(Object? value, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw const FormatException('Invalid co-creation count.');
  }
  return value;
}

bool peopleBool(Object? value) {
  if (value is! bool) throw const FormatException('Invalid co-creation flag.');
  return value;
}

String peopleState(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid co-creation state.');
  }
  return value;
}

class OwnPeoplePost {
  OwnPeoplePost.parse(Object? value) {
    final r = coCreationObject(value, {
      'post_id',
      'title',
      'body',
      'locality',
      'topic_id',
      'state',
      'version',
      'suppressed',
      'created_at',
      'expires_at',
    });
    id = PostId.parse(r['post_id']);
    title = peopleText(r['title'], 120);
    body = peopleText(r['body'], 1000);
    locality = peopleText(r['locality'], 100);
    topicId = r['topic_id'] == null ? null : TopicId.parse(r['topic_id']);
    state = peopleState(r['state'], {'draft', 'open', 'closed'});
    version = peopleCount(r['version'], minimum: 1);
    suppressed = peopleBool(r['suppressed']);
    createdAt = coCreationDate(r['created_at']);
    expiresAt = r['expires_at'] == null
        ? null
        : coCreationDate(r['expires_at']);
  }
  late final PostId id;
  late final String title, body, locality, state;
  late final TopicId? topicId;
  late final int version;
  late final bool suppressed;
  late final DateTime createdAt;
  late final DateTime? expiresAt;
  PeoplePostCursor get cursor => PeoplePostCursor(createdAt, id);
}

class PeopleInterest {
  PeopleInterest.parse(Object? value) {
    final r = coCreationObject(value, {
      'interest_id',
      'post_id',
      'post_title',
      'requester_id',
      'note',
      'state',
      'created_at',
      'contact_id',
    });
    id = peopleUuid(r['interest_id']);
    postId = PostId.parse(r['post_id']);
    postTitle = peopleText(r['post_title'], 120, empty: false);
    requesterId = peopleUuid(r['requester_id']);
    note = peopleText(r['note'], 500);
    state = peopleState(r['state'], {
      'pending',
      'accepted',
      'declined',
      'withdrawn',
    });
    createdAt = coCreationDate(r['created_at']);
    contactId = r['contact_id'] == null ? null : peopleUuid(r['contact_id']);
    if (state == 'accepted' && contactId == null) {
      throw const FormatException('Accepted interest has no contact.');
    }
  }
  late final String id, requesterId, note, state;
  late final PostId postId;
  late final String postTitle;
  late final String? contactId;
  late final DateTime createdAt;
}

class PeopleContact {
  PeopleContact.parse(Object? value) {
    final r = coCreationObject(value, {
      'contact_id',
      'post_id',
      'post_title',
      'created_at',
      'closed_at',
      'unread_count',
    });
    id = peopleUuid(r['contact_id']);
    postId = PostId.parse(r['post_id']);
    postTitle = peopleText(r['post_title'], 120, empty: false);
    createdAt = coCreationDate(r['created_at']);
    closedAt = r['closed_at'] == null ? null : coCreationDate(r['closed_at']);
    unread = peopleCount(r['unread_count']);
  }
  late final String id;
  late final PostId postId;
  late final String postTitle;
  late final DateTime createdAt;
  late final DateTime? closedAt;
  late final int unread;
}

class PeopleMessage {
  PeopleMessage.parse(Object? value) {
    final r = coCreationObject(value, {
      'message_id',
      'sender_id',
      'sequence',
      'body',
      'created_at',
    });
    id = peopleUuid(r['message_id']);
    senderId = peopleUuid(r['sender_id']);
    sequence = peopleCount(r['sequence'], minimum: 1);
    body = peopleText(r['body'], 2000, empty: false);
    createdAt = coCreationDate(r['created_at']);
  }
  late final String id, senderId, body;
  late final int sequence;
  late final DateTime createdAt;
}

class PeopleContactPage {
  PeopleContactPage.parse(
    Object? value,
    String actor,
    String contact,
    int? before,
  ) {
    final r = coCreationObject(value, {
      'profile_id',
      'contact_id',
      'closed',
      'messages',
      'read_token',
    });
    if (peopleUuid(r['profile_id']) != actor ||
        peopleUuid(r['contact_id']) != contact) {
      throw const FormatException('Contact identity mismatch.');
    }
    closed = peopleBool(r['closed']);
    final raw = r['messages'];
    if (raw is! List || raw.length > 30) {
      throw const FormatException('Invalid contact page.');
    }
    messages = List.unmodifiable(raw.map(PeopleMessage.parse));
    final ids = <String>{};
    int? sequence = before;
    for (final m in messages) {
      if (!ids.add(m.id) || (sequence != null && m.sequence >= sequence)) {
        throw const FormatException('Invalid message order.');
      }
      sequence = m.sequence;
    }
    final token = r['read_token'];
    if (before == null && messages.isNotEmpty && token == null) {
      throw const FormatException(
        'Newest contact page omitted its read receipt.',
      );
    }
    if (token != null &&
        (token is! String ||
            before != null ||
            messages.isEmpty ||
            !RegExp(r'^[0-9]{1,18}\.[0-9a-f]{64}$').hasMatch(token) ||
            token.split('.').first != messages.first.sequence.toString())) {
      throw const FormatException('Invalid rendered contact receipt.');
    }
    readToken = token as String?;
  }
  late final bool closed;
  late final List<PeopleMessage> messages;
  late final String? readToken;
}
