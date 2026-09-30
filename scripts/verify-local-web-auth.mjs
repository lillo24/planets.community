import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

import { createServerClient, serializeCookieHeader } from "@supabase/ssr";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const webRoot = fileURLToPath(new URL("../apps/web/", import.meta.url));
const nextBin = fileURLToPath(
  new URL("../node_modules/next/dist/bin/next", import.meta.url),
);
const testEmail = "web-auth-ci@planets.invalid";
const appUrl = "http://127.0.0.1:3100";
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);

await verifyWebEmailOtpSession();

async function verifyWebEmailOtpSession() {
  const server = startNextServer();

  try {
    await waitForNextServer(server);
    await assertPublicAndAdminBoundaries();

    const existingMessageIds = await findMessageIds();
    const requestStartedAt = Date.now();
    const cookieJar = new Map();
    const supabase = createServerClient(apiUrl, publishableKey, {
      cookies: {
        getAll() {
          return [...cookieJar].map(([name, value]) => ({ name, value }));
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            if (value.length === 0) {
              cookieJar.delete(name);
            } else {
              cookieJar.set(name, value);
            }
          }
        },
      },
    });

    const { error: requestError } = await supabase.auth.signInWithOtp({
      email: testEmail,
      options: { shouldCreateUser: true },
    });
    if (requestError) {
      throw authFailure("request the local web email OTP", requestError);
    }
    console.log("Requested a local web email OTP.");

    const messageId = await waitForNewMessage(
      existingMessageIds,
      requestStartedAt,
    );
    const message = await fetchJson(
      `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
      {},
      "read the local web OTP email",
    );
    const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
    const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
    if (!token) {
      throw new Error(
        "The local web sign-in email did not contain the configured 6-digit token.",
      );
    }
    if (
      messageBody.includes("/auth/v1/verify?") ||
      messageBody.includes("token_hash=")
    ) {
      throw new Error(
        "The local web sign-in email unexpectedly contained a magic-link verification URL.",
      );
    }
    console.log("Read the web numeric code without exposing it.");

    const { data: verification, error: verificationError } =
      await supabase.auth.verifyOtp({
        email: testEmail,
        token,
        type: "email",
      });
    if (verificationError) {
      throw authFailure("verify the local web email OTP", verificationError);
    }

    const accessToken = verification.session?.access_token;
    const userId = verification.user?.id;
    if (!accessToken || !userId || cookieJar.size === 0) {
      throw new Error(
        "Web OTP verification did not establish a cookie-backed user session.",
      );
    }
    console.log("Verified the code and established an SSR cookie session.");

    const { error: profileError } = await supabase
      .from("profiles")
      .insert({ id: userId });
    if (profileError && !isExpectedProfileDuplicate(profileError)) {
      throw new Error(
        `Could not ensure the web profile anchor (code ${safeCode(profileError.code)}).`,
      );
    }

    const { error: completionError } = await supabase.rpc(
      "update_own_profile",
      {
        p_expected_profile_id: userId,
        p_display_name: "Web Auth CI",
        p_bio: "",
        p_skill_ids: [],
        p_display_name_audience: "public",
        p_bio_audience: "public",
        p_skills_audience: "public",
      },
    );
    if (completionError) {
      throw new Error(
        `Could not complete the web profile anchor (code ${safeCode(completionError.code)}).`,
      );
    }

    const cookieHeader = [...cookieJar]
      .map(([name, value]) => serializeCookieHeader(name, value))
      .join("; ");
    const authenticatedHome = await fetchExpected(
      `${appUrl}/`,
      { headers: { Cookie: cookieHeader } },
      "request the authenticated web home page",
    );
    const homeBody = await authenticatedHome.text();
    if (!homeBody.includes("Signed in")) {
      throw new Error(
        "The built web application did not recognize the SSR cookie session.",
      );
    }
    if (homeBody.includes(testEmail) || homeBody.includes(accessToken)) {
      throw new Error(
        "The authenticated web response exposed private authentication material.",
      );
    }

    const authenticatedAdmin = await fetch(`${appUrl}/admin`, {
      headers: { Cookie: cookieHeader },
    });
    if (authenticatedAdmin.status !== 404) {
      throw new Error(
        `Authenticated /admin did not fail closed (HTTP ${authenticatedAdmin.status}).`,
      );
    }
    console.log(
      "Confirmed authenticated SSR state and the ordinary signed-in /admin 404 boundary.",
    );
  } finally {
    await stopNextServer(server);
  }
}

function startNextServer() {
  return spawn(
    process.execPath,
    [nextBin, "start", "--hostname", "127.0.0.1", "--port", "3100"],
    {
      cwd: webRoot,
      env: { ...process.env, NODE_ENV: "production" },
      stdio: "inherit",
    },
  );
}

async function waitForNextServer(server) {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error(
        `The built Next.js server exited before it became ready (code ${server.exitCode}).`,
      );
    }
    try {
      const response = await fetch(`${appUrl}/`);
      if (response.ok) {
        return;
      }
    } catch {
      // The server socket is not ready yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("The built Next.js server was not ready within 15 seconds.");
}

async function stopNextServer(server) {
  if (server.exitCode !== null) {
    return;
  }

  server.kill("SIGTERM");
  await Promise.race([
    new Promise((resolve) => server.once("exit", resolve)),
    new Promise((resolve) => setTimeout(resolve, 5_000)),
  ]);

  if (server.exitCode === null) {
    server.kill("SIGKILL");
  }
}

async function assertPublicAndAdminBoundaries() {
  const publicHome = await fetchExpected(
    `${appUrl}/`,
    {},
    "request the signed-out web home page",
  );
  const homeBody = await publicHome.text();
  if (!homeBody.includes("Sign in")) {
    throw new Error("The signed-out public home page did not offer sign-in.");
  }

  const signedOutAdmin = await fetch(`${appUrl}/admin`);
  if (signedOutAdmin.status !== 404) {
    throw new Error(
      `Signed-out /admin did not fail closed (HTTP ${signedOutAdmin.status}).`,
    );
  }
  console.log("Confirmed the signed-out public home and /admin 404 boundary.");
}

function authFailure(action, error) {
  return new Error(`Failed to ${action} (code ${safeCode(error.code)}).`);
}

function safeCode(value) {
  return typeof value === "string" && /^[a-z0-9_]+$/i.test(value)
    ? value
    : "unknown";
}

function isExpectedProfileDuplicate(error) {
  const diagnostic = `${error.message ?? ""} ${error.details ?? ""}`;
  return error.code === "23505" && diagnostic.includes("profiles_pkey");
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
    "Mailpit did not receive the requested web OTP email within 15 seconds.",
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
