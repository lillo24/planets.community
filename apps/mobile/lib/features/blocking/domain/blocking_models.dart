const blockingPageSize = 20;

class BlockedProfile {
  const BlockedProfile({
    required this.blockEpisodeId,
    required this.profileId,
    required this.displayName,
    required this.blockedAt,
  });

  final String blockEpisodeId;
  final String profileId;
  final String displayName;
  final DateTime blockedAt;
}

class BlockedProfilesPage {
  const BlockedProfilesPage({required this.items, required this.hasMore});

  final List<BlockedProfile> items;
  final bool hasMore;
}

enum BlockingListPhase { idle, loading, loadingMore, ready, failure }

enum BlockingMutation { blocking, unblocking }

enum BlockingFailureKind {
  invalidInput,
  forbidden,
  targetUnavailable,
  interactionUnavailable,
  unavailable,
}

enum BlockingMutationOutcome {
  success,
  busy,
  staleIdentity,
  invalidInput,
  forbidden,
  targetUnavailable,
  interactionUnavailable,
  unavailable,
}
