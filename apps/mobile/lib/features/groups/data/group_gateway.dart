import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/group_models.dart';

typedef GroupRpc = Future<Object?> Function(
  String name,
  Map<String, dynamic> params,
);

class GroupGateway {
  const GroupGateway(this.rpc);
  final GroupRpc rpc;
  List<T> rows<T>(Object? value, T Function(Map<String, dynamic>) parse) {
    if (value is! List) throw const FormatException('Malformed group result.');
    return List.unmodifiable(value.map((row) => parse(groupRow(row))));
  }

  T? single<T>(Object? value, T Function(Map<String, dynamic>) parse) {
    final result = rows(value, parse);
    if (result.length > 1) throw const FormatException('Multiple group rows.');
    return result.singleOrNull;
  }

  Map<String, dynamic> page(GroupCursor? cursor) => {
    'p_limit': 25,
    'p_before_created_at': null,
    'p_before_id': null,
    ...?cursor?.params,
  };
  Future<List<PublicGroup>> publicPage(
    GroupFilters filters,
    GroupCursor? cursor,
  ) async => rows(
    await rpc('list_public_groups', {...filters.params, ...page(cursor)}),
    PublicGroup.new,
  );
  Future<PublicGroup?> publicDetail(String id) async => single(
    await rpc('get_public_group', {'p_group_id': groupUuid(id)}),
    PublicGroup.new,
  );
  Future<List<OwnGroup>> ownPage(String actor, GroupCursor? cursor) async =>
      rows(
        await rpc('list_own_groups', {
          'p_expected_profile_id': groupUuid(actor),
          ...page(cursor),
        }),
        OwnGroup.new,
      );
  Future<OwnGroup> ownDetail(String actor, String id) async {
    final result = single(
      await rpc('get_own_group', {
        'p_expected_profile_id': groupUuid(actor),
        'p_group_id': groupUuid(id),
      }),
      OwnGroup.new,
    );
    if (result == null) throw const FormatException('Missing protected group.');
    return result;
  }

  Future<GroupReceipt?> recover(String actor, String key) async => single(
    await rpc('recover_group_command', {
      'p_expected_profile_id': groupUuid(actor),
      'p_client_request_id': groupUuid(key),
    }),
    GroupReceipt.new,
  );
  Future<String> create(String actor, String key, GroupContent content) async =>
      groupUuid(
        await rpc('create_group_draft', {
          'p_expected_profile_id': groupUuid(actor),
          'p_client_request_id': groupUuid(key),
          'p_content': content.toJson(),
        }),
      );
  Future<int> update(
    String actor,
    String id,
    String key,
    int version,
    GroupContent content,
  ) async => groupVersion(
    await rpc('update_group', {
      'p_expected_profile_id': groupUuid(actor),
      'p_group_id': groupUuid(id),
      'p_client_request_id': groupUuid(key),
      'p_expected_version': groupVersion(version),
      'p_content': content.toJson(),
    }),
  );
  Future<int> publish(
    String actor,
    String id,
    String key,
    int version,
    GroupPublication state,
  ) async => groupVersion(
    await rpc('set_group_publication_state', {
      'p_expected_profile_id': groupUuid(actor),
      'p_group_id': groupUuid(id),
      'p_client_request_id': groupUuid(key),
      'p_expected_version': groupVersion(version),
      'p_publication_state': state.name,
    }),
  );
}

final groupGatewayProvider = Provider<GroupGateway>((ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return GroupGateway((name, params) async => client.rpc(name, params: params));
});
