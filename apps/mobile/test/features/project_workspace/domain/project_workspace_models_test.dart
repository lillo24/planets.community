import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

void main() {
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
