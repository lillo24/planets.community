import { env } from "cloudflare:workers";
import { describe, expect, it, vi } from "vitest";

import { handleWaitlistRequest, WAITLIST_CONSENT_VERSION } from "../waitlist";

const validBody = {
  email: " Person@example.com ",
  consent: true,
  turnstileToken: "valid-test-token",
};

const firstSignupTime = "2026-09-13T09:00:00.000Z";

function requestWithBody(body: unknown) {
  return new Request("https://planets.test/api/waitlist", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function successfulVerification() {
  return vi.fn(async () =>
    Response.json({
      success: true,
      action: env.TURNSTILE_EXPECTED_ACTION,
      hostname: env.TURNSTILE_EXPECTED_HOSTNAME,
    }),
  );
}

function invoke(
  body: unknown = validBody,
  request = successfulVerification(),
  now = firstSignupTime,
) {
  return handleWaitlistRequest(requestWithBody(body), env, {
    fetch: request,
    now: () => now,
  });
}

describe("POST /api/waitlist", () => {
  it("rejects methods other than POST", async () => {
    const request = new Request("https://planets.test/api/waitlist");

    const response = await handleWaitlistRequest(request, env);

    expect(response.status).toBe(405);
    expect(response.headers.get("Allow")).toBe("POST");
  });

  it("rejects malformed JSON and an unsupported content type", async () => {
    const malformedResponse = await handleWaitlistRequest(
      new Request("https://planets.test/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{",
      }),
      env,
    );
    const unsupportedResponse = await handleWaitlistRequest(
      new Request("https://planets.test/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify(validBody),
      }),
      env,
    );

    expect(malformedResponse.status).toBe(400);
    expect(unsupportedResponse.status).toBe(400);
  });

  it("rejects invalid email input without calling Turnstile", async () => {
    const verification = successfulVerification();

    const response = await invoke(
      { ...validBody, email: "not-an-email" },
      verification,
    );

    expect(response.status).toBe(400);
    expect(verification).not.toHaveBeenCalled();
  });

  it("rejects missing or false consent", async () => {
    const missingConsent = { ...validBody } as Record<string, unknown>;
    delete missingConsent.consent;

    const missingResponse = await invoke(missingConsent);
    const falseResponse = await invoke({ ...validBody, consent: false });

    expect(missingResponse.status).toBe(400);
    expect(falseResponse.status).toBe(400);
  });

  it("rejects a missing Turnstile token", async () => {
    const response = await invoke({ ...validBody, turnstileToken: "" });

    expect(response.status).toBe(400);
  });

  it("fails closed when Turnstile rejects the token", async () => {
    const response = await invoke(
      validBody,
      vi.fn(async () => Response.json({ success: false })),
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      ok: false,
      code: "verification_failed",
    });
    const stored = await env.WAITLIST_DB.prepare(
      "SELECT count(*) AS total FROM launch_waitlist",
    ).first<{ total: number }>();
    expect(stored?.total).toBe(0);
  });

  it("requires the configured Turnstile action and hostname outside testing mode", async () => {
    const wrongAction = await invoke(
      validBody,
      vi.fn(async () =>
        Response.json({
          success: true,
          action: "other_action",
          hostname: env.TURNSTILE_EXPECTED_HOSTNAME,
        }),
      ),
    );
    const wrongHostname = await invoke(
      validBody,
      vi.fn(async () =>
        Response.json({
          success: true,
          action: env.TURNSTILE_EXPECTED_ACTION,
          hostname: "other.example",
        }),
      ),
    );

    expect(wrongAction.status).toBe(403);
    expect(wrongHostname.status).toBe(403);
    const stored = await env.WAITLIST_DB.prepare(
      "SELECT count(*) AS total FROM launch_waitlist",
    ).first<{ total: number }>();
    expect(stored?.total).toBe(0);
  });

  it("accepts only a provider-marked result in explicit testing mode", async () => {
    const testingEnv: WaitlistEnv = {
      WAITLIST_DB: env.WAITLIST_DB,
      TURNSTILE_SECRET_KEY: env.TURNSTILE_SECRET_KEY,
      TURNSTILE_EXPECTED_ACTION: env.TURNSTILE_EXPECTED_ACTION,
      TURNSTILE_EXPECTED_HOSTNAME: "example.com",
      TURNSTILE_TESTING_MODE: "true",
    };
    const verification = vi.fn(async () =>
      Response.json({
        success: true,
        hostname: "example.com",
        metadata: { result_with_testing_key: true },
      }),
    );

    const response = await handleWaitlistRequest(
      requestWithBody(validBody),
      testingEnv,
      {
        fetch: verification,
        now: () => firstSignupTime,
      },
    );
    const unmarkedResponse = await handleWaitlistRequest(
      requestWithBody(validBody),
      testingEnv,
      {
        fetch: vi.fn(async () =>
          Response.json({
            success: true,
            hostname: "example.com",
          }),
        ),
        now: () => firstSignupTime,
      },
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
    expect(unmarkedResponse.status).toBe(403);
  });

  it("normalizes and stores only the one-purpose waitlist fields", async () => {
    const response = await invoke();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
    const stored = await env.WAITLIST_DB.prepare(
      "SELECT * FROM launch_waitlist",
    ).first<{
      email: string;
      created_at: string;
      consented_at: string;
      consent_version: string;
      notified_at: string | null;
    }>();
    expect(stored).toEqual({
      email: "person@example.com",
      created_at: firstSignupTime,
      consented_at: firstSignupTime,
      consent_version: WAITLIST_CONSENT_VERSION,
      notified_at: null,
    });
  });

  it("keeps duplicate signup idempotent and membership-private", async () => {
    const firstResponse = await invoke();
    const firstBody = await firstResponse.text();
    const notifiedAt = "2026-09-13T09:30:00.000Z";
    await env.WAITLIST_DB.prepare(
      "UPDATE launch_waitlist SET notified_at = ? WHERE email = ?",
    )
      .bind(notifiedAt, "person@example.com")
      .run();
    const duplicateResponse = await invoke(
      { ...validBody, email: "PERSON@EXAMPLE.COM" },
      successfulVerification(),
      "2026-09-13T10:00:00.000Z",
    );
    const duplicateBody = await duplicateResponse.text();

    const stored = await env.WAITLIST_DB.prepare(
      `SELECT
        count(*) AS total,
        min(created_at) AS created_at,
        min(notified_at) AS notified_at
       FROM launch_waitlist`,
    ).first<{ total: number; created_at: string; notified_at: string }>();

    expect(duplicateResponse.status).toBe(200);
    expect(duplicateBody).toBe(firstBody);
    expect(stored).toEqual({
      total: 1,
      created_at: firstSignupTime,
      notified_at: notifiedAt,
    });
  });

  it("fails safely without logging the submitted address or token", async () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const failingEnv: WaitlistEnv = {
      WAITLIST_DB: {
        prepare: () => {
          throw new Error("simulated D1 failure");
        },
      } as unknown as D1Database,
      TURNSTILE_SECRET_KEY: env.TURNSTILE_SECRET_KEY,
      TURNSTILE_EXPECTED_ACTION: env.TURNSTILE_EXPECTED_ACTION,
      TURNSTILE_EXPECTED_HOSTNAME: env.TURNSTILE_EXPECTED_HOSTNAME,
      TURNSTILE_TESTING_MODE: env.TURNSTILE_TESTING_MODE,
    };

    const response = await handleWaitlistRequest(
      requestWithBody(validBody),
      failingEnv,
      {
        fetch: successfulVerification(),
        now: () => firstSignupTime,
      },
    );
    const logged = JSON.stringify(errorSpy.mock.calls);

    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({
      ok: false,
      code: "server_error",
    });
    expect(logged).toContain("Waitlist persistence failed.");
    expect(logged).not.toContain("Person@example.com");
    expect(logged).not.toContain("valid-test-token");
  });

  it("fails closed when Turnstile configuration is incomplete", async () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const incompleteEnv: WaitlistEnv = {
      WAITLIST_DB: env.WAITLIST_DB,
      TURNSTILE_SECRET_KEY: "",
      TURNSTILE_EXPECTED_ACTION: env.TURNSTILE_EXPECTED_ACTION,
      TURNSTILE_EXPECTED_HOSTNAME: env.TURNSTILE_EXPECTED_HOSTNAME,
      TURNSTILE_TESTING_MODE: env.TURNSTILE_TESTING_MODE,
    };

    const response = await handleWaitlistRequest(
      requestWithBody(validBody),
      incompleteEnv,
    );

    expect(response.status).toBe(500);
    expect(errorSpy).toHaveBeenCalledWith(
      "Waitlist Turnstile configuration is incomplete.",
    );
  });
});

describe("D1 waitlist migration", () => {
  it("creates only the expected minimal columns", async () => {
    const columns = await env.WAITLIST_DB.prepare(
      "PRAGMA table_info(launch_waitlist)",
    ).all<{ name: string }>();

    expect(columns.results.map((column) => column.name)).toEqual([
      "email",
      "created_at",
      "consented_at",
      "consent_version",
      "notified_at",
    ]);
  });

  it("enforces normalized-email uniqueness and the consent version", async () => {
    const insert = (email: string, consentVersion = WAITLIST_CONSENT_VERSION) =>
      env.WAITLIST_DB.prepare(
        `INSERT INTO launch_waitlist (
          email, created_at, consented_at, consent_version
        ) VALUES (?, ?, ?, ?)`,
      )
        .bind(email, firstSignupTime, firstSignupTime, consentVersion)
        .run();

    await insert("case@example.com");

    await expect(insert("CASE@example.com")).rejects.toThrow();
    await expect(
      insert("other@example.com", "newsletter_v1"),
    ).rejects.toThrow();
  });
});
