import { createClient } from "@supabase/supabase-js";
import { ActivityImportError } from "./lib/external-activities/transport.mjs";
import {
  activityOperationArguments,
  activityOperationStore,
  activityOperationTarget,
  activityRefreshPolicy,
  runActivityOperations,
} from "./lib/external-activities/operations.mjs";

const controller = new AbortController();
const interrupt = () => controller.abort();
process.once("SIGINT", interrupt);
process.once("SIGTERM", interrupt);
try {
  const options = activityOperationArguments(process.argv.slice(2));
  const policy = activityRefreshPolicy(
    process.env.ACTIVITIES_REFRESH_POLICY_JSON,
  );
  let store;
  if (options.mode !== "dry-run") {
    const { apiUrl, key } = activityOperationTarget(options, process.env);
    store = activityOperationStore(
      createClient(apiUrl, key, {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      }),
    );
  }
  const result = await runActivityOperations({
    ...options,
    policy,
    store,
    parentSignal: controller.signal,
  });
  process.stdout.write(JSON.stringify(result) + "\n");
  if (result.status !== "success") process.exitCode = 1;
} catch (error) {
  const code =
    error instanceof ActivityImportError ? error.code : "internal_error";
  process.stderr.write(
    `External activity operations: ${code}. No complete refresh is confirmed.\n`,
  );
  process.exitCode = 1;
} finally {
  process.removeListener("SIGINT", interrupt);
  process.removeListener("SIGTERM", interrupt);
}
