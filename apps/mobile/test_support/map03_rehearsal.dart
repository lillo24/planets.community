import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../test/support/fake_location_preview.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_recurring_activity.dart';
import '../test/support/fake_resource_listing.dart';

void main() {
  if (!kDebugMode || !const bool.fromEnvironment('MAP03_REHEARSAL')) {
    throw StateError('MAP03 requires opted-in debug build.');
  }
  final gateway = FakePreviewGateway(),
      images = FakeStaticPreviewGateway(
        enabled: const bool.fromEnvironment('MAP03_FAKE_IMAGES'),
      ),
      maps = FakePreviewMapsLauncher();
  final container = ProviderContainer(
    overrides: [
      locationPreviewGatewayProvider.overrideWithValue(gateway),
      staticPreviewGatewayProvider.overrideWithValue(images),
      previewMapsLauncherProvider.overrideWithValue(maps),
    ],
  );
  final language = ValueNotifier('en'),
      detail = ValueNotifier<PreviewItem?>(null);
  enableFlutterDriverExtension(
    handler: (command) async {
      if (command == 'en' || command == 'it') {
        language.value = command!;
        return command;
      }
      if (command == 'images') {
        images.enabled = true;
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'synthetic-image-viewer'));
        return 'synthetic-images';
      }
      if (command == 'public') {
        gateway.protected = false;
        gateway.exact = false;
        container.read(authSessionProvider.notifier).markSignedOut();
        return 'public';
      }
      if (command == 'protected') {
        gateway.protected = true;
        gateway.exact = true;
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'synthetic-user'));
        return 'protected';
      }
      if (command == 'status') {
        return jsonEncode({
          'maps': maps.urls.map((x) => x.queryParameters).toList(),
          'renders': images.calls,
          'reads': gateway.reads,
          'batches': gateway.batches,
          'detail': detail.value?.kind,
        });
      }
      throw StateError('Unknown MAP03 rehearsal command.');
    },
  );
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ValueListenableBuilder(
        valueListenable: language,
        builder: (context, lang, _) => MaterialApp(
          theme: AppTheme.light,
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder(
            valueListenable: detail,
            builder: (context, value, _) => Scaffold(
              appBar: AppBar(
                title: const Text('MAP03 synthetic rehearsal'),
                leading: value == null
                    ? null
                    : IconButton(
                        key: const Key('native-back'),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => detail.value = null,
                      ),
              ),
              body: value == null
                  ? ListView(
                      children: [
                        ProposalCard(
                          proposal: proposalSummaryFixture(),
                          onTap: () => detail.value = const PreviewItem(
                            'one_time',
                            'proposal-1',
                          ),
                        ),
                        RecurringActivityCard(
                          activity: publicRecurringSummaryFixture(),
                          onTap: () => detail.value = const PreviewItem(
                            'recurring',
                            'tavolo-1',
                          ),
                        ),
                        PublicResourceListingCard(
                          listing: publicResourceListingFixture(
                            id: 'resource-1',
                          ),
                          now: DateTime.utc(2026, 10, 8),
                          onTap: () => detail.value = const PreviewItem(
                            'resource',
                            'resource-1',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        Text(
                          'Native detail: ${value.kind}',
                          key: const Key('native-detail'),
                        ),
                        LocationPreviewPanel(
                          key: ValueKey(value.key),
                          item: value,
                          legacy: const LegacyPreviewArea('Trento', 'IT'),
                          publicLabel: 'Synthetic public area',
                          detail: true,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
