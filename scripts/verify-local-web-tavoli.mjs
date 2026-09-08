import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const webRoot = fileURLToPath(new URL("../apps/web/", import.meta.url));
const nextBin = fileURLToPath(
  new URL("../node_modules/next/dist/bin/next", import.meta.url),
);
const appUrl = "http://127.0.0.1:3100";
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const testEmail = "web-tavoli-ci@planets.invalid";

await verifyPublicWebTavoli();

async function verifyPublicWebTavoli() {
  const runId = randomUUID().slice(0, 8);
  const locality = `Web Tavoli ${runId}`;
  const user = await signInWithLocalOtp(testEmail);
  await ensureCompleteProfile(user);

  const restrictedExactText = `Protected room ${runId}`;
  const publicExactText = `Public fountain ${runId}`;
  const restrictedTitle = `Restricted weekly Tavolo ${runId}`;
  const publicTitle = `Public monthly Tavolo ${runId}`;
  const pausedTitle = `Paused Tavolo ${runId}`;
  const endedTitle = `Ended Tavolo ${runId}`;

  const restrictedId = await createAndPublish(user, {
    title: restrictedTitle,
    topic: "Philosophy",
    locality,
    roughLocation: `${locality} rough area`,
    exactMeetingText: restrictedExactText,
    exactLocationVisibility: "participants",
    recurrenceType: "weekly",
    weekday: 3,
    dayOfMonth: null,
    localStartTime: "19:00:00",
  });
  const publicId = await createAndPublish(user, {
    title: publicTitle,
    topic: "Culture",
    locality,
    roughLocation: `${locality} central area`,
    exactMeetingText: publicExactText,
    exactLocationVisibility: "public",
    recurrenceType: "monthly",
    weekday: null,
    dayOfMonth: 12,
    localStartTime: "18:30:00",
  });
  const pausedId = await createAndPublish(user, {
    title: pausedTitle,
    topic: "Reading",
    locality,
    roughLocation: `${locality} north area`,
    exactMeetingText: `Paused protected room ${runId}`,
    exactLocationVisibility: "participants",
    recurrenceType: "weekly",
    weekday: 4,
    dayOfMonth: null,
    localStartTime: "17:30:00",
  });
  const endedId = await createAndPublish(user, {
    title: endedTitle,
    topic: "Making",
    locality,
    roughLocation: `${locality} south area`,
    exactMeetingText: `Ended protected room ${runId}`,
    exactLocationVisibility: "participants",
    recurrenceType: "monthly",
    weekday: null,
    dayOfMonth: 20,
    localStartTime: "20:00:00",
  });

  await transition(user, "pause_recurring_activity", pausedId);
  await transition(user, "end_recurring_activity", endedId);

  const server = startNextServer();
  try {
    await waitForNextServer(server);

    const listBody = await responseText(
      `${appUrl}/tavoli?locality=${encodeURIComponent(locality)}`,
      200,
      "request signed-out Tavoli discovery",
    );
    requireText(listBody, restrictedTitle, "active restricted Tavolo title");
    requireText(listBody, publicTitle, "active public Tavolo title");
    requireText(listBody, `${locality} rough area`, "rough Tavolo location");
    requireText(listBody, "Next meeting", "next Tavolo meeting");
    rejectText(listBody, restrictedExactText, "restricted exact location");
    rejectText(listBody, publicExactText, "public detail-only exact location");
    rejectText(listBody, pausedTitle, "paused Tavolo list entry");
    rejectText(listBody, endedTitle, "ended Tavolo list entry");

    const restrictedBody = await responseText(
      `${appUrl}/tavoli/${restrictedId}`,
      200,
      "request restricted Tavolo detail",
    );
    requireText(
      restrictedBody,
      "Exact location available after joining.",
      "restricted-location explanation",
    );
    rejectText(
      restrictedBody,
      restrictedExactText,
      "restricted Tavolo exact location",
    );

    const publicBody = await responseText(
      `${appUrl}/tavoli/${publicId}`,
      200,
      "request public-location Tavolo detail",
    );
    requireText(publicBody, publicExactText, "public Tavolo exact location");

    const pausedBody = await responseText(
      `${appUrl}/tavoli/${pausedId}`,
      200,
      "request paused Tavolo detail",
    );
    requireText(pausedBody, "Paused", "paused lifecycle");
    rejectText(pausedBody, "Upcoming meetings", "paused upcoming list");

    const endedBody = await responseText(
      `${appUrl}/tavoli/${endedId}`,
      200,
      "request ended Tavolo detail",
    );
    requireText(endedBody, "Ended", "ended lifecycle");
    rejectText(endedBody, "Upcoming meetings", "ended upcoming list");

    await responseText(
      `${appUrl}/tavoli/not-a-uuid`,
      404,
      "request an invalid Tavolo ID",
    );
    await responseText(
      `${appUrl}/tavoli/00000000-0000-4000-8000-000000000fff`,
      404,
      "request an unknown Tavolo ID",
    );

    const renderedBodies = [
      listBody,
      restrictedBody,
      publicBody,
      pausedBody,
      endedBody,
    ];
    if (
      renderedBodies.some(
        (body) => body.includes(testEmail) || body.includes(user.accessToken),
      )
    ) {
      throw new Error(
        "A public Tavoli response exposed authentication material.",
      );
    }

    console.log(
      "Confirmed signed-out Tavoli list/detail, active and historical lifecycle visibility, next-meeting rendering, and detail-only exact-location privacy.",
    );
  } finally {
    await stopNextServer(server);
  }
}

async function createAndPublish(user, input) {
  const { data, error } = await user.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: user.id,
      p_title: input.title,
      p_summary: `Synthetic summary for ${input.title}`,
      p_description: `Synthetic public description for ${input.title}`,
      p_topic: input.topic,
      p_country_code: "IT",
      p_locality: input.locality,
      p_administrative_area: "Synthetic area",
      p_public_location_label: input.roughLocation,
      p_exact_meeting_text: input.exactMeetingText,
      p_exact_location_visibility: input.exactLocationVisibility,
      p_recurrence_type: input.recurrenceType,
      p_weekday: input.weekday,
      p_day_of_month: input.dayOfMonth,
      p_local_start_time: input.localStartTime,
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2020-01-01",
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a web Tavoli fixture", error ?? {});
  }
  await transition(user, "publish_recurring_activity", data);
  return data;
}

async function transition(user, operation, recurringActivityId) {
  const { error } = await user.client.rpc(operation, {
    p_expected_creator_profile_id: user.id,
    p_recurring_activity_id: recurringActivityId,
  });
  if (error) {
    throw safeDatabaseFailure("transition a web Tavoli fixture", error);
  }
}

async function ensureCompleteProfile(user) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError && !isExpectedProfileDuplicate(anchorError)) {
    throw safeDatabaseFailure("create the web Tavoli profile", anchorError);
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: "Web Tavoli CI",
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "public",
  });
  if (updateError) {
    throw safeDatabaseFailure("complete the web Tavoli profile", updateError);
  }
}

async function signInWithLocalOtp(email) {
  const client = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const existingMessageIds = await findMessageIds(email);
  const requestStartedAt = Date.now();
  const { error: requestError } = await client.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (requestError) {
    throw safeDatabaseFailure("request a local web Tavoli OTP", requestError);
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    "read a local web Tavoli OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "The local web Tavoli sign-in email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  const userId = verification.user?.id;
  const accessToken = verification.session?.access_token;
  if (verificationError || !userId || !accessToken) {
    throw safeDatabaseFailure(
      "verify a local web Tavoli OTP",
      verificationError ?? {},
    );
  }
  return { client, id: userId, accessToken };
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
      if (response.ok) return;
    } catch {
      // The server socket is not ready yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("The built Next.js server was not ready within 15 seconds.");
}

async function stopNextServer(server) {
  if (server.exitCode !== null) return;
  server.kill("SIGTERM");
  await Promise.race([
    new Promise((resolve) => server.once("exit", resolve)),
    new Promise((resolve) => setTimeout(resolve, 5_000)),
  ]);
  if (server.exitCode === null) server.kill("SIGKILL");
}

async function responseText(url, expectedStatus, action) {
  const response = await fetch(url);
  if (response.status !== expectedStatus) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  return response.text();
}

function requireText(body, expected, label) {
  if (!body.includes(expected)) {
    throw new Error(`The rendered page omitted the expected ${label}.`);
  }
}

function rejectText(body, forbidden, label) {
  if (body.includes(forbidden)) {
    throw new Error(`The rendered page exposed the forbidden ${label}.`);
  }
}

function isExpectedProfileDuplicate(error) {
  const diagnostic = `${error.message ?? ""} ${error.details ?? ""}`;
  return error.code === "23505" && diagnostic.includes("profiles_pkey");
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

async function findMessageIds(email) {
  const result = await fetchJson(
    `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=50`,
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

async function waitForNewMessage(email, existingIds, requestStartedAt) {
  const deadline = requestStartedAt + 15_000;
  while (Date.now() < deadline) {
    const result = await fetchJson(
      `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=10`,
      "search the local mailbox",
    );
    const messages = Array.isArray(result.messages) ? result.messages : [];
    const message = messages.find(
      (candidate) =>
        typeof candidate.ID === "string" && !existingIds.has(candidate.ID),
    );
    if (message) return message.ID;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(
    "Mailpit did not receive the web Tavoli OTP email within 15 seconds.",
  );
}

async function fetchJson(url, action) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  try {
    return await response.json();
  } catch {
    throw new Error(`Failed to ${action}: the response was not valid JSON.`);
  }
}
