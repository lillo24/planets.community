import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../groups/application/group_controllers.dart';
import '../data/group_relationship_gateway.dart';
import '../domain/group_relationships.dart';

/// Unsent notes survive lazy-list disposal and temporary profile/policy routes.
/// They are private process memory and never cross an Auth identity change.
final groupRequestDraftsProvider = Provider<Map<String, String>>((ref) {
  final drafts = <String, String>{};
  ref.listen(
    authSessionProvider.select((s) => s.identity?.id),
    (_, _) => drafts.clear(),
  );
  ref.onDispose(drafts.clear);
  return drafts;
});

/// Cursor windows are independent. Revalidation rebuilds only the loaded window
/// and retains it on transport failure; authorization denial clears it at once.
class GroupRelationshipPager<T extends GroupPageRow> extends ChangeNotifier {
  GroupRelationshipPager(this.fetch, this.authorized);
  final Future<List<T>> Function(Map<String, dynamic>?) fetch;
  final bool Function() authorized;
  List<T> rows = [];
  Map<String, dynamic>? cursor;
  bool busy = false, more = true, disposed = false;
  Object? error;
  int revision = 0;
  Future<void> load() => _read(false);
  Future<void> refresh() => _read(true);
  Future<void> _read(bool refresh) async {
    if (disposed || busy || !authorized() || (!refresh && !more)) return;
    final epoch = ++revision;
    busy = true;
    error = null;
    notifyListeners();
    try {
      var next = refresh ? null : cursor;
      final window = <T>[];
      var hasMore = true;
      final pages = refresh ? (rows.length / 25).ceil().clamp(1, 1000000) : 1;
      for (var page = 0; page < pages && hasMore; page++) {
        final data = await fetch(next);
        if (disposed || epoch != revision || !authorized()) return;
        window.addAll(data);
        hasMore = data.length == 25;
        if (data.isNotEmpty) next = data.last.cursor;
      }
      final unique = <String>{};
      rows = [
        if (!refresh) ...rows,
        ...window,
      ].where((r) => unique.add(r.id)).toList(growable: false);
      cursor = next;
      more = hasMore;
    } catch (failure) {
      if (disposed || epoch != revision || !authorized()) return;
      error = failure;
      if (groupFailure(failure) == GroupFailure.denied) {
        rows = [];
        cursor = null;
        more = false;
      }
    } finally {
      if (!disposed && epoch == revision) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    revision++;
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
    revision++;
    super.dispose();
  }
}

class GroupRelationshipAttempt {
  GroupRelationshipAttempt(
    this.actor,
    this.mutation,
    Map<String, dynamic> input,
  ) : key = const Uuid().v4(),
      intent = Map.unmodifiable(input);
  final String actor, key;
  final GroupMutation mutation;
  final Map<String, dynamic> intent;
  GroupRelationshipReceipt? receipt;
  GroupFailure? failure;
  bool busy = false;
  @override
  String toString() => 'GroupRelationshipAttempt(redacted)';
}

/// Process-memory actor-bound, frozen command keys survive widget lifetimes.
/// Successful receipt recovery never proves current authority/participation.
class GroupCommandRegistry extends ChangeNotifier {
  GroupCommandRegistry(this.gateway, this.identity);
  final GroupRelationshipGateway gateway;
  final String? Function() identity;
  final Map<String, GroupRelationshipAttempt> attempts = {};
  int revision = 0;
  bool disposed = false;
  void clear() {
    revision++;
    attempts.clear();
    if (!disposed) notifyListeners();
  }

  void forget(String slot) {
    if (attempts[slot]?.busy != true) {
      attempts.remove(slot);
      notifyListeners();
    }
  }

  Future<GroupRelationshipReceipt?> run(
    String slot,
    String actor,
    GroupMutation mutation,
    Map<String, dynamic> intent, {
    required bool Function() policyAllows,
  }) async {
    if (disposed ||
        identity() != actor ||
        (!mutation.exit && !policyAllows())) {
      return null;
    }
    var attempt = attempts[slot];
    if (attempt == null) {
      attempt = GroupRelationshipAttempt(actor, mutation, intent);
      attempts[slot] = attempt;
    }
    if (attempt.actor != actor ||
        attempt.mutation != mutation ||
        jsonEncode(attempt.intent) != jsonEncode(intent)) {
      attempt.failure = GroupFailure.stale;
      notifyListeners();
      return null;
    }
    if (attempt.busy) return null;
    if (attempt.receipt != null) return attempt.receipt;
    final epoch = revision;
    bool active() => !disposed && epoch == revision && identity() == actor;
    attempt.busy = true;
    attempt.failure = null;
    notifyListeners();
    try {
      final recovered = await gateway.recover(actor, attempt.key);
      if (!active() || (!mutation.exit && !policyAllows())) return null;
      final receipt =
          recovered ??
          await gateway.command(actor, attempt.key, mutation, attempt.intent);
      if (!active()) return null;
      attempt.receipt = receipt;
      return receipt;
    } catch (error) {
      if (active()) attempt.failure = groupFailure(error);
      return null;
    } finally {
      if (active()) {
        attempt.busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    attempts.clear();
    super.dispose();
  }
}

final groupCommandRegistryProvider = Provider<GroupCommandRegistry>((ref) {
  final store = GroupCommandRegistry(
    ref.watch(groupRelationshipGatewayProvider),
    () => ref.read(authSessionProvider).identity?.id,
  );
  ref.listen(
    authSessionProvider.select((s) => s.identity?.id),
    (_, _) => store.clear(),
  );
  ref.onDispose(store.dispose);
  return store;
});

/// Sharing commands use their own result shape, but retain the same frozen
/// actor/key/intent until the server confirms them, including across navigation.
class GroupSharingAttempt {
  GroupSharingAttempt(this.actor, this.replace, this.revoke)
    : key = const Uuid().v4();
  final String actor, key;
  final bool replace;
  final String? revoke;
  bool busy = false;
  @override
  String toString() => 'GroupSharingAttempt(redacted)';
}

class GroupSharingRegistry extends ChangeNotifier {
  GroupSharingRegistry(this.identity);
  final String? Function() identity;
  bool disposed = false;
  final attempts = <String, GroupSharingAttempt>{};
  void clear() {
    attempts.clear();
    notifyListeners();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    attempts.clear();
    super.dispose();
  }
}

final groupSharingAttemptsProvider = Provider<GroupSharingRegistry>((ref) {
  final store = GroupSharingRegistry(
    () => ref.read(authSessionProvider).identity?.id,
  );
  ref.listen(
    authSessionProvider.select((s) => s.identity?.id),
    (_, _) => store.clear(),
  );
  ref.onDispose(store.dispose);
  return store;
});

class GroupInvitationAttempt extends GroupRelationshipAttempt {
  GroupInvitationAttempt(
    String actor,
    bool authority,
    String token,
    GroupInvitePreview preview,
  ) : consentVersion = preview.consentVersion,
      role = preview.role,
      super(
        actor,
        authority
            ? GroupMutation.acceptAuthority
            : GroupMutation.acceptParticipant,
        {'p_token': token},
      );
  final String consentVersion;
  final GroupAuthority? role;
}

class GroupInvitationController extends ChangeNotifier {
  GroupInvitationController(this.gateway, this.identity);
  final GroupRelationshipGateway gateway;
  final String? Function() identity;
  String? token, account;
  bool authority = false, loading = false, busy = false, disposed = false;
  GroupInvitePreview? preview;
  GroupSelfContext? current;
  GroupRelationshipReceipt? receipt;
  GroupFailure? failure;
  bool statusFailed = false;
  int revision = 0;
  final Map<String, GroupInvitationAttempt> attempts = {};
  GroupInvitationAttempt? get pendingAttempt => attempts[slot];
  String get slot => '${authority ? 'authority' : 'participant'}/$token';
  bool get confirmed =>
      receipt != null &&
      current != null &&
      (authority
          ? current!.authority != null
          : current!.membershipId != null ||
                current!.authority == GroupAuthority.creator);
  void clear() {
    revision++;
    token = null;
    account = null;
    preview = null;
    current = null;
    receipt = null;
    attempts.clear();
    loading = busy = statusFailed = false;
    failure = null;
    if (!disposed) notifyListeners();
  }

  Future<void> open(String value, bool structural) async {
    if (token == value &&
        authority == structural &&
        account == identity() &&
        busy) {
      return;
    }
    final epoch = ++revision;
    token = value;
    authority = structural;
    account = identity();
    preview = null;
    current = null;
    receipt = attempts[slot]?.receipt;
    failure = null;
    loading = true;
    statusFailed = false;
    notifyListeners();
    try {
      final data = await gateway.preview(value, structural);
      if (!_active(epoch)) return;
      preview = data;
      if (receipt != null) await refreshStatus();
    } catch (error) {
      if (_active(epoch)) failure = groupFailure(error);
    } finally {
      if (_active(epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _active(int epoch) =>
      !disposed && epoch == revision && account == identity();
  Future<void> accept(
    String expected, {
    required String consentVersion,
    required bool Function() policyAllows,
    bool reenter = false,
  }) async {
    if (account != expected ||
        identity() != expected ||
        busy ||
        loading ||
        !policyAllows()) {
      return;
    }
    if (receipt != null && !reenter) {
      await refreshStatus();
      return;
    }
    if (reenter &&
        (authority ||
            receipt == null ||
            current == null ||
            confirmed ||
            preview?.available != true)) {
      return;
    }
    if (reenter) {
      attempts.remove(slot);
      receipt = null;
      current = null;
    }
    var attempt = attempts[slot];
    if (attempt == null) {
      if (preview?.available != true ||
          preview?.consentVersion != consentVersion) {
        return;
      }
      attempt = GroupInvitationAttempt(expected, authority, token!, preview!);
      attempts[slot] = attempt;
    }
    final epoch = revision;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final recovered = await gateway.recover(expected, attempt.key);
      if (!_active(epoch) || !policyAllows()) return;
      if (recovered == null) {
        final fresh = await gateway.preview(token!, authority);
        if (!_active(epoch) || !policyAllows()) return;
        if (!fresh.available ||
            fresh.consentVersion != attempt.consentVersion ||
            consentVersion != attempt.consentVersion) {
          preview = fresh;
          failure = GroupFailure.stale;
          return;
        }
      }
      final result =
          recovered ??
          await gateway.command(
            expected,
            attempt.key,
            attempt.mutation,
            attempt.intent,
          );
      if (!_active(epoch)) return;
      if (preview?.groupId != null && result.groupId != preview!.groupId) {
        throw const FormatException('Group receipt destination mismatch.');
      }
      receipt = result;
      attempt.receipt = result;
      await refreshStatus();
    } catch (error) {
      if (_active(epoch)) failure = groupFailure(error);
    } finally {
      if (_active(epoch)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshStatus() async {
    final result = receipt;
    final actor = account;
    if (result == null || actor == null) return;
    final epoch = revision;
    try {
      final data = await gateway.self(actor, result.groupId);
      if (!_active(epoch)) return;
      current = data;
      statusFailed = false;
    } catch (_) {
      if (_active(epoch)) {
        current = null;
        statusFailed = true;
      }
    }
    if (_active(epoch)) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    attempts.clear();
    super.dispose();
  }
}

final groupInvitationControllerProvider = Provider<GroupInvitationController>((
  ref,
) {
  final controller = GroupInvitationController(
    ref.watch(groupRelationshipGatewayProvider),
    () => ref.read(authSessionProvider).identity?.id,
  );
  ref.listen(
    authSessionProvider.select((s) => s.identity?.id),
    (_, _) => controller.clear(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
