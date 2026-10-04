import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Presents existing request actions while retaining the public detail destination.
class OrdinaryShareIntent extends StatefulWidget {
  const OrdinaryShareIntent({
    required this.enabled,
    required this.detailDestination,
    required this.request,
    required this.child,
    super.key,
  });
  final bool enabled;
  final String detailDestination;
  final Widget request;
  final Widget child;
  @override
  State<OrdinaryShareIntent> createState() => _OrdinaryShareIntentState();
}

class _OrdinaryShareIntentState extends State<OrdinaryShareIntent> {
  bool _shown = false;
  GoRouter? _routing;
  ModalRoute<void>? _overlay;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routing = GoRouter.of(context);
    if (_routing != routing) {
      _routing?.routerDelegate.removeListener(_navigationChanged);
      _routing = routing;
      routing.routerDelegate.addListener(_navigationChanged);
    }
  }

  @override
  void didUpdateWidget(covariant OrdinaryShareIntent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailDestination != widget.detailDestination ||
        (!oldWidget.enabled && widget.enabled)) {
      _shown = false;
    }
  }

  void _navigationChanged() {
    if (_routing?.state.uri.path == widget.detailDestination) return;
    final route = _overlay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true && route?.navigator?.mounted == true) {
        route!.navigator!.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _routing?.routerDelegate.removeListener(_navigationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled && !_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _routing?.state.uri.path != widget.detailDestination) {
          return;
        }
        final l10n = AppLocalizations.of(context);
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) {
            _overlay = ModalRoute.of(sheetContext);
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.participationRequestToJoin,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    Text(l10n.ordinaryShareIntentMessage),
                    widget.request,
                    TextButton(
                      key: const Key('ordinary-share-intent-close'),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(l10n.projectShareClose),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        _overlay = null;
        if (mounted &&
            context.mounted &&
            _routing?.state.uri.path == widget.detailDestination) {
          context.replace(widget.detailDestination);
        }
      });
    }
    return widget.child;
  }
}
