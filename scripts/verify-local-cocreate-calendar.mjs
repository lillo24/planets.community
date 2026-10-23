import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { verifyCocreateCalendar } from "./lib/cocreate-calendar-verifier.mjs";

const backend = openCocreateLocalBackend();
try {
  await verifyCocreateCalendar(backend);
} finally {
  await backend.sql.end();
}
