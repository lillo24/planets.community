import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_controller.dart';

/// Removes a secret-bearing overlay when its account or originating route changes.
class ProjectContextDialog extends ConsumerStatefulWidget {
  const ProjectContextDialog({
    required this.account,
    required this.destination,
    required this.child,
    this.onInvalidated,
    super.key,
  });
  final String? account;
  final String destination;
  final Widget child;
  final VoidCallback? onInvalidated;
  @override
  ConsumerState<ProjectContextDialog> createState() =>
      _ProjectContextDialogState();
}

class _ProjectContextDialogState extends ConsumerState<ProjectContextDialog> {
  GoRouter? _routing;
  bool _invalid = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routing = GoRouter.of(context);
    if (_routing != routing) {
      _routing?.routerDelegate.removeListener(_checkRoute);
      _routing = routing;
      routing.routerDelegate.addListener(_checkRoute);
    }
  }

  void _checkRoute() {
    if (_routing?.state.uri.path != widget.destination) _invalidate();
  }

  void _invalidate() {
    if (_invalid) return;
    _invalid = true;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onInvalidated?.call();
      if (route?.isActive == true && route?.navigator?.mounted == true) {
        route!.navigator!.removeRoute(route);
      }
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _routing?.routerDelegate.removeListener(_checkRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => s.identity?.id),
      (_, _) => _invalidate(),
    );
    return _invalid ? const SizedBox.shrink() : widget.child;
  }
}
