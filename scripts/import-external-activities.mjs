import { createClient } from "@supabase/supabase-js";
import { ActivityImportError } from "./lib/external-activities/transport.mjs";
import {
  activityImportArguments,
  activityImportStore,
  officialActivityConnector,
  runActivityImport,
} from "./lib/external-activities/importer.mjs";

try {
  const options = activityImportArguments(process.argv.slice(2));
  // Resolve the code-owned connector first: missing rights must never cause
  // provider IO, even when a hosted target and credentials have been supplied.
  const connector = officialActivityConnector(options.source);
  let store;
  if (options.apply) {
    const apiUrl = process.env.ACTIVITIES_API_URL;
    const key = process.env.ACTIVITIES_SERVICE_ROLE_KEY;
    if (!apiUrl || !key || options.target !== process.env.ACTIVITIES_TARGET)
      throw new ActivityImportError("missing_explicit_target");
    const url = new URL(apiUrl);
    if (
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      !(
        url.protocol === "https:" ||
        (url.protocol === "http:" &&
          ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname))
      )
    )
      throw new ActivityImportError("invalid_target");
    store = activityImportStore(
      createClient(apiUrl, key, {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      }),
    );
  }
  const result = await runActivityImport({
    connector,
    store,
    apply: options.apply,
  });
  process.stdout.write(JSON.stringify(result) + "\n");
} catch (error) {
  const code =
    error instanceof ActivityImportError ? error.code : "internal_error";
  process.stderr.write(
    `External activities: ${code}. No successful import is confirmed.\n`,
  );
  process.exitCode = 1;
}
