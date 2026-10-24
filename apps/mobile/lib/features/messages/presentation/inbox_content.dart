import 'dart:async';

import 'package:flutter/material.dart';

/// Presentation results from the existing loaders, never another data fetch.
enum InboxContent { pending, empty, present, failure, inapplicable }

/// One mounted tab/scope owns this registry. The caller keys it by actor, realm
/// and scope; it contains no domain rows and is discarded with that identity.
class InboxContentController extends ChangeNotifier {
  final _sources = <Object, (InboxContent, Future<void> Function()?)>{};
  bool _scheduled = false, _disposed = false, _settled = false;

  bool get isEmpty =>
      _settled &&
      _sources.isNotEmpty &&
      _sources.values.every(
        (s) => s.$1 == InboxContent.empty || s.$1 == InboxContent.inapplicable,
      );

  void update(
    Object source,
    InboxContent content,
    Future<void> Function()? refresh,
  ) {
    final old = _sources[source];
    _sources[source] = (content, refresh);
    if (old?.$1 != content) _notifyAfterBuild();
  }

  void remove(Object source) {
    if (_sources.remove(source) != null) _notifyAfterBuild();
  }

  Future<void> refresh() async {
    await Future.wait([
      for (final source in _sources.values.toList())
        if (source.$2 != null) source.$2!(),
    ]);
  }

  void _notifyAfterBuild() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      _scheduled = false;
      _settled = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sources.clear();
    super.dispose();
  }
}

class InboxContentScope extends StatefulWidget {
  const InboxContentScope({required this.child, super.key});
  final Widget child;

  static InboxContentController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_InboxContentScope>()
      ?.controller;

  static Future<void> refresh(BuildContext context) async {
    await maybeOf(context)?.refresh();
  }

  @override
  State<InboxContentScope> createState() => _InboxContentScopeState();
}

class _InboxContentScopeState extends State<InboxContentScope> {
  final controller = InboxContentController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _InboxContentScope(controller: controller, child: widget.child);
}

class _InboxContentScope extends InheritedWidget {
  const _InboxContentScope({required this.controller, required super.child});
  final InboxContentController controller;
  @override
  bool updateShouldNotify(_InboxContentScope oldWidget) =>
      controller != oldWidget.controller;
}

/// A loader reports its actual state through its existing rebuilds. Sources
/// mount/unmount with applicability; a failed or pending source cannot be empty.
class InboxSource extends StatefulWidget {
  const InboxSource({
    required this.content,
    required this.child,
    this.onRefresh,
    super.key,
  });
  final InboxContent content;
  final Widget child;
  final Future<void> Function()? onRefresh;
  @override
  State<InboxSource> createState() => _InboxSourceState();
}

class _InboxSourceState extends State<InboxSource> {
  InboxContentController? controller;
  final source = Object();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = InboxContentScope.maybeOf(context);
    if (next != controller) controller?.remove(source);
    controller = next;
    _update();
  }

  @override
  void didUpdateWidget(InboxSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() =>
      controller?.update(source, widget.content, widget.onRefresh);
  @override
  void dispose() {
    controller?.remove(source);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class InboxEmpty extends StatelessWidget {
  const InboxEmpty({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final controller = InboxContentScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          controller.isEmpty ? child : const SizedBox.shrink(),
    );
  }
}
