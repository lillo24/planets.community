import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { seedCocreateLocalCatalogue } from "./lib/cocreate-local-fixtures.mjs";
const { sql } = openCocreateLocalBackend();
try {
  await seedCocreateLocalCatalogue(sql);
  console.log(
    "Synthetic local co-creation catalogue seeded (3 topics / 3 hubs). Activation unchanged.",
  );
} finally {
  await sql.end();
}
