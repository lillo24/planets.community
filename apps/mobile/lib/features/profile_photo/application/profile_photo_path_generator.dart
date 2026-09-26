import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

abstract interface class ProfilePhotoPathGenerator {
  String newPath(String profileId);
}

class UuidProfilePhotoPathGenerator implements ProfilePhotoPathGenerator {
  const UuidProfilePhotoPathGenerator([this._uuid = const Uuid()]);

  final Uuid _uuid;

  @override
  String newPath(String profileId) => '$profileId/${_uuid.v4()}.webp';
}

final profilePhotoPathGeneratorProvider = Provider<ProfilePhotoPathGenerator>(
  (ref) => const UuidProfilePhotoPathGenerator(),
);
