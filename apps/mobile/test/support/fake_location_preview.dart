import 'dart:convert';
import 'dart:typed_data';

import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';

Uint8List fakePreviewPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAgAAAAEACAYAAADFkM5nAAAEQUlEQVR4nO3WMQ0AIADAMPz7I0ECLsAFHOvRf+fG2vMAAC3jdwAA8J4BAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABBkAAAgyAAAQJABAIAgAwAAQQYAAIIMAAAEGQAACDIAABB0AdTsa1lG1P77AAAAAElFTkSuQmCC',
);
LocationPreview previewFixture(
  PreviewItem item, {
  bool protected = false,
  bool exact = false,
}) => LocationPreview(
  item: item,
  revision: 1,
  isProtected: protected,
  place: PreviewPlace(
    exact ? 'address' : 'locality',
    exact ? 'SECRET synthetic venue' : 'Synthetic Trento area',
    exact ? 44 : 45,
    exact ? 10 : 12,
  ),
  imageKey: 'a' * 64,
  legacy: const LegacyPreviewArea('Trento', 'IT'),
);

class FakePreviewGateway implements LocationPreviewGateway {
  int batches = 0, reads = 0;
  final requested = <List<PreviewItem>>[];
  bool protected = false, exact = false, denied = false;
  Future<LocationPreview?> Function(PreviewItem, String?)? pending;
  @override
  Future<Map<String, LocationPreview?>> publicBatch(
    List<PreviewItem> items,
  ) async {
    batches++;
    requested.add(items);
    return {for (final x in items) x.key: previewFixture(x)};
  }

  @override
  Future<LocationPreview?> read(
    PreviewItem item, {
    bool card = false,
    String? actor,
  }) async {
    reads++;
    if (pending != null) return pending!(item, actor);
    if (denied) return null;
    return previewFixture(
      item,
      protected: !card && protected && actor != null,
      exact: !card && exact && actor != null,
    );
  }
}

class FakeStaticPreviewGateway implements StaticPreviewGateway {
  FakeStaticPreviewGateway({this.enabled = true});
  @override
  bool enabled;
  int calls = 0;
  Future<Uint8List> Function()? pending;
  final outputs = <Uint8List>[];
  @override
  Future<Uint8List> image(
    LocationPreview p, {
    required String view,
    String? actor,
    required Future<void> cancellation,
  }) async {
    calls++;
    if (pending != null) return pending!();
    final bytes = fakePreviewPng();
    outputs.add(bytes);
    return bytes;
  }
}

class FakePreviewMapsLauncher implements PreviewMapsLauncher {
  final urls = <Uri>[];
  bool result = true;
  @override
  Future<bool> open(Uri uri) async {
    urls.add(uri);
    return result;
  }
}
