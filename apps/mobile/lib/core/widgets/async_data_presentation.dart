enum AsyncDataPresentation { loading, content, absent, failure }

/// Classifies an asynchronous screen without treating pre-request or
/// different-target state as a failure. Retained usable data wins while the
/// same target refreshes or fails.
AsyncDataPresentation classifyAsyncDataPresentation({
  bool belongsToTarget = true,
  required bool hasData,
  required bool isPending,
  required bool hasFailed,
}) {
  if (!belongsToTarget) return AsyncDataPresentation.loading;
  if (hasData) return AsyncDataPresentation.content;
  if (hasFailed) return AsyncDataPresentation.failure;
  if (isPending) return AsyncDataPresentation.loading;
  return AsyncDataPresentation.absent;
}
