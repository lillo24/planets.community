import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { sha256 } from "./sql-fingerprint.mjs";
import { ReleaseError } from "./errors.mjs";

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
