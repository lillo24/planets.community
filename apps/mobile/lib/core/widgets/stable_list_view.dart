import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keyed, lazy rows retain their elements and visible anchor during canonical
/// revalidation. Unchanged immutable row values also retain their widgets.
class StableListView extends StatefulWidget {
  const StableListView({
    required this.rowIds,
    required this.rowValues,
    required this.itemBuilder,
    required this.storageKey,
    this.padding,
    super.key,
  }) : assert(rowIds.length == rowValues.length);

  final List<Object> rowIds;
  final List<Object?> rowValues;
  final IndexedWidgetBuilder itemBuilder;
  final Object storageKey;
  final EdgeInsetsGeometry? padding;

  @override
  State<StableListView> createState() => _StableListViewState();
}

class _StableListViewState extends State<StableListView> {
  var _controller = ScrollController();
  final _keys = <Object, GlobalKey>{};
  final _cache = <Object, (Object?, Widget)>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cache.clear();
  }

  @override
  void didUpdateWidget(StableListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) {
      final previous = _controller;
      _controller = ScrollController();
      _keys.clear();
      _cache.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      return;
    }
    if (!_controller.hasClients ||
        _controller.offset <= 1 ||
        _controller.position.isScrollingNotifier.value ||
        (listEquals(oldWidget.rowIds, widget.rowIds) &&
            listEquals(oldWidget.rowValues, widget.rowValues))) {
      return;
    }
    final viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    final anchors = <(Object, double)>[];
    for (final id in oldWidget.rowIds) {
      final box = _keys[id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y < bottom &&
          y + box.size.height > top &&
          widget.rowIds.contains(id)) {
        anchors.add((id, y));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      for (final (id, y) in anchors) {
        final box = _keys[id]?.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached || !box.hasSize) continue;
        final delta = box.localToGlobal(Offset.zero).dy - y;
        if (delta.abs() > 0.5) {
          _controller.jumpTo(
            (_controller.offset + delta).clamp(
              _controller.position.minScrollExtent,
              _controller.position.maxScrollExtent,
            ),
          );
        }
        break;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cache.removeWhere((id, _) => !widget.rowIds.contains(id));
    _keys.removeWhere((id, _) => !widget.rowIds.contains(id));
    final indices = {
      for (var i = 0; i < widget.rowIds.length; i++) widget.rowIds[i]: i,
    };
    return ListView.builder(
      key: PageStorageKey(widget.storageKey),
      controller: _controller,
      padding: widget.padding,
      itemCount: widget.rowIds.length,
      findChildIndexCallback: (key) =>
          key is ValueKey ? indices[key.value] : null,
      itemBuilder: (context, index) {
        final id = widget.rowIds[index];
        final value = widget.rowValues[index];
        final cached = _cache[id];
        final child = cached != null && cached.$1 == value
            ? cached.$2
            : widget.itemBuilder(context, index);
        _cache[id] = (value, child);
        return KeyedSubtree(
          key: ValueKey(id),
          child: KeyedSubtree(
            key: _keys.putIfAbsent(id, GlobalKey.new),
            child: child,
          ),
        );
      },
    );
  }
}
