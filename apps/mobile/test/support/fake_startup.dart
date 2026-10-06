import 'package:planets_mobile/app/startup/startup_flow.dart';

class FakeStartupStore implements StartupPreferenceStore {
  String? version;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  int resets = 0;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('test read unavailable');
    return version;
  }

  @override
  Future<void> complete(String value) async {
    writes++;
    if (failWrite) throw StateError('test write unavailable');
    version = value;
  }

  @override
  Future<void> reset() async {
    resets++;
    if (failWrite) throw StateError('test reset unavailable');
    version = null;
  }
}
