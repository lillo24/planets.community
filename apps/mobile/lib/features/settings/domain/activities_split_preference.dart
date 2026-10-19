enum ActivitiesSplitMode {
  off('off'),
  on('on');

  const ActivitiesSplitMode(this.storageValue);
  final String storageValue;

  static ActivitiesSplitMode fromStorage(String? value) =>
      value == 'on' ? on : off;
}

class ActivitiesSplitPreferenceState {
  const ActivitiesSplitPreferenceState({
    this.mode = ActivitiesSplitMode.off,
    this.restoreFailed = false,
  });

  final ActivitiesSplitMode mode;
  final bool restoreFailed;
  bool get enabled => mode == ActivitiesSplitMode.on;
}
