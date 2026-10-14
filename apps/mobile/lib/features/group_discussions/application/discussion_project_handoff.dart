import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';

/// Checks the current source before entering the independent canonical editor.
Future<DiscussionRoom> checkDiscussionProjectHandoff(
  DiscussionGateway gateway,
  String actor,
  DiscussionRoom source,
  bool Function() current,
) async {
  if (!current() || !source.canPublish || source.archived) {
    throw const PostgrestException(
      message: 'The discussion is unavailable.',
      code: '42501',
    );
  }
  final fresh = await gateway.room(actor, source.id);
  if (!current() ||
      fresh.id != source.id ||
      fresh.groupId != source.groupId ||
      fresh.admissionId != source.admissionId ||
      !fresh.canPublish ||
      fresh.archived) {
    throw const PostgrestException(
      message: 'The discussion is unavailable.',
      code: '42501',
    );
  }
  return fresh;
}
