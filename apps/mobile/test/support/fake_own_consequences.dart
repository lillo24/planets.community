import 'package:planets_mobile/features/moderation/data/own_consequence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/own_consequence_models.dart';

Map<String, dynamic> ownConsequenceRow(
  int id, {
  String type = 'safety_notice',
  bool active = true,
  String? contentKind,
}) => {
  'consequence_id': '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
  'consequence_type': type,
  'is_active': active,
  'applied_at': '2026-10-01T12:00:00.123456+00:00',
  'apply_reason': 'Synthetic reason <b>not markup</b> https://example.invalid',
  'revoked_at': active ? null : '2026-10-02T12:00:00.654321+00:00',
  'revoke_reason': active ? null : 'Synthetic removal reason',
  'content_kind': contentKind,
  'content_id': contentKind == null
      ? null
      : '00000000-0000-4000-8000-000000000099',
  'content_title': contentKind == null ? null : 'Synthetic owned content',
};

OwnConsequence ownConsequence(
  int id, {
  String type = 'safety_notice',
  bool active = true,
  String? contentKind,
}) => OwnConsequence.fromJson(
  ownConsequenceRow(id, type: type, active: active, contentKind: contentKind),
);

class FakeOwnConsequenceGateway implements OwnConsequenceGateway {
  final identities = <String>[];
  final cursors = <OwnConsequenceCursor?>[];
  OwnConsequencePage page = const OwnConsequencePage([], hasMore: false);
  Object? error;
  Future<OwnConsequencePage>? pending;

  @override
  Future<OwnConsequencePage> listOwn({
    required String expectedProfileId,
    OwnConsequenceCursor? cursor,
  }) async {
    identities.add(expectedProfileId);
    cursors.add(cursor);
    if (pending case final future?) return future;
    if (error case final failure?) throw failure;
    return page;
  }
}
