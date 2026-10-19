import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_group_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_group_discussions.dart';
import '../../support/fake_policy.dart';
import '../groups/group_membership_test.dart' show selfRow;
import 'discussion_test_support.dart' show Session, groupId, roomId, receipt;

class _DropdownGateway extends EmptyDiscussionGateway {
  String policy = 'managers';
  int version = 1;
  final writes = <(DiscussionAction, Map<String, dynamic>)>[];

  @override
  Future<DiscussionSettings> settings(String actor, String group) async =>
      DiscussionSettings({
        'group_id': group,
        'creation_policy': policy,
        'version': version,
        'can_edit': true,
        'can_create': true,
        'general_room_id': null,
      });

  @override
  Future<DiscussionReceipt> command(
    String actor,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async {
    writes.add((action, Map.of(intent)));
    if (action == DiscussionAction.settings) {
      policy = intent['p_creation_policy'] as String;
      version++;
    } else if (action != DiscussionAction.create) {
      throw StateError('Unexpected dropdown command: $action');
    }
    return receipt();
  }
}

Future<AppLocalizations> _pumpScreen(
  WidgetTester tester,
  _DropdownGateway gateway,
  String language, {
  required bool create,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Session.new),
      discussionGatewayProvider.overrideWithValue(gateway),
      preacceptedPolicyFixture,
      groupGatewayProvider.overrideWithValue(
        GroupGateway((name, _) async {
          if (name == 'get_own_group_membership_context') {
            return [selfRow(role: 'creator')];
          }
          throw StateError('Unexpected dropdown read: $name');
        }),
      ),
    ],
  );
  container.read(policyAcceptanceProvider);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            DiscussionGroupScreen(groupId: groupId, create: create),
      ),
      GoRoute(
        path: discussionRoute(roomId),
        builder: (_, _) => const Scaffold(body: Text('Created Idea')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(
    tester.element(find.byType(DiscussionGroupScreen)),
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void _expectCompleteLabel(WidgetTester tester, String label) {
  final finder = find.text(label).hitTestable();
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  final lines = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: label.length),
  );
  expect(
    lines.length,
    greaterThan(1),
    reason: 'Full label wraps at 320dp/1.8x.',
  );
  // Selection boxes include trailing line-break spaces outside the painted
  // width. Check each word so only the actual disclosure glyphs are measured.
  for (final word in RegExp(r'\S+').allMatches(label)) {
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    )) {
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + .01));
      expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + .01));
    }
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language audience menu and selected label wrap at 320dp/1.8x',
      (tester) async {
        final gateway = _DropdownGateway();
        final l = await _pumpScreen(tester, gateway, language, create: true);
        await _reveal(tester, find.byKey(const Key('discussion-name')));
        await tester.enterText(
          find.byKey(const Key('discussion-name')),
          'Garden',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await _reveal(tester, dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        _expectCompleteLabel(tester, l.discussionInviteOnly);
        await tester.tap(find.text(l.discussionInviteOnly).hitTestable());
        await tester.pumpAndSettle();
        _expectCompleteLabel(tester, l.discussionInviteOnly);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          expect(
            find.bySemanticsLabel(
              RegExp(RegExp.escape(l.discussionInviteOnly)),
            ),
            findsWidgets,
          );
        } finally {
          semantics.dispose();
        }
        await _reveal(tester, find.text(l.discussionManagerDisclosure));
        expect(find.text(l.discussionManagerDisclosure), findsOneWidget);
        await _reveal(
          tester,
          find.byKey(const Key('discussion-create-submit')),
        );
        await tester.tap(find.byKey(const Key('discussion-create-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Created Idea'), findsOneWidget);
        expect(gateway.writes.single.$1, DiscussionAction.create);
        expect(gateway.writes.single.$2['p_visibility'], 'invitation');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language policy menu wraps and persists both choices at 320dp/1.8x',
      (tester) async {
        final gateway = _DropdownGateway();
        final l = await _pumpScreen(tester, gateway, language, create: false);
        final settings = find.widgetWithText(
          ExpansionTile,
          l.discussionSettings,
        );
        await _reveal(tester, settings);
        await tester.tap(settings);
        await tester.pumpAndSettle();
        final dropdown = find.byType(DropdownButtonFormField<String>);
        for (final (label, policy) in [
          (l.discussionAllMembers, 'members'),
          (l.discussionManagersOnly, 'managers'),
        ]) {
          await _reveal(tester, dropdown);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          _expectCompleteLabel(tester, label);
          await tester.tap(find.text(label).hitTestable());
          await tester.pumpAndSettle();
          _expectCompleteLabel(tester, label);
          expect(gateway.policy, policy);
          expect(gateway.writes.last.$1, DiscussionAction.settings);
          expect(gateway.writes.last.$2['p_creation_policy'], policy);
        }
        expect(gateway.writes, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
