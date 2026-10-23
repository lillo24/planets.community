/// Common delivery boundary only. Each domain gateway validates its own exact
/// receipt; this interface grants no audience, admission or lifecycle authority.
abstract interface class CoCreationCommandGateway {
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> parameters,
  );
}
