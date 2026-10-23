import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { sha256 } from "./sql-fingerprint.mjs";
import { ReleaseError } from "./errors.mjs";

// These startup defaults apply to each separate CLI connection. RESET restores
// the same bounds; an empty DDL search path cannot invoke project overloads.
export const migrationStartupOptions =
  "-c lock_timeout=5000 -c statement_timeout=60000 -c search_path=pg_catalog -c default_table_access_method=heap";
export const migrationStartupProbe =
  "select 1 / ((current_setting('lock_timeout')::interval = interval '5 seconds') and (current_setting('statement_timeout')::interval = interval '60 seconds') and current_setting('search_path')='pg_catalog' and current_setting('default_table_access_method')='heap')::integer as verified_startup_bounds";

// Public CA downloaded from the authenticated staging dashboard's SSL link.
// Pin bytes so a damaged/replaced local trust file fails before connecting.
export const stagingCaPath = fileURLToPath(
  new URL("./supabase-prod-ca-2021.crt", import.meta.url),
);
export function stagingTlsOptions() {
  const ca = readFileSync(stagingCaPath);
  if (
    sha256(ca) !==
    "700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7"
  )
    throw new ReleaseError(
      "Staging database CA differs from the reviewed certificate",
    );
  return { rejectUnauthorized: true, ca };
}
