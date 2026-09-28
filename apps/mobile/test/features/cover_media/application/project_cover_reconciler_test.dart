import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/cover_media/application/cover_media_path_generator.dart';
import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

import '../../../support/fake_cover_media.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _project = 'c2000000-0000-4000-8000-000000000001';
const _oldPath =
    '$_owner/projects/$_project/c3000000-0000-4000-8000-000000000001.webp';

void main() {
  late FakeCoverMediaGateway gateway;
  late GatewayProjectCoverReconciler reconciler;

  setUp(() {
    gateway = FakeCoverMediaGateway();
    reconciler = GatewayProjectCoverReconciler(
      gateway,
      CoverMediaPathGenerator(),
    );
  });

  test('Project path generator creates unique parent-bound WebP paths', () {
    final generator = CoverMediaPathGenerator();
    final first = generator.forProject(
      ownerProfileId: _owner,
      projectId: _project,
    );
    final second = generator.forProject(
      ownerProfileId: _owner,
      projectId: _project,
    );

    expect(first, isNot(second));
    expect(
      first,
      matches(RegExp('^$_owner/projects/$_project/[0-9a-f-]{36}\\.webp\$')),
    );
  });

  test('unchanged performs no media operation', () async {
    await reconciler.reconcile(
      ownerProfileId: _owner,
      projectId: _project,
      change: const ProjectCoverChange.unchanged(),
    );

    expect(gateway.calls, isEmpty);
  });

  test(
    'replacement uploads, commits, then cleans the old immutable path',
    () async {
      gateway.currentObjectPath = _oldPath;

      final path = await reconciler.reconcile(
        ownerProfileId: _owner,
        projectId: _project,
        change: ProjectCoverChange.replacement(processedCoverFixture()),
      );

      expect(path, gateway.currentObjectPath);
      expect(
        path,
        matches(RegExp('^$_owner/projects/$_project/[0-9a-f-]{36}\\.webp\$')),
      );
      expect(gateway.calls[0], startsWith('upload:$path:'));
      expect(gateway.calls[1], 'set:$_owner:$_project:$path');
      expect(gateway.calls[2], 'delete:$_oldPath');
    },
  );

  test('commit failure cleans the new upload and reports commit', () async {
    gateway.failCommit = true;

    await expectLater(
      reconciler.reconcile(
        ownerProfileId: _owner,
        projectId: _project,
        change: ProjectCoverChange.replacement(processedCoverFixture()),
      ),
      throwsA(
        isA<CoverPersistenceException>().having(
          (error) => error.kind,
          'kind',
          CoverPersistenceFailureKind.commit,
        ),
      ),
    );
    expect(
      gateway.calls.last,
      startsWith('delete:$_owner/projects/$_project/'),
    );
    expect(gateway.currentObjectPath, isNull);
  });

  test('old object cleanup failure does not roll back a commit', () async {
    gateway
      ..currentObjectPath = _oldPath
      ..failDelete = true;

    final path = await reconciler.reconcile(
      ownerProfileId: _owner,
      projectId: _project,
      change: ProjectCoverChange.replacement(processedCoverFixture()),
    );

    expect(path, isNotNull);
    expect(gateway.currentObjectPath, path);
  });

  test('removal clears canonical state before best-effort cleanup', () async {
    gateway.currentObjectPath = _oldPath;

    await reconciler.reconcile(
      ownerProfileId: _owner,
      projectId: _project,
      change: const ProjectCoverChange.removal(),
    );

    expect(gateway.calls, ['clear:$_owner:$_project', 'delete:$_oldPath']);
    expect(gateway.currentObjectPath, isNull);
  });
}
