/// Private, in-memory navigation marker; it grants no publishing authority.
/// The optional destination stays in route memory and grants no room access.
class GroupProjectCreationReturn {
  const GroupProjectCreationReturn(this.actor, {this.returnPath});
  final String actor;
  final String? returnPath;
}

/// Only an acknowledged ordinary editor save returns a canonical Project ID.
class GroupProjectCreationResult {
  const GroupProjectCreationResult(this.actor, this.projectId);
  final String actor, projectId;
}
