import 'package:planets_mobile/features/project_organization/domain/project_organization.dart';

/// Fictional, data-free review fixture. Never a backend identity/Project seed.
ProjectOrganization organizationFixture({
  String state = 'proposed',
  bool canPlan = true,
  bool canMutate = true,
  int revision = 1,
  Map<String, dynamic>? locationValue,
  Map<String, dynamic>? scheduleValue,
}) {
  const location = {
    'text': 'Trento',
    'locality': 'Trento',
    'country_code': 'IT',
    'label': 'Trento',
  };
  const replacement = {
    'text': 'Rovereto',
    'locality': 'Rovereto',
    'country_code': 'IT',
    'label': 'Rovereto',
  };
  const schedule = {
    'starts_at': '2027-05-03T08:00:00Z',
    'ends_at': '2027-05-05T16:00:00Z',
    'timezone': 'Europe/Rome',
  };
  const capacity = {'limit': 12, 'count_organizers': false};
  final values = {
    'location': locationValue ?? location,
    'schedule': scheduleValue ?? schedule,
    'capacity': capacity,
  };
  return ProjectOrganization.parse({
    'project_id': 'fictional-check01',
    'revision': revision,
    'definition_phase': state == 'defined' ? 'defined' : 'idea',
    'can_mutate': canMutate,
    'can_plan': canPlan,
    'can_manage_tasks': canPlan,
    'schedule_ready': state != 'stale',
    'proposals': switch (state) {
      'proposed' => values,
      'replacement' => {'location': replacement},
      _ => {},
    },
    'official': switch (state) {
      'confirmed' || 'replacement' || 'defined' || 'stale' => values,
      _ => {},
    },
    'tasks': [
      {
        'id': 'materials',
        'parent_id': null,
        'title': 'Organizzare i materiali',
        'done': false,
        'can_edit': true,
        'can_remove': false,
      },
      {
        'id': 'tools',
        'parent_id': 'materials',
        'title': 'Contattare chi ha gli attrezzi',
        'done': true,
        'can_edit': false,
        'can_remove': false,
      },
      {
        'id': 'missing',
        'parent_id': 'materials',
        'title': 'Preparare il materiale mancante',
        'done': false,
        'can_edit': true,
        'can_remove': true,
      },
      {
        'id': 'poster',
        'parent_id': null,
        'title': 'Preparare una locandina',
        'done': false,
        'can_edit': true,
        'can_remove': true,
      },
    ],
  }, 'fictional-check01');
}
