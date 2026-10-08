import 'package:supabase_flutter/supabase_flutter.dart';

/// Complete actor-bound owner reads despite PostgREST's response row cap.
/// Keyset paging orders the canonical UUID output; it does not change RPC/RLS.
Future<List<Map<String, dynamic>>> readOwnerCollection(
  SupabaseClient client,
  String rpc, {
  required Map<String, dynamic> params,
  required String idColumn,
  bool descendingIdTie = false,
}) async {
  final rows = await collectOwnerCollection(
    idColumn: idColumn,
    page: (after, limit) async {
      var query = client.rpc<List<dynamic>>(rpc, params: params);
      if (after != null) query = query.gt(idColumn, after);
      return (await query.order(idColumn).limit(limit))
          .cast<Map<String, dynamic>>();
    },
  );
  // Restore each owner endpoint's documented created-time presentation order.
  final ordered = List<Map<String, dynamic>>.of(rows);
  ordered.sort((a, b) {
    final date = DateTime.parse(b['created_at'] as String)
        .compareTo(DateTime.parse(a['created_at'] as String));
    if (date != 0) return date;
    final id = (a[idColumn] as String).compareTo(b[idColumn] as String);
    return descendingIdTie ? -id : id;
  });
  return List.unmodifiable(ordered);
}

/// The page size stays below the repository's configured 1,000-row API cap.
/// Failed or malformed later pages fail the whole read, never a partial success.
Future<List<Map<String, dynamic>>> collectOwnerCollection({
  required String idColumn,
  required Future<List<Map<String, dynamic>>> Function(String?, int) page,
}) async {
  const size = 200;
  final rows = <Map<String, dynamic>>[];
  String? after;
  while (true) {
    final batch = await page(after, size);
    if (batch.length > size) {
      throw const FormatException('Owner collection page exceeded its limit.');
    }
    for (final row in batch) {
      final id = row[idColumn];
      if (id is! String ||
          id.isEmpty ||
          (after != null && id.compareTo(after) <= 0)) {
        throw FormatException('Owner collection $idColumn did not advance.');
      }
      after = id;
      rows.add(row);
    }
    if (batch.length < size) return List.unmodifiable(rows);
  }
}
