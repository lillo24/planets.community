import 'dart:async';

import 'package:http/http.dart' as http;

/// Transport ownership complements provider disposal. Captured old gateways
/// keep their original destination and cannot resume product work in a new realm.
class RealmTransport extends http.BaseClient {
  RealmTransport({required this.origin, this.mock = false, http.Client? inner})
    : _inner = inner ?? http.Client();
  final Uri origin;
  final bool mock;
  final http.Client _inner;
  bool productBlocked = false;
  bool _closed = false;
  int _inFlight = 0;
  Completer<void>? _drained;
  final uncertainOperations = <String>{};

  bool _maintenance(http.BaseRequest request) {
    if (request.url.path == '/auth/v1/user' && request.method == 'GET') {
      return true;
    }
    if (request.url.path == '/auth/v1/token' &&
        request.method == 'POST' &&
        request.url.queryParameters['grant_type'] == 'refresh_token') {
      return true;
    }
    return request.url.path == '/auth/v1/logout' && request.method == 'POST';
  }

  Future<void> get whenDrained => _inFlight == 0
      ? Future<void>.value()
      : (_drained ??= Completer<void>()).future;
  void _finish() {
    _inFlight--;
    if (_inFlight == 0) {
      _drained?.complete();
      _drained = null;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final auth = request.url.path.startsWith('/auth/v1/');
    if (_closed ||
        request.url.origin != origin.origin ||
        ((productBlocked || (mock && auth)) && !_maintenance(request))) {
      throw http.ClientException(
        'The originating realm is unavailable for this operation.',
      );
    }
    // A redirect cannot silently move authenticated data traffic to a new host.
    request.followRedirects = false;
    final product = !auth;
    if (!product) return _inner.send(request);
    // The fixed map API reads public imagery/centers. Its server-owned quota
    // reservation is not an uncertain product edit when route cancellation
    // aborts a POST; treating it as one blocks later realm departure.
    final providerRead =
        request.method == 'POST' &&
        request.url.path == '/functions/v1/map-provider';
    final mutation =
        !providerRead && request.method != 'GET' && request.method != 'HEAD';
    final name = request.url.path.startsWith('/rest/v1/rpc/')
        ? request.url.path.substring('/rest/v1/rpc/'.length)
        : request.url.path.split('/').take(3).join('/');
    _inFlight++;
    try {
      final response = await _inner.send(request);
      if (mutation && response.statusCode >= 500) uncertainOperations.add(name);
      Stream<List<int>> tracked() async* {
        try {
          yield* response.stream;
        } catch (_) {
          if (mutation) uncertainOperations.add(name);
          rethrow;
        } finally {
          _finish();
        }
      }

      return http.StreamedResponse(
        tracked(),
        response.statusCode,
        headers: response.headers,
        contentLength: response.contentLength,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        request: request,
      );
    } catch (_) {
      if (mutation) uncertainOperations.add(name);
      _finish();
      rethrow;
    }
  }

  @override
  void close() {
    _closed = true;
    _inner.close();
  }
}
