// Only repository-authored messages are safe for public Actions output. Native
// JSON, database, network and tool errors may include credentials or user data.
export class ReleaseError extends Error {}
export function reportFailure(stage, error) {
  console.error(
    `RELEASE01 ${stage} failed: ${error instanceof ReleaseError ? error.message : "Unexpected I/O/provider failure (details withheld). Inspect the sanitized evidence and operator runbook privately."}`,
  );
  process.exitCode = 1;
}
