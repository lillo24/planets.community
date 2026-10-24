import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/pagination_control.dart';
import '../../../core/widgets/user_scroll_pagination.dart';

/// Chronological lazy history with a fixed origin at the first rendered page.
/// Older entries grow above the center sliver, preserving the viewport even for
/// variable-height messages. No estimated-height jump or read-boundary change.
class ConversationHistoryList<T> extends StatefulWidget {
  const ConversationHistoryList({
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    required this.controller,
    required this.enabled,
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onLoadOlder,
    required this.fallbackLabel,
    required this.buttonKey,
    required this.empty,
    this.initialOriginKey,
    super.key,
  });

  final List<T> items;
  final Object Function(T) itemKey;
  final Widget Function(BuildContext, T) itemBuilder;
  final ScrollController controller;
  final bool enabled, hasMore, loading, failed;
  final Future<void> Function() onLoadOlder;
  final String fallbackLabel;
  final Key buttonKey;
  final Widget empty;

  /// Retained layout identity after an authorization scrub recreates the tree.
  /// It never retains message content; a missing authorized item resets to zero.
  final Object? initialOriginKey;

  @override
  State<ConversationHistoryList<T>> createState() =>
      _ConversationHistoryListState<T>();
}

class _ConversationHistoryListState<T>
    extends State<ConversationHistoryList<T>> {
  final _centerKey = GlobalKey();
  Object? _origin;

  @override
  Widget build(BuildContext context) {
    _origin ??= widget.initialOriginKey;
    var origin = widget.items.indexWhere(
      (item) => widget.itemKey(item) == _origin,
    );
    if (origin < 0) {
      origin = 0;
      _origin = widget.items.isEmpty
          ? null
          : widget.itemKey(widget.items.first);
    }
    Widget item(int index) => KeyedSubtree(
      key: ValueKey(widget.itemKey(widget.items[index])),
      child: widget.itemBuilder(context, widget.items[index]),
    );
    return UserScrollPagination(
      enabled:
          widget.enabled && widget.hasMore && !widget.loading && !widget.failed,
      requestKey: (_origin, widget.items.length),
      towardStart: true,
      onLoad: widget.onLoadOlder,
      builder: (context, showFallback) {
        final control = PaginationControl(
          loading: widget.loading,
          failed: widget.failed,
          showFallback: showFallback,
          onLoad: widget.onLoadOlder,
          fallbackLabel: widget.fallbackLabel,
          buttonKey: widget.buttonKey,
        );
        final scroll = CustomScrollView(
          controller: widget.controller,
          center: _centerKey,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: widget.hasMore && !showFallback
                  ? control
                  : const SizedBox.shrink(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              sliver: SliverList.builder(
                itemCount: origin,
                itemBuilder: (context, index) => item(origin - index - 1),
              ),
            ),
            SliverPadding(
              key: _centerKey,
              padding: const EdgeInsets.all(AppSpacing.medium),
              sliver: widget.items.isEmpty
                  ? SliverToBoxAdapter(child: widget.empty)
                  : SliverList.builder(
                      itemCount: widget.items.length - origin,
                      itemBuilder: (context, index) => item(origin + index),
                    ),
            ),
          ],
        );
        // A fallback above the zero-origin sliver would be outside a short
        // viewport. Keep deliberate accessibility controls visible above it.
        return showFallback && widget.hasMore
            ? Column(
                children: [
                  control,
                  Expanded(child: scroll),
                ],
              )
            : scroll;
      },
    );
  }
}
