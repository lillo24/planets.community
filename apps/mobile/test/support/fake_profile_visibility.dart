import 'package:planets_mobile/features/profile/data/profile_visibility_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';

class FakeProfileVisibilityGateway implements ProfileVisibilityGateway {
  Map<ProfileFieldKey, ProfileAudience> values = {
    ProfileFieldKey.displayName: ProfileAudience.private,
    ProfileFieldKey.bio: ProfileAudience.public,
    ProfileFieldKey.skills: ProfileAudience.private,
  };
  Future<Map<ProfileFieldKey, ProfileAudience>> Function(String)? onLoad;
  Future<void> Function()? onUpdate;
  Object? loadError, updateError;
  final writes = <(String, ProfileFieldKey, ProfileAudience)>[];
  final loads = <String>[];

  @override
  Future<Map<ProfileFieldKey, ProfileAudience>> load(String id) async {
    loads.add(id);
    if (onLoad case final load?) return load(id);
    if (loadError case final error?) throw error;
    return Map.unmodifiable(values);
  }

  @override
  Future<void> update(
    String id,
    ProfileFieldKey field,
    ProfileAudience audience,
  ) async {
    writes.add((id, field, audience));
    if (onUpdate case final update?) await update();
    if (updateError case final error?) throw error;
    values = {...values, field: audience};
  }
}
