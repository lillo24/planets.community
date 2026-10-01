import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

void main() {
  group('Project authority roles', () {
    test('parses stable and legacy management-role wire values', () {
      expect(
        ProjectManagementRole.fromWire('creator'),
        ProjectManagementRole.creator,
      );
      expect(
        ProjectManagementRole.fromWire('co_creator'),
        ProjectManagementRole.coCreator,
      );
      expect(
        ProjectManagementRole.fromWire('co_organizer'),
        ProjectManagementRole.coOrganizer,
      );
      expect(
        ProjectManagementRole.fromWire('owner'),
        ProjectManagementRole.creator,
      );
      expect(
        ProjectManagementRole.fromWire('delegate'),
        ProjectManagementRole.coOrganizer,
      );
    });

    test('distinguishes operational and structural authority', () {
      expect(ProjectManagementRole.creator.isManager, isTrue);
      expect(ProjectManagementRole.coCreator.isManager, isTrue);
      expect(ProjectManagementRole.coOrganizer.isManager, isTrue);
      expect(ProjectManagementRole.none.isManager, isFalse);

      expect(ProjectManagementRole.creator.hasStructuralAuthority, isTrue);
      expect(ProjectManagementRole.coCreator.hasStructuralAuthority, isTrue);
      expect(ProjectManagementRole.coOrganizer.hasStructuralAuthority, isFalse);
      expect(ProjectManagementRole.none.hasStructuralAuthority, isFalse);
    });

    test('parses delegated authority without collapsing the roles', () {
      expect(
        ProjectDelegatedAuthorityRole.fromWire('co_creator'),
        ProjectDelegatedAuthorityRole.coCreator,
      );
      expect(
        ProjectDelegatedAuthorityRole.fromWire('co_organizer'),
        ProjectDelegatedAuthorityRole.coOrganizer,
      );
      expect(
        () => ProjectDelegatedAuthorityRole.fromWire('creator'),
        throwsFormatException,
      );
    });
  });
}
