import { describe, expect, it } from "vitest";

import {
  getPublicEnvDiagnostics,
  parsePublicEnv,
  parseSentryEnv,
  PublicEnvError,
} from "@/lib/config/public-env";

const validInput = {
  NEXT_PUBLIC_APP_ENV: "local",
  NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-publishable-key",
  NEXT_PUBLIC_SENTRY_DSN: "",
};

describe("parsePublicEnv", () => {
  it("parses the local public configuration and disables optional Sentry", () => {
    expect(parsePublicEnv(validInput)).toEqual({
      appEnv: "local",
      supabaseUrl: "http://127.0.0.1:54321",
      supabasePublishableKey: "local-publishable-key",
    });
  });

  it("requires every canonical Supabase value", () => {
    expect(() =>
      parsePublicEnv({
        ...validInput,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "",
      }),
    ).toThrowError(
      new PublicEnvError("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required."),
    );
  });

  it("requires a Supabase URL only when the full public config is used", () => {
    expect(() =>
      parsePublicEnv({
        ...validInput,
        NEXT_PUBLIC_SUPABASE_URL: undefined,
      }),
    ).toThrow("NEXT_PUBLIC_SUPABASE_URL is required");

    expect(
      parseSentryEnv({
        NEXT_PUBLIC_APP_ENV: undefined,
        NEXT_PUBLIC_SENTRY_DSN: "",
      }),
    ).toEqual({});
  });

  it("rejects non-HTTPS shared environments", () => {
    expect(() =>
      parsePublicEnv({
        ...validInput,
        NEXT_PUBLIC_APP_ENV: "staging",
      }),
    ).toThrow("must use HTTPS outside local development");
  });

  it("rejects unknown application environments", () => {
    expect(() =>
      parsePublicEnv({
        ...validInput,
        NEXT_PUBLIC_APP_ENV: "preview",
      }),
    ).toThrow("must be local, staging, or production");
  });

  it("rejects a malformed non-empty Sentry DSN", () => {
    expect(() =>
      parsePublicEnv({
        ...validInput,
        NEXT_PUBLIC_SENTRY_DSN: "not-a-url",
      }),
    ).toThrow("NEXT_PUBLIC_SENTRY_DSN must be a valid absolute URL");
  });

  it("returns diagnostics without the publishable key or Sentry DSN", () => {
    const config = parsePublicEnv({
      ...validInput,
      NEXT_PUBLIC_SENTRY_DSN: "https://public@example.ingest.sentry.io/1",
    });

    const diagnostics = getPublicEnvDiagnostics(config);

    expect(diagnostics).toEqual({
      appEnv: "local",
      supabaseOrigin: "http://127.0.0.1:54321",
      sentryEnabled: true,
    });
    expect(JSON.stringify(diagnostics)).not.toContain("local-publishable-key");
    expect(JSON.stringify(diagnostics)).not.toContain("example.ingest");
  });
});
