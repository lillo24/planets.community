/// Validates the pinned Realtime transport envelope separately from application
/// keys. The binary decoder's bounded metadata and optional delivery UUID carry
/// no application authority. Unknown fields (including personal data) fail.
Map<String, dynamic> privateBroadcastPayload(
  Object? value,
  String event,
  Set<String> keys,
) {
  Map<String, dynamic> object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid private broadcast object.');
    }
    return value.cast<String, dynamic>();
  }

  void exact(Map<String, dynamic> value, Set<String> keys) {
    if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected private broadcast shape.');
    }
  }

  final envelope = object(value);
  exact(envelope, {
    'type',
    'event',
    'payload',
    if (envelope.containsKey('meta')) 'meta',
  });
  if (envelope['type'] != 'broadcast' || envelope['event'] != event) {
    throw const FormatException('Unexpected private broadcast event.');
  }
  if (envelope.containsKey('meta')) {
    final meta = object(envelope['meta']);
    exact(meta, {'id', if (meta.containsKey('replayed')) 'replayed'});
    final id = meta['id'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        (meta.containsKey('replayed') && meta['replayed'] is! bool)) {
      throw const FormatException('Invalid private broadcast metadata.');
    }
  }
  final payload = object(envelope['payload']);
  exact(payload, {...keys, if (payload.containsKey('id')) 'id'});
  if (payload.containsKey('id') &&
      (payload['id'] is! String ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(payload['id'] as String))) {
    throw const FormatException('Invalid private broadcast delivery ID.');
  }
  return payload;
}
