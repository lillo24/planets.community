/// Private, in-memory navigation marker; it grants no publishing authority.
/// Room identifiers/content stay with the originating discussion route.
class GroupProjectCreationReturn {
  const GroupProjectCreationReturn(this.actor);
  final String actor;
}

/// Only an acknowledged ordinary editor save returns a canonical Project ID.
class GroupProjectCreationResult {
  const GroupProjectCreationResult(this.actor, this.projectId);
  final String actor, projectId;
}
