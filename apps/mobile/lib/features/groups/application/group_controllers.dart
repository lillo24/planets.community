import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/group_gateway.dart';
import '../domain/group_models.dart';

enum GroupFailure { stale, invalid, denied, prerequisite, setup, uncertain }

GroupFailure groupFailure(Object error) => switch (error) {
  PostgrestException(code: 'PT409') => GroupFailure.stale,
  PostgrestException(code: '22023') => GroupFailure.invalid,
  PostgrestException(code: '42501') => GroupFailure.denied,
  PostgrestException(code: '55000') => GroupFailure.prerequisite,
  PostgrestException(code: 'PGRST202') => GroupFailure.setup,
  _ => GroupFailure.uncertain,
};

/// Epoch invalidation retains rows on page failures and retries the same cursor.
class GroupPager<T extends PublicGroup> extends ChangeNotifier {
  GroupPager(this.fetch);
  final Future<List<T>> Function(GroupCursor?) fetch;
  List<T> rows = [];
  GroupCursor? cursor;
  bool busy = false, more = true, disposed = false;
  Object? error;
  int epoch = 0;
  Future<void> reset() {
    epoch++;
    rows = [];
    cursor = null;
    more = true;
    busy = false;
    error = null;
    return load();
  }

  Future<void> load() async {
    if (disposed || busy || !more) return;
    final token = epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetch(cursor);
      if (disposed || token != epoch) return;
      final ids = rows.map((row) => row.id).toSet();
      rows = [...rows, ...page.where((row) => ids.add(row.id))];
      if (page.isNotEmpty) cursor = page.last.cursor;
      more = page.length == 25;
    } catch (failure) {
      if (disposed || token != epoch) return;
      error = failure;
    } finally {
      if (!disposed && token == epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    epoch++;
    rows = [];
    cursor = null;
    more = false;
    busy = false;
    error = null;
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    super.dispose();
  }
}

class GroupCommand {
  GroupCommand({
    required this.key,
    required this.content,
    required this.id,
    required this.version,
    this.publication,
  });
  final String key;
  final GroupContent content;
  final String? id;
  final int? version;
  final GroupPublication? publication;
}

/// Pending requests live only in this editor. Lost replies never generate a new
/// create key; recovery reads a receipt, then reloads current protected content.
class GroupEditorController extends ChangeNotifier {
  GroupEditorController({
    required this.gateway,
    required this.actor,
    required this.authorized,
    required this.policyAllows,
    String? id,
  }) : groupId = id;
  final GroupGateway gateway;
  final String actor;
  final bool Function() authorized, policyAllows;
  String? groupId;
  OwnGroup? own;
  GroupContent content = const GroupContent(), saved = const GroupContent();
  GroupCommand? pending;
  GroupFailure? failure;
  bool busy = false, disposed = false, invalidated = false;
  bool get active => !disposed && !invalidated && authorized();
  bool get dirty => !content.same(saved);
  bool get frozen => busy || pending != null || failure == GroupFailure.stale;
  bool get canWrite => active && policyAllows();
  void edit(GroupContent value) {
    if (!frozen && active) {
      content = value;
      notifyListeners();
    }
  }

  void invalidate() {
    invalidated = true;
    content = saved = const GroupContent();
    own = null;
    groupId = null;
    pending = null;
    failure = null;
    busy = false;
    if (!disposed) notifyListeners();
  }

  Future<void> reload({bool keepInput = false}) async {
    if (!active || busy || pending != null || groupId == null) return;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final row = await gateway.ownDetail(actor, groupId!);
      if (!active) return;
      own = row;
      saved = row.content;
      if (!keepInput) content = saved;
    } catch (error) {
      if (active) failure = groupFailure(error);
    } finally {
      if (active) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save() => _start(null);
  Future<bool> publication(GroupPublication next) => _start(next);
  Future<bool> _start(GroupPublication? next) async {
    if (!canWrite ||
        frozen ||
        !content.valid ||
        (next != null && (own == null || dirty))) {
      return false;
    }
    if (next == GroupPublication.published && !saved.publishable) {
      failure = GroupFailure.invalid;
      notifyListeners();
      return false;
    }
    pending = GroupCommand(
      key: const Uuid().v4(),
      content: content.normalized,
      id: groupId,
      version: own?.version,
      publication: next,
    );
    return retry();
  }

  Future<bool> retry() async {
    final command = pending;
    if (!canWrite || busy || command == null) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      // Recovery is also safe before first delivery and after later edits.
      final receipt = await gateway.recover(actor, command.key);
      if (!canWrite) {
        if (active) failure = GroupFailure.uncertain;
        return false;
      }
      String id;
      if (receipt != null) {
        id = receipt.id;
        if (command.id != null && id != command.id) {
          throw const FormatException('Wrong command destination.');
        }
      } else if (command.id == null) {
        id = await gateway.create(actor, command.key, command.content);
      } else {
        id = command.id!;
        if (command.publication != null) {
          await gateway.publish(
            actor,
            id,
            command.key,
            command.version!,
            command.publication!,
          );
        } else {
          await gateway.update(
            actor,
            id,
            command.key,
            command.version!,
            command.content,
          );
        }
      }
      if (!active) return false;
      groupId = id;
      final row = await gateway.ownDetail(actor, id);
      if (!active) return false;
      own = row;
      saved = row.content;
      content = saved;
      pending = null;
      return true;
    } catch (error) {
      if (!active) return false;
      failure = groupFailure(error);
      if (failure != GroupFailure.uncertain && failure != GroupFailure.setup) {
        pending = null;
      }
      return false;
    } finally {
      if (active) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    pending = null;
    content = saved = const GroupContent();
    super.dispose();
  }
}
