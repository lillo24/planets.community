import { describe, expect, it } from "vitest";
import { containsInvitationSecret } from "./invitation-privacy";
import {
  createSentryBrowserOptions,
  createSentryServerOptions,
} from "./sentry-options";
import { parseSentryEnv } from "../config/public-env";
const token = "a".repeat(43);
const config = parseSentryEnv({
  NEXT_PUBLIC_APP_ENV: "production",
  NEXT_PUBLIC_SENTRY_DSN: "https://public@example.ingest.sentry.io/1",
});
describe("invitation telemetry privacy", () => {
  it.each([
    `/join/project/${token}`,
    `/invite/project/${token}`,
    `/auth?returnTo=${encodeURIComponent(`/join/project/${token}`)}`,
    `/profile?returnTo=${encodeURIComponent(encodeURIComponent(`/join/project/${token}`))}`,
    { request: { data: { p_token: "short-secret" } } },
    { invite_token: "short-secret" },
    JSON.stringify({ p_token: "short-secret" }),
    encodeURIComponent(JSON.stringify({ invite_token: "short-secret" })),
    new Error(`RPC input ${token}`),
    { exception: { values: [{ value: token }] } },
  ])(
    "detects direct, encoded, RPC and serialized exception secrets",
    (value) => {
      expect(containsInvitationSecret(value)).toBe(true);
    },
  );
  it("handles cycles and preserves ordinary/token-free URLs", () => {
    const circular: Record<string, unknown> = {};
    circular.self = circular;
    expect(containsInvitationSecret(circular)).toBe(false);
    expect(
      containsInvitationSecret({
        request: {
          url: "https://planets.community/proposals/00000000-0000-4000-8000-000000000001?intent=join",
        },
      }),
    ).toBe(false);
    expect(
      containsInvitationSecret(
        "/joined/tavoli/00000000-0000-4000-8000-000000000001",
      ),
    ).toBe(false);
  });
  it.each([createSentryBrowserOptions, createSentryServerOptions])(
    "drops secret-bearing events/breadcrumbs and original Error hints",
    (factory) => {
      const options = factory(config);
      expect(
        options.beforeSend(
          { type: undefined, request: { url: `/join/project/${token}` } },
          {},
        ),
      ).toBeNull();
      expect(
        options.beforeSend(
          { type: undefined, message: "safe failure" },
          { originalException: new Error(token) },
        ),
      ).toBeNull();
      expect(
        options.beforeBreadcrumb({
          category: "fetch",
          data: { p_token: token },
        }),
      ).toBeNull();
      expect(
        options.beforeSend(
          {
            type: undefined,
            message: "Participant invitation operation: network.",
          },
          {},
        ),
      ).toEqual({
        type: undefined,
        message: "Participant invitation operation: network.",
      });
      expect(
        options.beforeBreadcrumb({
          category: "navigation",
          data: { to: "/proposals" },
        }),
      ).toEqual({ category: "navigation", data: { to: "/proposals" } });
    },
  );
});
