import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/cover_image_loader.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/public_recurring_activities_screen.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/presentation/public_resource_listings_screen.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/domain/template_models.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../support/fake_auth.dart';
import '../support/fake_proposal.dart';
import '../support/fake_recurring_activity.dart';
import '../support/fake_resource_listing.dart';
import '../support/fake_template.dart';

void main() {
  for (final feed in ['projects', 'tavoli', 'resources', 'templates']) {
    for (final size in [const Size(320, 800), const Size(1200, 1600)]) {
      testWidgets('$feed user paging and lazy covers at $size', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FakeAuthGateway();
        addTearDown(auth.close);
        final limits = <int>[];
        final images = <String>[];
        final pending = Completer<void>();
        var fail = false;
        Future<void> request(int limit, Object? cursor) async {
          limits.add(limit);
          if (cursor != null) {
            await pending.future;
            if (fail) throw Exception('offline');
          }
        }

        int offset(String? id) =>
            id == null ? 0 : int.parse(id.split('-').last) + 1;
        String cover(int i) =>
            '11111111-1111-4111-8111-111111111111/projects/'
            '22222222-2222-4222-8222-${i.toString().padLeft(12, '0')}/'
            '33333333-3333-4333-8333-333333333333.webp';
        final proposals = FakeProposalGateway();
        final tavoli = FakeRecurringActivityGateway();
        final resources = FakeResourceListingGateway();
        final templates = FakeTemplateGateway();
        proposals.publicLoader =
            ({required limit, cursor, query, locality, skillIds}) async {
              await request(limit, cursor);
              return List.generate(limit, (j) {
                final i = offset(cursor?.id) + j;
                return proposalSummaryFixture(
                  id: 'item-$i',
                  coverObjectPath: cover(i),
                );
              });
            };
        tavoli.publicLoader =
            ({required referenceTime, required limit, cursor, locality}) async {
              await request(limit, cursor);
              return List.generate(limit, (j) {
                final i = offset(cursor?.id) + j;
                return publicRecurringSummaryFixture(
                  id: 'item-$i',
                  coverObjectPath: cover(i),
                );
              });
            };
        resources.publicLoader =
            ({required limit, cursor, mode, locality, query}) async {
              await request(limit, cursor);
              return List.generate(limit, (j) {
                final i = offset(cursor?.id) + j;
                return publicResourceListingFixture(
                  id: 'item-$i',
                  coverObjectPath: cover(i),
                );
              });
            };
        templates.listLoader = (cursor, query, skills) async {
          final limit = templates.limits.last;
          await request(limit, cursor);
          return List.generate(limit, (j) {
            final i = offset(cursor?.id) + j;
            return TemplateCard(
              id: 'item-$i',
              sourceId: templateSource,
              linkedAt: DateTime.utc(2026),
              title: 'Template $i',
              summary: 'Reusable community project',
              skills: const [],
              creatorId: templateActor,
              coverPath: cover(i),
            );
          });
        };
        final c = ProviderContainer(
          overrides: [
            authGatewayProvider.overrideWithValue(auth),
            proposalGatewayProvider.overrideWithValue(proposals),
            recurringActivityGatewayProvider.overrideWithValue(tavoli),
            resourceListingGatewayProvider.overrideWithValue(resources),
            templateGatewayProvider.overrideWithValue(templates),
            publicCoverBytesProvider.overrideWith((ref, path) async {
              images.add(path);
              return base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              );
            }),
          ],
        );
        addTearDown(c.dispose);
        if (feed == 'templates') {
          c
              .read(authSessionProvider.notifier)
              .markProfileReady(const AuthIdentity(id: templateActor));
        }
        final screen = switch (feed) {
          'projects' => const PublicProposalsScreen(),
          'tavoli' => const PublicRecurringActivitiesScreen(),
          'resources' => const PublicResourceListingsScreen(),
          _ => const TemplateWorkshopScreen(),
        };
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => screen),
            GoRoute(
              path: '/proposals/:id',
              builder: (_, _) => const Scaffold(body: Text('Detail')),
            ),
            GoRoute(
              path: '/tavoli/:id',
              builder: (_, _) => const Scaffold(body: Text('Detail')),
            ),
            GoRoute(
              path: '/resources/:id',
              builder: (_, _) => const Scaffold(body: Text('Detail')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(limits, [7]);
        final prefix = switch (feed) {
          'projects' => 'proposal',
          'tavoli' => 'tavoli',
          'resources' => 'resource',
          _ => 'template',
        };
        expect(find.byKey(Key('$prefix-load-more')), findsNothing);
        expect(images.length, greaterThan(0));
        expect(images.length, lessThan(7));
        debugPrint(
          'AUTO01 $feed $size initial records=7 covers=${images.length}',
        );
        final dir = Platform.environment['PLANETS_AUTO_QA_DIR'];
        if (dir != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await tester.runAsync(() async {
            final frame = await boundary.toImage();
            final bytes = await frame.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File('$dir/$feed-${size.width.toInt()}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            frame.dispose();
          });
        }
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        scroll.jumpTo(scroll.maxScrollExtent);
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          scroll.jumpTo(scroll.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        expect(limits, [7], reason: 'programmatic movement stays inert');
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pump();
        expect(limits, [7, 15]);
        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, -300),
          2000,
        );
        await tester.pump();
        expect(limits, [7, 15]);
        fail = true;
        pending.complete();
        await tester.pumpAndSettle();
        expect(limits, [7, 15]);
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(limits, [7, 15], reason: 'failure pauses automatic retries');
        final beforeRetryImages = images.length;
        final l = AppLocalizations.of(
          tester.element(find.byType(ListView).first),
        );
        final retryLabel = feed == 'templates'
            ? l.workshopRetry
            : l.retryAction;
        fail = false;
        await tester.scrollUntilVisible(
          find.text(retryLabel),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(retryLabel));
        await tester.pumpAndSettle();
        expect(limits, [7, 15, 15]);
        expect(
          images.length - beforeRetryImages,
          lessThan(15),
          reason: 'the appended page does not fetch every offscreen cover',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
