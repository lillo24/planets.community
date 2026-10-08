import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_controller.dart';
import '../application/policy_acceptance_controller.dart';
import '../application/policy_documents.dart';

bool requirePolicyAcknowledgement(
  BuildContext context,
  WidgetRef ref,
  String returnTo,
) {
  if (ref
      .read(policyAcceptanceProvider)
      .allows(
        ref.read(authSessionProvider).identity?.id,
        ref.read(policyVersionProvider),
      )) {
    return true;
  }
  context.push(policyAcceptanceDestination(returnTo));
  return false;
}
