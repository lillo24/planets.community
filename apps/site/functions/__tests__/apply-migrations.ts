import { applyD1Migrations } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach } from "vitest";

beforeEach(async () => {
  await applyD1Migrations(env.WAITLIST_DB, env.TEST_MIGRATIONS);
  await env.WAITLIST_DB.prepare("DELETE FROM launch_waitlist").run();
});
