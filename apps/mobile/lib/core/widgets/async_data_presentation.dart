enum AsyncDataPresentation { loading, content, absent, failure }

/// Classifies an asynchronous screen without treating pre-request null data as
/// a failure. Retained usable data wins while refreshes are in flight or fail.
AsyncDataPresentation classifyAsyncDataPresentation({
  required bool hasData,
  required bool isPending,
  required bool hasFailed,
}) {
  if (hasData) return AsyncDataPresentation.content;
  if (hasFailed) return AsyncDataPresentation.failure;
  if (isPending) return AsyncDataPresentation.loading;
  return AsyncDataPresentation.absent;
}
