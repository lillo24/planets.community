import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

void main() {
  test('validates trimmed bounded names', () {
    expect(
      validateProjectWorkspaceName('  Documento organizzazione  '),
      'Documento organizzazione',
    );
    for (final name in ['', '   ', 'a' * 121, 'a\nb', 'a\tb']) {
      expect(
        () => validateProjectWorkspaceName(name),
        throwsA(isA<ProjectWorkspaceNameException>()),
      );
    }
  });
  test('name-first EN/IT classification uses whole words and reliable URL fallbacks', () {
    final cases = <(String, String, ProjectWorkspaceIconType)>[
      (
        'DOCUMENTO organizzazione',
        'https://meet.google.com/x',
        ProjectWorkspaceIconType.document,
      ),
      (
        'Sheet Budget',
        'https://example.org',
        ProjectWorkspaceIconType.spreadsheet,
      ),
      (
        'Foglio Excel',
        'https://example.org',
        ProjectWorkspaceIconType.spreadsheet,
      ),
      (
        'Riunione settimanale',
        'https://example.org',
        ProjectWorkspaceIconType.video,
      ),
      (
        'Cartella condivisa',
        'https://example.org',
        ProjectWorkspaceIconType.drive,
      ),
      (
        'Organizzazione',
        'https://docs.google.com/document/d/x',
        ProjectWorkspaceIconType.document,
      ),
      (
        'Budget',
        'https://docs.google.com/spreadsheets/d/x',
        ProjectWorkspaceIconType.spreadsheet,
      ),
      ('Incontro', 'https://meet.google.com/x', ProjectWorkspaceIconType.video),
      (
        'Materiali',
        'https://drive.google.com/x',
        ProjectWorkspaceIconType.drive,
      ),
      (
        'Doctor callback teamster',
        'https://meet.google.com.evil.example/x',
        ProjectWorkspaceIconType.link,
      ),
      (
        'Docs budget sheet',
        'https://example.org',
        ProjectWorkspaceIconType.spreadsheet,
      ),
      ('Risorse', 'https://example.org/docs', ProjectWorkspaceIconType.link),
    ];
    for (final (name, url, kind) in cases) {
      expect(
        classifyProjectWorkspace(name, Uri.parse(url)),
        kind,
        reason: name,
      );
    }
  });
  test('accepts and trims provider-neutral HTTPS URLs', () {
    final drive = ProjectWorkspaceUrl.parse(
      '  https://drive.google.com/drive/folders/private-token?usp=sharing  ',
    );
    final generic = ProjectWorkspaceUrl.parse('https://docs.example.org/team');

    expect(
      drive.value,
      'https://drive.google.com/drive/folders/private-token?usp=sharing',
    );
    expect(drive.hostname, 'drive.google.com');
    expect(generic.hostname, 'docs.example.org');
  });

  test(
    'rejects non-HTTPS, malformed, credential, whitespace, and long URLs',
    () {
      for (final value in [
        '',
        'http://example.org/folder',
        'not a URL',
        'https://user:secret@example.org/folder',
        'https://example.org/private folder',
        'https://example.org/${'a' * 2040}',
      ]) {
        expect(
          () => ProjectWorkspaceUrl.parse(value),
          throwsA(isA<ProjectWorkspaceUrlException>()),
          reason: value,
        );
      }
    },
  );
}
