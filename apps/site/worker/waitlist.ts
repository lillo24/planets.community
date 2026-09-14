import { validateEmailAddress } from "../src/email-validation";

export const WAITLIST_CONSENT_VERSION = "launch_notification_v1";

const SITEVERIFY_URL =
  "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const MAX_BODY_LENGTH = 4096;
const MAX_TURNSTILE_TOKEN_LENGTH = 2048;
const allowedRequestFields = new Set(["email", "consent", "turnstileToken"]);

type WaitlistRequestBody = {
  email: string;
  consent: true;
  turnstileToken: string;
};

type SiteverifyResponse = {
  success?: boolean;
  action?: string;
  hostname?: string;
  metadata?: {
    result_with_testing_key?: boolean;
  };
};

type WaitlistDependencies = {
  fetch: (input: string, init?: RequestInit) => Promise<Response>;
  now: () => string;
};

const defaultDependencies: WaitlistDependencies = {
  fetch: (input, init) => fetch(input, init),
  now: () => new Date().toISOString(),
};

function jsonResponse(status: number, body: { ok: boolean; code?: string }) {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
    },
  });
}

function parseRequestBody(value: unknown): WaitlistRequestBody | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const record = value as Record<string, unknown>;
  if (Object.keys(record).some((key) => !allowedRequestFields.has(key))) {
    return null;
  }

  if (
    typeof record.email !== "string" ||
    record.consent !== true ||
    typeof record.turnstileToken !== "string"
  ) {
    return null;
  }

  if (
    !validateEmailAddress(record.email) ||
    record.turnstileToken.length === 0 ||
    record.turnstileToken.length > MAX_TURNSTILE_TOKEN_LENGTH
  ) {
    return null;
  }

  return {
    email: record.email,
    consent: true,
    turnstileToken: record.turnstileToken,
  };
}

function hasWaitlistConfiguration(env: WaitlistEnv) {
  return (
    typeof env.TURNSTILE_SECRET_KEY === "string" &&
    env.TURNSTILE_SECRET_KEY.length > 0 &&
    typeof env.TURNSTILE_EXPECTED_ACTION === "string" &&
    env.TURNSTILE_EXPECTED_ACTION.length > 0 &&
    typeof env.TURNSTILE_EXPECTED_HOSTNAME === "string" &&
    env.TURNSTILE_EXPECTED_HOSTNAME.length > 0 &&
    (env.TURNSTILE_TESTING_MODE === "true" ||
      env.TURNSTILE_TESTING_MODE === "false")
  );
}

async function verifyTurnstile(
  token: string,
  env: WaitlistEnv,
  request: WaitlistDependencies["fetch"],
) {
  const body = new URLSearchParams({
    secret: env.TURNSTILE_SECRET_KEY,
    response: token,
  });

  try {
    const response = await request(SITEVERIFY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      return false;
    }

    const result = (await response.json()) as SiteverifyResponse;
    if (
      result.success !== true ||
      result.hostname !== env.TURNSTILE_EXPECTED_HOSTNAME
    ) {
      return false;
    }

    if (env.TURNSTILE_TESTING_MODE === "true") {
      return result.metadata?.result_with_testing_key === true;
    }

    return result.action === env.TURNSTILE_EXPECTED_ACTION;
  } catch {
    console.error("Turnstile validation request failed.");
    return false;
  }
}

export function normalizeWaitlistEmail(email: string) {
  return email.trim().toLowerCase();
}

export async function handleWaitlistRequest(
  request: Request,
  env: WaitlistEnv,
  dependencies: WaitlistDependencies = defaultDependencies,
) {
  if (request.method !== "POST") {
    return new Response(null, {
      status: 405,
      headers: {
        Allow: "POST",
        "Cache-Control": "no-store",
      },
    });
  }

  if (
    request.headers.get("Content-Type")?.split(";", 1)[0].trim() !==
    "application/json"
  ) {
    return jsonResponse(400, { ok: false, code: "invalid_request" });
  }

  if (!hasWaitlistConfiguration(env)) {
    console.error("Waitlist Turnstile configuration is incomplete.");
    return jsonResponse(500, { ok: false, code: "server_error" });
  }

  let rawBody: string;
  try {
    rawBody = await request.text();
  } catch {
    return jsonResponse(400, { ok: false, code: "invalid_request" });
  }

  if (rawBody.length > MAX_BODY_LENGTH) {
    return jsonResponse(400, { ok: false, code: "invalid_request" });
  }

  let parsedBody: unknown;
  try {
    parsedBody = JSON.parse(rawBody);
  } catch {
    return jsonResponse(400, { ok: false, code: "invalid_request" });
  }

  const body = parseRequestBody(parsedBody);
  if (body === null) {
    return jsonResponse(400, { ok: false, code: "invalid_request" });
  }

  if (!(await verifyTurnstile(body.turnstileToken, env, dependencies.fetch))) {
    return jsonResponse(403, {
      ok: false,
      code: "verification_failed",
    });
  }

  const normalizedEmail = normalizeWaitlistEmail(body.email);
  const timestamp = dependencies.now();

  try {
    await env.WAITLIST_DB.prepare(
      `INSERT INTO launch_waitlist (
        email,
        created_at,
        consented_at,
        consent_version
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(email) DO NOTHING`,
    )
      .bind(normalizedEmail, timestamp, timestamp, WAITLIST_CONSENT_VERSION)
      .run();
  } catch {
    console.error("Waitlist persistence failed.");
    return jsonResponse(500, { ok: false, code: "server_error" });
  }

  return jsonResponse(200, { ok: true });
}
