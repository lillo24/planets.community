import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/realm_transport.dart';
import '../../../core/backend/secure_session_storage.dart';
import '../../../core/config/mock_environment_config.dart';
import '../domain/mock_models.dart';
import '../domain/mock_session_access.dart';

class SupabaseMockRealm implements MockRealmHandle {
  SupabaseMockRealm(
    this.selection,
    this.client,
    this.transport,
    this.store, {
    void Function(SupabaseMockRealm)? invalidated,
  }) {
    _subscription = client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (session == null &&
          state.event != AuthChangeEvent.initialSession &&
          !retired &&
          !_retiring) {
        invalidated?.call(this);
      }
      if (retired ||
          _retiring ||
          session == null ||
          session.user.id != selection.userId) {
        return;
      }
      final raw = jsonEncode(session.toJson());
      _persistence = _persistence.then((_) async {
        if (!retired &&
            !_retiring &&
            client.auth.currentSession?.accessToken == session.accessToken) {
          await store.write(key, raw);
        }
      });
      // Retain an explicit error for readiness/activation; no unhandled secret-
      // bearing platform exception escapes an SDK stream listener.
      _persistence = _persistence.catchError((Object _) {
        storageFailed = true;
        if (!retired && !_retiring) invalidated?.call(this);
      });
    });
  }
  @override
  final MockSelection selection;
  final SupabaseClient client;
  final RealmTransport transport;
  final ConfidentialStore store;
  late final StreamSubscription<AuthState> _subscription;
  Future<void> _persistence = Future<void>.value();
  bool storageFailed = false;
  bool retired = false;
  bool _retiring = false;
  bool _cleaned = false;
  Future<void>? _retirement;
  String get key => mockSessionKey(
    Uri.parse(selection.origin),
    selection.rootId,
    selection.requestId,
  );
  Future<void> flush() async {
    await _persistence;
    final session = client.auth.currentSession;
    if (retired || session == null || session.user.id != selection.userId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    try {
      await store.write(key, jsonEncode(session.toJson()));
      storageFailed = false;
    } on Exception {
      storageFailed = true;
      throw const MockFailure(MockFailureKind.storage);
    }
  }

  Future<void> retire() => _retirement ??= _retire().whenComplete(() {
    _retirement = null;
  });

  Future<void> _retire() async {
    if (_cleaned) return;
    _retiring = true;
    transport.productBlocked = true;
    client.auth.stopAutoRefresh();
    await client.removeAllChannels();
    await client.realtime.disconnect();
    // Local scope revokes only this session, never all sessions of the persona.
    if (!retired) {
      try {
        await client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        _retiring = false;
        rethrow;
      }
    }
    retired = true;
    await _subscription.cancel();
    await _persistence;
    await store.delete(key);
    await client.dispose();
    transport.close();
    _cleaned = true;
  }
}

class SupabaseMockSessionAccess implements MockSessionAccess {
  SupabaseMockSessionAccess({
    required this.config,
    required this.normal,
    required this.normalTransport,
    required this.credentials,
    http.Client? brokerClient,
  }) : _broker = brokerClient ?? http.Client();
  final MockEnvironmentConfig config;
  final SupabaseClient normal;
  final RealmTransport normalTransport;
  final ConfidentialStore credentials;
  final http.Client _broker;
  final _candidates = <String, SupabaseMockRealm>{};
  final _operationTokens = <String, String>{};
  final _invalidations = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get dataInvalidations => _invalidations.stream;
  SupabaseMockRealm? _active;
  SupabaseClient get activeClient =>
      _active?.retired == false ? _active!.client : normal;
  RealmTransport get activeTransport =>
      _active?.retired == false ? _active!.transport : normalTransport;
  @override
  String? get controlId => normal.auth.currentUser?.id;
  @override
  Stream<String?> get controlChanges =>
      normal.auth.onAuthStateChange.map((event) => event.session?.user.id);

  Future<String> _control(String? expected) async {
    if (normal.auth.currentSession == null) {
      throw const MockFailure(MockFailureKind.controlLoginRequired);
    }
    try {
      if (normal.auth.currentSession!.isExpired) {
        await normal.auth.refreshSession().timeout(const Duration(seconds: 12));
      }
      final result = await normal.auth.getUser().timeout(
        const Duration(seconds: 12),
      );
      final id = result.user?.id;
      if (id == null ||
          id != controlId ||
          (expected != null && id != expected)) {
        throw const MockFailure(MockFailureKind.controlLoginRequired);
      }
      return normal.auth.currentSession!.accessToken;
    } on AuthRetryableFetchException {
      throw const MockFailure(MockFailureKind.unavailable);
    } on AuthException {
      throw const MockFailure(MockFailureKind.controlLoginRequired);
    }
  }

  Future<Map<String, dynamic>> _call(
    Map<String, Object> body,
    String token,
  ) async {
    final request = http.Request('POST', config.broker)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      })
      ..body = jsonEncode(body);
    try {
      final response = await _broker
          .send(request)
          .timeout(const Duration(seconds: 12));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 12),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 32768) {
          throw const MockFailure(MockFailureKind.unavailable);
        }
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const MockFailure(MockFailureKind.unavailable);
      }
      if (response.statusCode != 200) {
        throw MockFailure(switch (response.statusCode) {
          401 => MockFailureKind.controlLoginRequired,
          403 => MockFailureKind.denied,
          409 =>
            value['error'] == 'pending'
                ? MockFailureKind.pending
                : MockFailureKind.expired,
          _ => MockFailureKind.unavailable,
        });
      }
      return value;
    } on FormatException {
      throw const MockFailure(MockFailureKind.unavailable);
    } on http.ClientException {
      throw const MockFailure(MockFailureKind.unavailable);
    } on TimeoutException {
      throw const MockFailure(MockFailureKind.pending);
    }
  }

  @override
  Future<List<MockPersona>> catalog({String? expectedRoot}) async {
    final token = await _control(expectedRoot);
    final root = controlId;
    final value = await _call({'action': 'catalog'}, token);
    if (controlId != root ||
        value['project_ref'] != MockEnvironmentConfig.projectRef ||
        value['generation'] != MockEnvironmentConfig.fixtureGeneration ||
        value['personas'] is! List) {
      throw const MockFailure(MockFailureKind.denied);
    }
    final rows = value['personas'] as List;
    if (rows.length > 12 || rows.any((row) => row is! Map<String, dynamic>)) {
      throw const MockFailure(MockFailureKind.unavailable);
    }
    final people = rows
        .map((row) => MockPersona.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
    if (people.map((p) => p.key).toSet().length != people.length ||
        people.map((p) => p.userId).toSet().length != people.length) {
      throw const MockFailure(MockFailureKind.unavailable);
    }
    return people;
  }

  @override
  Future<MockRealmHandle> prepare(
    MockSelection selection, {
    bool storedOnly = false,
  }) async {
    final catalogRows = await catalog(expectedRoot: selection.rootId);
    if (!catalogRows.any(
      (p) => p.key == selection.personaKey && p.userId == selection.userId,
    )) {
      throw const MockFailure(MockFailureKind.denied);
    }
    if (selection.origin != config.origin.origin) {
      throw const MockFailure(MockFailureKind.denied);
    }
    var candidate = _candidates[selection.requestId];
    if (candidate != null &&
        (candidate.selection.rootId != selection.rootId ||
            candidate.selection.personaKey != selection.personaKey ||
            candidate.selection.userId != selection.userId ||
            candidate.selection.origin != selection.origin)) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    if (candidate == null) {
      final transport = RealmTransport(origin: config.origin, mock: true);
      final client = SupabaseClient(
        config.origin.origin,
        config.publishableKey,
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      candidate = SupabaseMockRealm(
        selection,
        client,
        transport,
        credentials,
        invalidated: (realm) {
          if (identical(_active, realm)) _invalidations.add(null);
        },
      );
      _candidates[selection.requestId] = candidate;
    }
    final client = candidate.client;
    if (client.auth.currentSession == null && !candidate.retired) {
      final saved = await credentials.read(candidate.key);
      try {
        if (saved != null) {
          await client.auth
              .recoverSession(saved)
              .timeout(const Duration(seconds: 12));
        } else {
          if (storedOnly) {
            throw const MockFailure(MockFailureKind.invalidSession);
          }
          final token = await _control(selection.rootId);
          _operationTokens[selection.requestId] = token;
          final value = await _call({
            'action': 'issue',
            'persona_key': selection.personaKey,
            'request_id': selection.requestId,
          }, token);
          if (value['project_ref'] != MockEnvironmentConfig.projectRef ||
              value['generation'] != MockEnvironmentConfig.fixtureGeneration ||
              value['request_id'] != selection.requestId ||
              value['persona_key'] != selection.personaKey ||
              value['user_id'] != selection.userId ||
              value['access_token'] is! String ||
              value['refresh_token'] is! String ||
              value['access_token'] ==
                  normal.auth.currentSession?.accessToken ||
              value['refresh_token'] ==
                  normal.auth.currentSession?.refreshToken) {
            throw const MockFailure(MockFailureKind.invalidSession);
          }
          if (candidate.retired || candidate._retiring) {
            // Logout may have overtaken a delayed successful broker response.
            // Retire using the captured original control token, never install it.
            await _call({
              'action': 'retire',
              'persona_key': selection.personaKey,
              'request_id': selection.requestId,
            }, token);
            throw const MockFailure(MockFailureKind.expired);
          }
          final response = await client.auth
              .setSession(value['refresh_token'] as String)
              .timeout(const Duration(seconds: 12));
          if (response.user?.id != selection.userId) {
            throw const MockFailure(MockFailureKind.invalidSession);
          }
        }
      } on AuthException {
        throw const MockFailure(MockFailureKind.invalidSession);
      }
    }
    if (candidate.retired) throw const MockFailure(MockFailureKind.expired);
    final user = await candidate.client.auth.getUser().timeout(
      const Duration(seconds: 12),
    );
    if (user.user?.id != selection.userId ||
        candidate.client.auth.currentUser?.id != selection.userId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    final row = await candidate.client
        .from('profiles')
        .select('id,display_name')
        .eq('id', selection.userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    if (row?['id'] != selection.userId ||
        row?['display_name'] is! String ||
        (row!['display_name'] as String).trim().isEmpty) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    await candidate.flush();
    // Eligibility/registry changes during slow session/profile reads invalidate
    // the already-open action before it can commit an active realm.
    final current = await catalog(expectedRoot: selection.rootId);
    if (!current.any(
      (p) => p.key == selection.personaKey && p.userId == selection.userId,
    )) {
      throw const MockFailure(MockFailureKind.denied);
    }
    return candidate;
  }

  @override
  Future<void> suspend() async {
    final client = activeClient;
    final transport = activeTransport;
    transport.productBlocked = true;
    _active?.client.auth.stopAutoRefresh();
    await client.removeAllChannels();
    await client.realtime.disconnect();
  }

  @override
  Future<void> resume() async {
    activeTransport.productBlocked = false;
    _active?.client.auth.startAutoRefresh();
  }

  @override
  Future<void> activate(MockRealmHandle candidate) async {
    if (candidate is! SupabaseMockRealm ||
        candidate.retired ||
        candidate._retiring ||
        candidate.selection.rootId != controlId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    final previous = _active;
    normalTransport.productBlocked = true;
    await normal.removeAllChannels();
    await normal.realtime.disconnect();
    if (previous != null && previous != candidate) {
      await previous.retire();
      _candidates.remove(previous.selection.requestId);
      _operationTokens.remove(previous.selection.requestId);
    }
    if (candidate.retired ||
        candidate._retiring ||
        candidate.selection.rootId != controlId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    _active = candidate;
    candidate.transport.productBlocked = false;
    candidate.client.auth.startAutoRefresh();
  }

  @override
  Future<void> returnToNormal() async {
    final previous = _active;
    if (previous != null) {
      await previous.retire();
      _candidates.remove(previous.selection.requestId);
      _operationTokens.remove(previous.selection.requestId);
    }
    _active = null;
    // Existing Auth restoration owns valid/expired normal login. No normal
    // product refresh resumes until the mock client was retired.
    if (normal.auth.currentSession?.isExpired == true) {
      try {
        await normal.auth.refreshSession().timeout(const Duration(seconds: 12));
      } on AuthException {
        if (normal.auth.currentSession != null) rethrow;
      }
    }
    if (normal.auth.currentSession != null) {
      final checkedToken = normal.auth.currentSession!.accessToken;
      final checkedId = controlId;
      try {
        final result = await normal.auth.getUser().timeout(
          const Duration(seconds: 12),
        );
        if (normal.auth.currentSession?.accessToken != checkedToken ||
            result.user?.id != checkedId) {
          throw const MockFailure(MockFailureKind.controlLoginRequired);
        }
      } on AuthRetryableFetchException {
        rethrow;
      } on AuthException catch (error) {
        if (normal.auth.currentSession != null &&
            normal.auth.currentSession!.accessToken != checkedToken) {
          throw const MockFailure(MockFailureKind.controlLoginRequired);
        }
        if (!{'401', '403', '404'}.contains(error.statusCode)) rethrow;
        // Actual normal Auth authority was lost while its data scope was absent.
        // SDK local sign-out clears its session before revocation and tolerates
        // these authoritative statuses; no mock identity enters normal readiness.
        await normal.auth.signOut(scope: SignOutScope.local);
        await credentials.delete(normalSessionKey(config.normalOrigin));
      }
    }
    // The coordinator releases the fence only after committing No and checking
    // its revision, so a superseded return cannot reopen a newer realm.
  }

  @override
  Future<void> retire(MockSelection selection) async {
    final candidate = _candidates[selection.requestId];
    if (candidate != null) await candidate.retire();
    _candidates.remove(selection.requestId);
    final token =
        _operationTokens.remove(selection.requestId) ??
        (controlId == selection.rootId
            ? await _control(selection.rootId)
            : null);
    if (token != null) {
      await _call({
        'action': 'retire',
        'persona_key': selection.personaKey,
        'request_id': selection.requestId,
      }, token);
    }
    await credentials.delete(
      mockSessionKey(config.origin, selection.rootId, selection.requestId),
    );
    if (_active == candidate) _active = null;
  }

  @override
  Future<void> fullLogout() async {
    final root = controlId;
    for (final candidate in _candidates.values.toList()) {
      await candidate.retire();
    }
    _candidates.clear();
    _active = null;
    _operationTokens.clear();
    if (controlId != root) {
      throw const MockFailure(MockFailureKind.controlLoginRequired);
    }
    // Coalesce any outstanding SDK refresh before clearing the normal session.
    if (normal.auth.currentSession != null) {
      try {
        await normal.auth.refreshSession().timeout(const Duration(seconds: 12));
      } on AuthException {
        /* sign-out still owns cleanup below */
      }
    }
    if (controlId != null && controlId != root) {
      throw const MockFailure(MockFailureKind.controlLoginRequired);
    }
    normal.auth.stopAutoRefresh();
    await normal.auth.signOut();
    await credentials.delete(normalSessionKey(config.normalOrigin));
    normalTransport.productBlocked = false;
  }

  Future<void> dispose() async {
    _broker.close();
    await _invalidations.close();
    for (final candidate in _candidates.values) {
      candidate.client.auth.stopAutoRefresh();
      await candidate.client.dispose();
    }
  }

  @override
  Future<bool> drain() async {
    await suspend();
    try {
      await activeTransport.whenDrained.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return false;
    }
    return activeTransport.uncertainOperations.isEmpty;
  }

  @override
  Future<void> retainUncertain(int revision) async {
    final actor = activeClient.auth.currentUser?.id ?? 'guest';
    final realm = activeTransport.origin;
    final root = _active?.selection.rootId ?? actor;
    final key =
        'planets.realm.outcomes.v1.${sessionNamespace(realm)}.$root.$actor';
    final existing = await credentials.read(key);
    final List<dynamic> records = existing == null
        ? []
        : jsonDecode(existing) as List<dynamic>;
    records.add({
      'realm': realm.origin,
      'actor': actor,
      'revision': revision,
      'operations': activeTransport.uncertainOperations.toList(),
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    // Contains no payload, URL query, invitation capability or automatic replay.
    // Existing feature journals retain their own exact submitted intents.
    await credentials.write(
      key,
      jsonEncode(
        records.length > 24 ? records.sublist(records.length - 24) : records,
      ),
    );
  }
}
