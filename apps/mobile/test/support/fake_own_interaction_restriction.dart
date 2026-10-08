import 'package:planets_mobile/features/moderation/data/own_interaction_restriction_gateway.dart';

class FakeOwnInteractionRestrictionGateway
    implements OwnInteractionRestrictionGateway {
  bool active = false;
  Object? error;
  Future<bool>? pending;
  final identities = <String>[];

  @override
  Future<bool> isActive(String expectedProfileId) async {
    identities.add(expectedProfileId);
    if (pending case final future?) return future;
    if (error case final failure?) throw failure;
    return active;
  }
}
