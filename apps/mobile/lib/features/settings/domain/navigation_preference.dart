enum BottomTabDestination {
  messages('messages'),
  browse('browse');

  const BottomTabDestination(this.storageValue);

  final String storageValue;

  static BottomTabDestination fromStorage(String? value) => switch (value) {
    'browse' => BottomTabDestination.browse,
    _ => BottomTabDestination.messages,
  };
}

class NavigationPreferenceState {
  const NavigationPreferenceState({
    this.destination = BottomTabDestination.messages,
    this.restoreFailed = false,
  });

  final BottomTabDestination destination;
  final bool restoreFailed;
}
