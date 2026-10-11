import '../../proposals/domain/proposal_time.dart';

enum OrganizationDecision { location, schedule, capacity }

class OrganizationTask {
  const OrganizationTask({
    required this.id,
    required this.parentId,
    required this.title,
    required this.done,
    required this.canEdit,
    required this.canRemove,
  });
  final String id;
  final String? parentId;
  final String title;
  final bool done, canEdit, canRemove;
}

/// Only the identity-bound RPC can supply these private values. They must never
/// be composed into a public Proposal, notification, location preview or cache.
class ProjectOrganization {
  const ProjectOrganization({
    required this.projectId,
    required this.revision,
    required this.isIdea,
    required this.canMutate,
    required this.canPlan,
    required this.canManageTasks,
    required this.scheduleReady,
    required this.proposed,
    required this.official,
    required this.tasks,
  });
  final String projectId;
  final int revision;
  final bool isIdea, canMutate, canPlan, canManageTasks, scheduleReady;
  final Map<OrganizationDecision, Map<String, dynamic>> proposed, official;
  final List<OrganizationTask> tasks;

  factory ProjectOrganization.parse(Object? payload, String projectId) {
    if (payload is! Map ||
        payload['project_id'] != projectId ||
        payload['revision'] is! int ||
        (payload['revision'] as int) < 0 ||
        !['idea', 'defined'].contains(payload['definition_phase']) ||
        payload['can_mutate'] is! bool ||
        payload['can_plan'] is! bool ||
        payload['can_manage_tasks'] is! bool ||
        payload['tasks'] is! List ||
        (payload['tasks'] as List).length > 120) {
      throw const FormatException('Malformed Project Organization snapshot.');
    }
    Map<OrganizationDecision, Map<String, dynamic>> decisions(Object? raw) {
      if (raw is! Map) {
        throw const FormatException('Malformed planning decisions.');
      }
      return {
        for (final kind in OrganizationDecision.values)
          if (raw[kind.name] != null) kind: _decision(kind, raw[kind.name]),
      };
    }

    final tasks = <OrganizationTask>[];
    final ids = <String>{};
    for (final raw in payload['tasks'] as List) {
      if (raw is! Map ||
          raw['id'] is! String ||
          !ids.add(raw['id'] as String) ||
          (raw['parent_id'] != null && raw['parent_id'] is! String) ||
          raw['title'] is! String ||
          (raw['title'] as String).trim().isEmpty ||
          (raw['title'] as String).length > 160 ||
          raw['done'] is! bool ||
          raw['can_edit'] is! bool ||
          raw['can_remove'] is! bool) {
        throw const FormatException('Malformed Organization task.');
      }
      tasks.add(
        OrganizationTask(
          id: raw['id'] as String,
          parentId: raw['parent_id'] as String?,
          title: raw['title'] as String,
          done: raw['done'] as bool,
          canEdit: raw['can_edit'] as bool,
          canRemove: raw['can_remove'] as bool,
        ),
      );
    }
    for (final task in tasks.where((t) => t.parentId != null)) {
      if (!tasks.any((p) => p.id == task.parentId && p.parentId == null)) {
        throw const FormatException('Invalid Organization task depth/parent.');
      }
    }
    return ProjectOrganization(
      projectId: projectId,
      revision: payload['revision'] as int,
      isIdea: payload['definition_phase'] == 'idea',
      canMutate: payload['can_mutate'] as bool,
      canPlan: payload['can_plan'] as bool,
      canManageTasks: payload['can_manage_tasks'] as bool,
      scheduleReady: payload['schedule_ready'] == true,
      proposed: Map.unmodifiable(decisions(payload['proposals'])),
      official: Map.unmodifiable(decisions(payload['official'])),
      tasks: List.unmodifiable(tasks),
    );
  }

  static Map<String, dynamic> _decision(
    OrganizationDecision kind,
    Object? raw,
  ) {
    if (raw is! Map) throw const FormatException('Malformed planning value.');
    final value = Map<String, dynamic>.from(raw);
    switch (kind) {
      case OrganizationDecision.location:
        if (value['text'] is! String ||
            (value['text'] as String).trim().isEmpty ||
            [
              'country_code',
              'locality',
              'label',
              'administrative_area',
            ].any((k) => value[k] != null && value[k] is! String)) {
          throw const FormatException('Malformed planning location.');
        }
      case OrganizationDecision.schedule:
        // Imported publication suggestions can be incomplete; they are not
        // promotion-ready and must be corrected before confirmation.
        for (final key in ['starts_at', 'ends_at']) {
          if (value[key] != null &&
              (value[key] is! String ||
                  DateTime.tryParse(value[key] as String) == null)) {
            throw const FormatException('Malformed planning schedule.');
          }
        }
        if (value['timezone'] != null &&
            (value['timezone'] is! String ||
                !isKnownProposalTimeZone(value['timezone'] as String))) {
          throw const FormatException('Malformed planning timezone.');
        }
      case OrganizationDecision.capacity:
        if (value['limit'] is! int ||
            (value['limit'] as int) < 1 ||
            (value['limit'] as int) > 100000 ||
            value['count_organizers'] is! bool) {
          throw const FormatException('Malformed planning capacity.');
        }
    }
    return Map.unmodifiable(value);
  }
}
