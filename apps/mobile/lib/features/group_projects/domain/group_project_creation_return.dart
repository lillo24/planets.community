/// Private, in-memory navigation marker; it grants no publishing authority.
/// The optional destination stays in route memory and grants no room access.
class GroupProjectCreationReturn {
  const GroupProjectCreationReturn(this.actor, {this.returnPath, this.readObserver});
  final String actor;
  final String? returnPath;
  // Compose Workshop's actual editor-read acknowledgement with the private
  // Group/source return destination; neither marker grants domain authority.
  final ProposalEditorReadObserver? readObserver;
}

/// Only an acknowledged ordinary editor save returns a canonical Project ID.
class GroupProjectCreationResult {
  const GroupProjectCreationResult(this.actor, this.projectId);
  final String actor, projectId;
}
import '../../proposals/domain/proposal_models.dart';
