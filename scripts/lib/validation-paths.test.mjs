import assert from "node:assert/strict";
import test from "node:test";

import { classifyValidationPaths } from "./validation-paths.mjs";

const none = {
  mobile: false,
  web: false,
  site: false,
  database: false,
};

test("maps application-only changes to their owning validation", () => {
  assert.deepEqual(classifyValidationPaths(["apps/mobile/lib/main.dart"]), {
    ...none,
    mobile: true,
  });
  assert.deepEqual(classifyValidationPaths(["apps/web/src/app/page.tsx"]), {
    ...none,
    web: true,
  });
  assert.deepEqual(classifyValidationPaths(["apps/site/src/App.tsx"]), {
    ...none,
    site: true,
  });
  assert.deepEqual(
    classifyValidationPaths(["supabase/migrations/20260915000000_test.sql"]),
    { ...none, database: true },
  );
});

test("maps generated database types to both database and web validation", () => {
  assert.deepEqual(
    classifyValidationPaths(["apps/web/src/types/database.generated.ts"]),
    { ...none, web: true, database: true },
  );
});

test("maps shared Node inputs to every Node-based validation", () => {
  for (const path of ["package-lock.json", ".nvmrc"]) {
    assert.deepEqual(classifyValidationPaths([path]), {
      ...none,
      web: true,
      site: true,
      database: true,
    });
  }
});

test("maps shared formatting configuration to its affected applications", () => {
  assert.deepEqual(classifyValidationPaths([".prettierignore"]), {
    ...none,
    web: true,
    site: true,
  });
  assert.deepEqual(classifyValidationPaths([".editorconfig"]), {
    mobile: true,
    web: true,
    site: true,
    database: true,
  });
});

test("maps repository-wide and workflow tooling to full validation", () => {
  for (const path of [
    "package.json",
    ".github/workflows/validation.yml",
    "scripts/classify-validation-paths.mjs",
    "unexpected-root-config.json",
  ]) {
    assert.deepEqual(classifyValidationPaths([path]), {
      mobile: true,
      web: true,
      site: true,
      database: true,
    });
  }
});

test("maps repository helper changes to their actual consumers", () => {
  assert.deepEqual(
    classifyValidationPaths(["scripts/generate-mobile-local-config.mjs"]),
    { ...none, mobile: true },
  );
  assert.deepEqual(
    classifyValidationPaths(["scripts/generate-web-local-config.mjs"]),
    { ...none, web: true, database: true },
  );
  assert.deepEqual(
    classifyValidationPaths(["scripts/generate-database-types.mjs"]),
    { ...none, web: true, database: true },
  );
  assert.deepEqual(
    classifyValidationPaths(["scripts/verify-local-proposals.mjs"]),
    { ...none, database: true },
  );
  assert.deepEqual(
    classifyValidationPaths(["scripts/lib/local-supabase-status.mjs"]),
    { ...none, mobile: true, web: true, database: true },
  );
});

test("does not start expensive validation for documentation-only changes", () => {
  assert.deepEqual(
    classifyValidationPaths([
      "README.md",
      "apps/mobile/README.md",
      "docs/development/getting-started.md",
      "history-implementations/plan.json",
    ]),
    none,
  );
});

test("unions multiple areas and normalizes Windows separators", () => {
  assert.deepEqual(
    classifyValidationPaths([
      "apps\\mobile\\lib\\main.dart",
      "apps/site/src/App.tsx",
    ]),
    { ...none, mobile: true, site: true },
  );
});

test("manual full validation enables every area", () => {
  assert.deepEqual(classifyValidationPaths([], { forceAll: true }), {
    mobile: true,
    web: true,
    site: true,
    database: true,
  });
});
