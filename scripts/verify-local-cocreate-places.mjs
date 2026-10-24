import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { verifyCocreatePlaces } from "./lib/cocreate-places-verifier.mjs";
const { sql, status } = openCocreateLocalBackend();
try {
  await verifyCocreatePlaces({ sql, status });
} finally {
  await sql.end();
}
