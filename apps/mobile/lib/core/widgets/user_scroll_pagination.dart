import 'dart:async';

import 'package:flutter/material.dart';

/// One page per deliberate drag toward the edge, including its ballistic tail.
/// Layout, restoration and programmatic scrolling never authorize a request.
/// Failure pauses automatic loading until the screen's explicit Retry succeeds.
class UserScrollPagination extends StatefulWidget {
  const UserScrollPagination({
    required this.enabled,
    required this.onLoad,
    required this.builder,
    this.requestKey,
    this.towardStart = false,
    super.key,
  });

  final bool enabled;
  final Future<void> Function() onLoad;
  final Widget Function(BuildContext context, bool showFallback) builder;
  final Object? requestKey;
  final bool towardStart;

  @override
  State<UserScrollPagination> createState() => _UserScrollPaginationState();
}

class _UserScrollPaginationState extends State<UserScrollPagination> {
  bool _drag = false, _requested = false, _pending = false;
  bool _short = false;

  bool get _active =>
      mounted &&
      widget.enabled &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void didUpdateWidget(UserScrollPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey || !widget.enabled) {
      _drag = false;
    }
    if (oldWidget.requestKey != widget.requestKey) _short = false;
  }

  bool _scroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _drag = notification.dragDetails != null;
      _requested = false;
    }
    final delta = switch (notification) {
      ScrollUpdateNotification() => notification.scrollDelta ?? 0,
      OverscrollNotification() => notification.overscroll,
      _ => 0.0,
    };
    final approaching = widget.towardStart ? delta < 0 : delta > 0;
    final metrics = notification.metrics;
    final remaining = widget.towardStart
        ? metrics.extentBefore
        : metrics.extentAfter;
    if (_drag &&
        approaching &&
        remaining <= metrics.viewportDimension &&
        !_requested &&
        !_pending &&
        _active) {
      _requested = true;
      _pending = true;
      final key = widget.requestKey;
      scheduleMicrotask(() async {
        try {
          if (mounted && key == widget.requestKey && _active) {
            await widget.onLoad();
          }
        } finally {
          _pending = false;
        }
      });
    }
    if (notification is ScrollEndNotification) _drag = false;
    return false;
  }

  bool _metrics(ScrollMetricsNotification notification) {
    // Keep a short-content fallback stable while its own height changes layout.
    // A new query/page (requestKey) measures the new content afresh.
    if (notification.depth != 0 || !widget.enabled || _short) return false;
    final short =
        notification.metrics.maxScrollExtent <=
        notification.metrics.minScrollExtent + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _short != short) setState(() => _short = short);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _metrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _scroll,
          child: widget.builder(
            context,
            _short || MediaQuery.accessibleNavigationOf(context),
          ),
        ),
      );
}
