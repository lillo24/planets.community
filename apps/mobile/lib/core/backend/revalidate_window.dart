/// Revalidates the entire visible keyset range, using fresh cursors from the
/// head. A head-page merge alone cannot detect revoked/deleted older rows.
/// Publication is atomic: later page failure leaves the confirmed snapshot.
Future<({List<T> items, bool hasMore})?> revalidateWindow<T>({
  required List<T> previous,
  required Future<({List<T> items, bool hasMore})> Function(T? after) fetch,
  required int Function(T a, T b) compare,
  required String Function(T item) id,
  required Object Function(T item) value,
  required bool Function() isCurrent,
}) async {
  final result = <T>[];
  final known = <String>{};
  final old = {for (final item in previous) id(item): item};
  T? cursor;
  while (true) {
    final page = await fetch(cursor);
    if (!isCurrent()) return null;
    for (final item in page.items) {
      if (!known.add(id(item))) continue;
      final cached = old[id(item)];
      result.add(
        cached != null && value(cached) == value(item) ? cached : item,
      );
    }
    if (page.hasMore &&
        (page.items.isEmpty ||
            (cursor != null && compare(page.items.last, cursor) <= 0))) {
      throw const FormatException('Revalidation cursor did not advance.');
    }
    if (!page.hasMore ||
        previous.isEmpty ||
        compare(page.items.last, previous.last) >= 0) {
      final unchanged =
          result.length == previous.length &&
          Iterable<int>.generate(result.length)
              .every((index) => identical(result[index], previous[index]));
      return (
        items: unchanged ? previous : List<T>.unmodifiable(result),
        hasMore: page.hasMore,
      );
    }
    cursor = page.items.last;
  }
}

/// Ordering used by canonical descending timestamp/kind/UUID keysets.
int compareDescendingKey(
  DateTime aTime,
  String aId,
  DateTime bTime,
  String bId, {
  int aKind = 0,
  int bKind = 0,
}) {
  final time = bTime.compareTo(aTime);
  if (time != 0) return time;
  final kind = bKind.compareTo(aKind);
  return kind != 0 ? kind : bId.compareTo(aId);
}
