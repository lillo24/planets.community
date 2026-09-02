import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double xLarge = 32;
}

abstract final class AppRadii {
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(20));
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double expanded = 840;
}
