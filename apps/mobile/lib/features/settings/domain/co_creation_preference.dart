enum CoCreationMode {
  off('off'),
  on('on');

  const CoCreationMode(this.storageValue);
  final String storageValue;

  static CoCreationMode fromStorage(String? value) => value == 'on' ? on : off;
}

class CoCreationPreferenceState {
  const CoCreationPreferenceState({
    this.mode = CoCreationMode.off,
    this.restoreFailed = false,
  });

  final CoCreationMode mode;
  final bool restoreFailed;
  bool get enabled => mode == CoCreationMode.on;
}
