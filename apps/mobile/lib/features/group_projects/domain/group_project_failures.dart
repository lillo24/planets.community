import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Only this post-lock denial proves an atomic group creation was rejected.
/// Identity/transport/unknown failures retain the original recovery intent.
bool isGroupRepresentationRejection(Object error) {
  if (error is! PostgrestException || error.code != '42501') return false;
  Object? details = error.details;
  if (details is String) {
    try {
      details = jsonDecode(details);
    } on FormatException {
      return false;
    }
  }
  return details is Map &&
      details['reason'] == 'group_representation_unavailable';
}
