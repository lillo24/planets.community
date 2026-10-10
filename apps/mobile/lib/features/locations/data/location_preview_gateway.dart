import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/location_preview.dart';

class PreviewUnavailable implements Exception {
  const PreviewUnavailable([this.denied = false]);
  final bool denied;
}

abstract interface class LocationPreviewGateway {
  Future<Map<String, LocationPreview?>> publicBatch(List<PreviewItem> items);
  Future<LocationPreview?> read(
    PreviewItem item, {
    bool card = false,
    String? actor,
  });
}

class RpcLocationPreviewGateway implements LocationPreviewGateway {
  const RpcLocationPreviewGateway(this.rpc);
  final Future<dynamic> Function(String, Map<String, dynamic>) rpc;
  Future<dynamic> _call(String name, Map<String, dynamic> args) async {
    try {
      return await rpc(name, args).timeout(const Duration(seconds: 5));
    } on PostgrestException catch (error) {
      throw PreviewUnavailable(['42501', 'P0002'].contains(error.code));
    } catch (_) {
      throw const PreviewUnavailable();
    }
  }

  @override
  Future<Map<String, LocationPreview?>> publicBatch(
    List<PreviewItem> items,
  ) async {
    final rows = await _call('get_public_location_previews_v1', {
      'p_items': items.map((e) => e.request).toList(),
    }) as List;
    return {
      for (final row in rows)
        '${row['kind']}:${row['id']}': row['preview'] == null
            ? null
            : LocationPreview.fromJson(
                Map<String, dynamic>.from(row['preview'] as Map),
              ),
    };
  }

  @override
  Future<LocationPreview?> read(
    PreviewItem item, {
    bool card = false,
    String? actor,
  }) async {
    final protected = !card && actor != null && item.kind != 'resource';
    try {
      final value = await _call('get_location_preview_v1', {
        'p_kind': item.kind,
        'p_item': item.id,
        'p_view': card
            ? 'card'
            : protected
            ? 'protected_detail'
            : 'public_detail',
        'p_expected_profile_id': protected ? actor : null,
      });
      final preview = value == null
          ? null
          : LocationPreview.fromJson(Map<String, dynamic>.from(value as Map));
      if (preview?.isProtected == true && preview?.place?.isArea == true) {
        // Audience describes the RPC, not necessarily the selected place. Only
        // an independently matching PUBLIC read may establish public ownership.
        // Draft/unpublished areas and mismatches retain protected isolation.
        final public = await read(item);
        if (public != null &&
            !public.isProtected &&
            public.place?.isArea == true &&
            preview!.sameLocationAs(public)) {
          return public;
        }
      }
      return preview;
    } on PreviewUnavailable catch (error) {
      // An unrelated/removed actor remains entitled to the PUBLIC detail.
      if (!protected || !error.denied) rethrow;
      return read(item);
    }
  }
}

final locationPreviewGatewayProvider = Provider<LocationPreviewGateway>(
  (ref) => RpcLocationPreviewGateway(
    (name, args) =>
        ref.read(supabaseClientProvider).rpc<dynamic>(name, params: args),
  ),
);

abstract interface class StaticPreviewGateway {
  bool get enabled;
  Future<Uint8List> image(
    LocationPreview preview, {
    required String view,
    String? actor,
    required Future<void> cancellation,
  });
}

class DisabledStaticPreviewGateway implements StaticPreviewGateway {
  const DisabledStaticPreviewGateway();
  @override
  bool get enabled => false;
  @override
  Future<Uint8List> image(
    LocationPreview preview, {
    required String view,
    String? actor,
    required Future<void> cancellation,
  }) => Future.error(const PreviewUnavailable());
}

class ServerStaticPreviewGateway implements StaticPreviewGateway {
  const ServerStaticPreviewGateway(this.client, {this.enabled = false});
  final SupabaseClient client;
  @override
  final bool enabled;
  @override
  Future<Uint8List> image(
    LocationPreview preview, {
    required String view,
    String? actor,
    required Future<void> cancellation,
  }) async {
    if (!enabled ||
        (preview.isProtected && client.auth.currentUser?.id != actor)) {
      throw const PreviewUnavailable(true);
    }
    try {
      final response = await client.functions
          .invoke(
            'location-preview',
            body: {
              'item_kind': preview.item.kind,
              'item_id': preview.item.id,
              'view': view,
              'expected_profile_id': preview.isProtected ? actor : null,
              'revision': preview.revision,
              'image_key': preview.imageKey,
            },
            abortSignal: cancellation,
          )
          .timeout(const Duration(seconds: 7));
      if (response.data is! Uint8List) {
        final result = response.data;
        throw PreviewUnavailable(
          result is Map && ['unauthorized', 'stale'].contains(result['status']),
        );
      }
      final bytes = response.data as Uint8List;
      if (!validPreviewPng(bytes)) {
        bytes.fillRange(0, bytes.length, 0);
        throw const PreviewUnavailable();
      }
      if (preview.isProtected && client.auth.currentUser?.id != actor) {
        bytes.fillRange(0, bytes.length, 0);
        throw const PreviewUnavailable(true);
      }
      return bytes;
    } on PreviewUnavailable {
      rethrow;
    } on FunctionException catch (error) {
      throw PreviewUnavailable([401, 403, 409].contains(error.status));
    } catch (_) {
      throw const PreviewUnavailable();
    }
  }
}

bool validPreviewPng(Uint8List bytes) {
  if (bytes.length < 45 || bytes.length > 524288) return false;
  const header = [137, 80, 78, 71, 13, 10, 26, 10];
  const size = [73, 72, 68, 82, 0, 0, 2, 0, 0, 0, 1, 0];
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) return false;
  }
  for (var i = 0; i < size.length; i++) {
    if (bytes[12 + i] != size[i]) return false;
  }
  const end = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
  for (var i = 0; i < end.length; i++) {
    if (bytes[bytes.length - end.length + i] != end[i]) return false;
  }
  return true;
}

final staticPreviewGatewayProvider = Provider<StaticPreviewGateway>(
  (ref) => const DisabledStaticPreviewGateway(),
);

abstract interface class PreviewMapsLauncher {
  Future<bool> open(Uri url);
}

Future<bool> _launchPreviewUrl(Uri url, LaunchMode mode) =>
    launchUrl(url, mode: mode);

class UniversalPreviewMapsLauncher implements PreviewMapsLauncher {
  const UniversalPreviewMapsLauncher({this.launch = _launchPreviewUrl});
  final Future<bool> Function(Uri, LaunchMode) launch;
  @override
  Future<bool> open(Uri url) async {
    try {
      if (await launch(url, LaunchMode.externalApplication)) return true;
    } catch (_) {
      // A platform without an external handler can still open the HTTPS URL.
    }
    try {
      return await launch(url, LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}

final previewMapsLauncherProvider = Provider<PreviewMapsLauncher>(
  (ref) => UniversalPreviewMapsLauncher(),
);
