import 'mock_models.dart';

abstract interface class MockRealmHandle {
  MockSelection get selection;
}

abstract interface class MockSessionAccess {
  String? get clientId;
  String? get normalIdentity;
  Stream<String?> get normalIdentityChanges;
  Stream<void> get dataInvalidations;
  Future<List<MockPersona>> catalog({String? expectedRoot});
  Future<MockRealmHandle> prepare(
    MockSelection selection, {
    bool storedOnly = false,
  });
  Future<void> activate(MockRealmHandle candidate);
  Future<void> suspend();
  Future<void> resume();
  Future<void> returnToNormal();
  Future<void> retire(MockSelection selection);
  Future<void> fullLogout();
  Future<bool> drain();
  Future<void> retainUncertain(int revision);
}
