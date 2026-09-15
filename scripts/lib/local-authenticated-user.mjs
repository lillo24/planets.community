import { createClient } from "@supabase/supabase-js";

export async function signInLocalOtpUser({
  apiUrl,
  publishableKey,
  mailpitUrl,
  email,
  verifierName,
}) {
  const authClient = createClient(apiUrl, publishableKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const existingMessageIds = await findMessageIds(mailpitUrl, email);
  const requestStartedAt = Date.now();
  const { error: requestError } = await authClient.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (requestError) {
    throw safeSupabaseFailure(
      `request a local ${verifierName} OTP`,
      requestError,
    );
  }

  const messageId = await waitForNewMessage(
    mailpitUrl,
    email,
    existingMessageIds,
    requestStartedAt,
    verifierName,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    `read a local ${verifierName} OTP email`,
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const otp = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!otp) {
    throw new Error(
      `A local ${verifierName} email did not contain a 6-digit token.`,
    );
  }

  const { data: verification, error: verificationError } =
    await authClient.auth.verifyOtp({ email, token: otp, type: "email" });
  const userId = verification?.user?.id;
  const accessToken = verification?.session?.access_token;
  if (verificationError || !userId || !accessToken) {
    throw safeSupabaseFailure(
      `verify a local ${verifierName} OTP`,
      verificationError ?? {},
    );
  }

  return {
    id: userId,
    client: createTokenBoundDataClient({
      apiUrl,
      publishableKey,
      accessToken,
    }),
  };
}

export function createTokenBoundDataClient({
  apiUrl,
  publishableKey,
  accessToken,
  fetch,
}) {
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new Error(
      "A verified local Supabase session access token is required.",
    );
  }

  return createClient(apiUrl, publishableKey, {
    accessToken: async () => accessToken,
    ...(fetch ? { global: { fetch } } : {}),
  });
}

async function findMessageIds(mailpitUrl, email) {
  const result = await fetchJson(
    `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=50`,
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

async function waitForNewMessage(
  mailpitUrl,
  email,
  existingIds,
  requestStartedAt,
  verifierName,
) {
  const deadline = requestStartedAt + 15_000;
  while (Date.now() < deadline) {
    const result = await fetchJson(
      `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=10`,
      {},
      "search the local mailbox",
    );
    const messages = Array.isArray(result.messages) ? result.messages : [];
    const message = messages.find(
      (candidate) =>
        typeof candidate.ID === "string" && !existingIds.has(candidate.ID),
    );
    if (message) return message.ID;
    await delay(250);
  }
  throw new Error(
    `Mailpit did not receive a ${verifierName} OTP within 15 seconds.`,
  );
}

function safeSupabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

async function fetchJson(url, options, action) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  try {
    return await response.json();
  } catch {
    throw new Error(`Failed to ${action}: the response was not valid JSON.`);
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
