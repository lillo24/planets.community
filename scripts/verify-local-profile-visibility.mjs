import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const userAEmail = "profile-visibility-a@planets.invalid";
const userBEmail = "profile-visibility-b@planets.invalid";

await verifyProfileVisibility();

async function verifyProfileVisibility() {
  const userA = await signInWithLocalOtp(userAEmail);
  const userB = await signInWithLocalOtp(userBEmail);

  await ensureProfileAnchor(userA);
  await ensureProfileAnchor(userB);

  const { data: skills, error: skillError } = await userA.client
    .from("skills")
    .select("id, slug")
    .in("slug", ["mural-painting", "musician"])
    .order("slug");
  if (skillError || skills?.length !== 2) {
    throw new Error("Could not load the required controlled profile skills.");
  }

  const skillIds = skills.map((skill) => skill.id);
  const { error: updateError } = await userA.client.rpc("update_own_profile", {
    p_expected_profile_id: userA.id,
    p_display_name: "  Profile Owner A  ",
    p_bio: "Private profile integration note",
    p_skill_ids: skillIds,
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "public",
  });
  if (updateError) {
    throw safeDatabaseFailure(
      "atomically update user A's profile",
      updateError,
    );
  }

  const { data: ownerProfiles, error: ownerProfileError } = await userA.client
    .from("profiles")
    .select("display_name, bio")
    .eq("id", userA.id);
  const { data: ownerSkills, error: ownerSkillError } = await userA.client
    .from("profile_skills")
    .select("skill_id")
    .eq("profile_id", userA.id);
  const { data: ownerVisibility, error: ownerVisibilityError } =
    await userA.client
      .from("profile_field_visibility")
      .select("field_key, audience")
      .eq("profile_id", userA.id);
  if (
    ownerProfileError ||
    ownerSkillError ||
    ownerVisibilityError ||
    ownerProfiles?.length !== 1 ||
    ownerProfiles[0].display_name !== "Profile Owner A" ||
    ownerProfiles[0].bio !== "Private profile integration note" ||
    ownerSkills?.length !== 2 ||
    ownerVisibility?.length !== 3
  ) {
    throw new Error(
      "User A could not read the complete canonical own profile.",
    );
  }

  const { data: crossUserProfiles, error: crossUserReadError } =
    await userB.client
      .from("profiles")
      .select("display_name, bio")
      .eq("id", userA.id);
  if (crossUserReadError || crossUserProfiles?.length !== 0) {
    throw new Error("User B could directly read user A's private profile row.");
  }

  const { data: crossUserUpdates, error: crossUserUpdateError } =
    await userB.client
      .from("profiles")
      .update({ display_name: "Cross-user overwrite" })
      .eq("id", userA.id)
      .select("id");
  if (crossUserUpdateError || crossUserUpdates?.length !== 0) {
    throw new Error("User B could update user A's profile row.");
  }

  const { error: staleFormError } = await userB.client.rpc(
    "update_own_profile",
    {
      p_expected_profile_id: userA.id,
      p_display_name: "Stale User A Value",
      p_bio: "Stale private bio",
      p_skill_ids: skillIds,
      p_display_name_audience: "private",
      p_bio_audience: "private",
      p_skills_audience: "private",
    },
  );
  if (staleFormError?.code !== "42501") {
    throw new Error(
      "A stale user A form was not rejected for the current user B session.",
    );
  }

  const [userBProfileResult, userBSkillsResult, userBVisibilityResult] =
    await Promise.all([
      userB.client
        .from("profiles")
        .select("display_name, bio")
        .eq("id", userB.id)
        .single(),
      userB.client
        .from("profile_skills")
        .select("skill_id")
        .eq("profile_id", userB.id),
      userB.client
        .from("profile_field_visibility")
        .select("field_key, audience")
        .eq("profile_id", userB.id),
    ]);
  if (
    userBProfileResult.error ||
    userBSkillsResult.error ||
    userBVisibilityResult.error ||
    !userBProfileResult.data ||
    userBProfileResult.data.display_name !== null ||
    userBProfileResult.data.bio !== null ||
    userBSkillsResult.data?.length !== 0 ||
    userBVisibilityResult.data?.length !== 3 ||
    userBVisibilityResult.data.some((row) => row.audience !== "public")
  ) {
    throw new Error("The rejected stale form changed user B's profile state.");
  }

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const { data: directProfiles, error: directProfileError } = await anonymous
    .from("profiles")
    .select("id")
    .eq("id", userA.id);
  if (!directProfileError || directProfiles !== null) {
    throw new Error(
      "Anonymous direct profile-table access did not fail closed.",
    );
  }

  const { data: publicProfiles, error: publicProfileError } =
    await anonymous.rpc("get_public_profile", { p_profile_id: userA.id });
  if (
    publicProfileError ||
    publicProfiles?.length !== 1 ||
    publicProfiles[0].profile_id !== userA.id ||
    publicProfiles[0].display_name !== "Profile Owner A" ||
    publicProfiles[0].bio !== null ||
    !Array.isArray(publicProfiles[0].skills) ||
    publicProfiles[0].skills.length !== 2
  ) {
    throw new Error(
      "The anonymous exact-ID profile read was not sanitized correctly.",
    );
  }

  const serializedPublicProfile = JSON.stringify(publicProfiles[0]);
  if (
    serializedPublicProfile.includes(userAEmail) ||
    serializedPublicProfile.includes("Private profile integration note") ||
    Object.keys(publicProfiles[0]).sort().join(",") !==
      "bio,display_name,profile_id,skills"
  ) {
    throw new Error(
      "The public profile payload exposed a private field or metadata.",
    );
  }

  const { data: ownerAfterCrossUserAttempt, error: finalOwnerReadError } =
    await userA.client
      .from("profiles")
      .select("display_name")
      .eq("id", userA.id)
      .single();
  if (
    finalOwnerReadError ||
    ownerAfterCrossUserAttempt.display_name !== "Profile Owner A"
  ) {
    throw new Error("The rejected cross-user update changed user A's profile.");
  }

  console.log(
    "Confirmed owner access, stale-form rejection, cross-user isolation, and exact-ID mixed-visibility sanitization.",
  );
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
    throw safeDatabaseFailure("request a local profile OTP", requestError);
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local profile OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local profile sign-in email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local profile OTP",
      verificationError ?? {},
    );
  }
  return { client, id: verification.user.id };
}

async function ensureProfileAnchor(user) {
  const { error } = await user.client.from("profiles").insert({ id: user.id });
  if (error) {
    const diagnostic = `${error.message ?? ""} ${error.details ?? ""}`;
    const expectedDuplicate =
      error.code === "23505" && diagnostic.includes("profiles_pkey");
    if (!expectedDuplicate) {
      throw safeDatabaseFailure("create a profile anchor", error);
    }
  }
}

async function findMessageIds(email) {
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

async function waitForNewMessage(email, existingIds, requestStartedAt) {
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
    if (message) {
      return message.ID;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(
    "Mailpit did not receive a profile OTP email within 15 seconds.",
  );
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
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
