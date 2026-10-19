import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Keeps every line of a large contact-action label on its colored background.
/// Shared by D, member contact and coordination without changing the app theme.
const contactFilledButtonStyle = ButtonStyle(
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: AppRadii.medium),
  ),
);
