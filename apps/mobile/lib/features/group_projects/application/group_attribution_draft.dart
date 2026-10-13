import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/group_project_gateway.dart';
import '../domain/group_project_models.dart';
import '../domain/group_project_failures.dart';

/// Editor-owned, actor-bound command state. A receipt never supplies authority.
class GroupAttributionDraft {
  GroupAttributionDraft(
    this.gateway,
    this.actor, {
    ProjectGroupBinding binding = const ProjectGroupBinding(),
    String? initialGroup,
  }) : confirmed = binding,
       groupId = initialGroup ?? binding.groupId;
  final GroupProjectGateway gateway;
  final String actor;
  ProjectGroupBinding confirmed;
  String? groupId;
  bool failed = false;
  bool conflict = false;
  Future<void>? _reload;
  bool get dirty => groupId != confirmed.groupId;
  bool get pending => _request != null;
  String? _project, _request, _intentGroup;
  int? _intentVersion;
  bool _created = false;

  void select(String? id) {
    if (pending || conflict || confirmed.frozen || _reload != null) {
      throw StateError(
        'Resolve the attribution command before changing its intent.',
      );
    }
    groupId = id;
    failed = false;
  }

  Future<void> reload() async {
    if (pending || _project == null) {
      throw StateError('Resolve the command before reloading.');
    }
    final task = gateway.own(actor, _project!).then((current) {
      confirmed = current;
      groupId = current.groupId;
      conflict = false;
      failed = false;
    });
    _reload = task;
    try {
      await task;
    } finally {
      _reload = null;
    }
  }

  Future<void> persist(
    String project, {
    required bool created,
    String? createdGroup,
  }) async {
    await _reload;
    if (conflict) throw StateError('Reload the group choice before retrying.');
    if (_project != null && _project != project) {
      throw StateError('Attribution cannot retarget another Project.');
    }
    _project = project;
    // Atomic creation may already have accepted this association. Reread the
    // same destination before a newer selection or any attempted publication.
    if (created &&
        !_created &&
        (createdGroup != null || groupId != null || dirty)) {
      confirmed = await gateway.own(actor, project);
      _created = true;
    }
    if (!dirty && !pending) return;
    _request ??= const Uuid().v4();
    if (_intentVersion == null) {
      _intentVersion = confirmed.version;
      _intentGroup = groupId;
    }
    try {
      await gateway.set(
        actor,
        project,
        _request!,
        _intentVersion!,
        _intentGroup,
      );
    } on PostgrestException catch (error) {
      // A definitive rejected command did not commit. A transport/unknown
      // outcome retains its exact actor/key/version/intent for recovery.
      if (isGroupRepresentationRejection(error) ||
          {'22023', 'PT409', '55000'}.contains(error.code)) {
        conflict = {'PT409', '55000'}.contains(error.code);
        _request = null;
        _intentVersion = null;
        _intentGroup = null;
      }
      rethrow;
    }
    final current = await gateway.own(actor, project);
    if (current.groupId != _intentGroup ||
        current.version != _intentVersion! + 1) {
      _request = null;
      _intentVersion = null;
      _intentGroup = null;
      conflict = true;
      throw StateError('Attribution changed. Explicitly reload this choice.');
    }
    confirmed = current;
    _request = null;
    _intentVersion = null;
    _intentGroup = null;
  }
}
