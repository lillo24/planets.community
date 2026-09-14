import path from "node:path";

import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  const migrations = await readD1Migrations(
    path.join(import.meta.dirname, "migrations"),
  );

  return {
    plugins: [
      cloudflareTest({
        miniflare: {
          compatibilityDate: "2026-09-13",
          d1Databases: ["WAITLIST_DB"],
          bindings: {
            TURNSTILE_SECRET_KEY: "test-secret",
            TURNSTILE_EXPECTED_ACTION: "waitlist_signup",
            TURNSTILE_EXPECTED_HOSTNAME: "planets.test",
            TURNSTILE_TESTING_MODE: "false",
            TEST_MIGRATIONS: migrations,
          },
        },
      }),
    ],
    test: {
      include: ["worker/__tests__/**/*.test.ts"],
      setupFiles: ["./worker/__tests__/apply-migrations.ts"],
    },
  };
});
