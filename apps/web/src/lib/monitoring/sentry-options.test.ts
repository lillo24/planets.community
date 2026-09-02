import { describe, expect, it } from "vitest";

import { parseSentryEnv } from "@/lib/config/public-env";
import {
  createSentryBrowserOptions,
  createSentryServerOptions,
} from "@/lib/monitoring/sentry-options";

const config = parseSentryEnv({
  NEXT_PUBLIC_APP_ENV: "production",
  NEXT_PUBLIC_SENTRY_DSN: "https://public@example.ingest.sentry.io/1",
});

describe("Sentry privacy defaults", () => {
  it("disables PII collection and tracing on the server", () => {
    expect(createSentryServerOptions(config)).toMatchObject({
      enabled: true,
      environment: "production",
      sendDefaultPii: false,
      tracesSampleRate: 0,
    });
  });

  it("also disables browser session replay", () => {
    expect(createSentryBrowserOptions(config)).toMatchObject({
      replaysOnErrorSampleRate: 0,
      replaysSessionSampleRate: 0,
    });
  });
});
