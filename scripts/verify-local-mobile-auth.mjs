import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const testEmail = "mobile-auth-ci@planets.invalid";
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);

await verifyMobileEmailOtpFlow();

async function verifyMobileEmailOtpFlow() {
  const existingMessageIds = await findMessageIds();
  const requestStartedAt = Date.now();

  await fetchExpected(
    `${apiUrl}/auth/v1/otp`,
    {
      method: "POST",
      headers: publicHeaders(),
      body: JSON.stringify({ email: testEmail, create_user: true }),
    },
    "request email OTP",
  );
  console.log("Requested a local email OTP.");

  const messageId = await waitForNewMessage(
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read the local OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "The local sign-in email did not contain the configured 6-digit token.",
    );
  }
  if (
    messageBody.includes("/auth/v1/verify?") ||
    messageBody.includes("token_hash=")
  ) {
    throw new Error(
      "The local sign-in email unexpectedly contained a magic-link verification URL.",
    );
  }
  console.log("Read a numeric code from Mailpit without exposing it.");

  const verification = await fetchJson(
    `${apiUrl}/auth/v1/verify`,
    {
      method: "POST",
      headers: publicHeaders(),
      body: JSON.stringify({ email: testEmail, token, type: "email" }),
    },
    "verify email OTP",
  );
  const accessToken = verification.access_token;
  const userId = verification.user?.id;
  if (typeof accessToken !== "string" || typeof userId !== "string") {
    throw new Error("OTP verification did not return a user session.");
  }
  console.log("Verified the code and received a user session.");

  const profileResponse = await fetch(`${apiUrl}/rest/v1/profiles`, {
    method: "POST",
    headers: {
      ...publicHeaders(),
      Authorization: `Bearer ${accessToken}`,
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ id: userId }),
  });
  if (!profileResponse.ok) {
    const failure = await readOptionalJson(profileResponse);
    const diagnostic = `${failure?.message ?? ""} ${failure?.details ?? ""}`;
    const expectedDuplicate =
      profileResponse.status === 409 &&
      failure?.code === "23505" &&
      diagnostic.includes("profiles_pkey");
    if (!expectedDuplicate) {
      throw new Error(
        `Could not ensure the authenticated profile anchor (HTTP ${profileResponse.status}).`,
      );
    }
  }

  const profiles = await fetchJson(
    `${apiUrl}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id`,
    {
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${accessToken}`,
      },
    },
    "read the authenticated profile anchor",
  );
  if (
    !Array.isArray(profiles) ||
    profiles.length !== 1 ||
    profiles[0]?.id !== userId
  ) {
    throw new Error(
      "The authenticated user does not have exactly one profile anchor.",
    );
  }
  console.log("Confirmed the signed-in user owns exactly one profile anchor.");
}

function publicHeaders() {
  return {
    apikey: publishableKey,
    "Content-Type": "application/json",
  };
}

async function findMessageIds() {
  const result = await fetchJson(
    `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${testEmail}`)}&limit=50`,
    {},
    "search the local mailbox",
  );
  return new Set(
    Array.isArray(result.messages)
      ? result.messages
          .map((message) => message.ID)
          .filter((id) => typeof id === "string")
      : [],
  );
}

async function waitForNewMessage(existingIds, requestStartedAt) {
  const deadline = requestStartedAt + 15_000;
  while (Date.now() < deadline) {
    const result = await fetchJson(
      `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${testEmail}`)}&limit=10`,
      {},
      "search the local mailbox",
    );
    const messages = Array.isArray(result.messages) ? result.messages : [];
    const message = messages.find(
      (candidate) =>
        typeof candidate.ID === "string" && !existingIds.has(candidate.ID),
    );
    if (message) {
      return message.ID;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(
    "Mailpit did not receive the requested OTP email within 15 seconds.",
  );
}

async function fetchExpected(url, options, action) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  return response;
}

async function fetchJson(url, options, action) {
  const response = await fetchExpected(url, options, action);
  try {
    return await response.json();
  } catch {
    throw new Error(`Failed to ${action}: the response was not valid JSON.`);
  }
}

async function readOptionalJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}
