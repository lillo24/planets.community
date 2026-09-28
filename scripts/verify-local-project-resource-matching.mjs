import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, publishableKey } = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false },
});

const [creator, listingOwner] = await Promise.all([
  signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email: "project-matching-creator@planets.invalid",
    verifierName: "Project resource matching verifier",
  }),
  signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email: "project-matching-listing-owner@planets.invalid",
    verifierName: "Project resource matching verifier",
  }),
]);

await Promise.all([
  completeProfile(creator, "Matching Creator"),
  completeProfile(listingOwner, "Matching Listing Owner"),
]);
await Promise.all([
  ensureLocalProfilePhoto(creator),
  ensureLocalProfilePhoto(listingOwner),
]);

const proposalId = await rpcId(creator.client, "create_proposal_draft", {
  p_expected_creator_profile_id: creator.id,
  p_title: "Matching verifier draft",
  p_summary: "A local matching verification Project.",
  p_description: "Exercises creator-only Resource matching.",
  p_starts_at: "2098-01-02T10:00:00.000Z",
  p_ends_at: "2098-01-02T14:00:00.000Z",
  p_event_timezone: "Europe/Rome",
  p_country_code: "IT",
  p_locality: "Trento",
  p_administrative_area: "Trentino",
  p_public_location_label: "Trento",
  p_exact_meeting_text: null,
  p_exact_location_visibility: "participants",
  p_skill_ids: [],
  p_skill_importances: [],
});
const needId = await rpcId(creator.client, "create_project_resource_need", {
  p_expected_creator_profile_id: creator.id,
  p_project_id: proposalId,
  p_title: "Trapano a percussione",
  p_details: "Bosch",
});

const listingId = await rpcId(
  listingOwner.client,
  "create_resource_listing_draft",
  {
    p_expected_owner_profile_id: listingOwner.id,
    p_listing_mode: "donate",
    p_title: "Trapano a percussione 18V",
    p_description: "Disponibile per il progetto.",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Trentino",
    p_public_location_label: "Trento",
  },
);
await rpcId(listingOwner.client, "publish_resource_listing", {
  p_expected_owner_profile_id: listingOwner.id,
  p_listing_id: listingId,
});

const query = (profileId, scope = "same_locality", extras = {}) => ({
  p_expected_creator_profile_id: profileId,
  p_resource_need_id: needId,
  p_location_scope: scope,
  p_limit: 20,
  p_listing_mode: null,
  ...extras,
});
await expectCode(
  anonymous.rpc(
    "list_project_resource_need_listing_matches",
    query(creator.id),
  ),
  "42501",
  "anonymous matching",
);
await expectCode(
  listingOwner.client.rpc(
    "list_project_resource_need_listing_matches",
    query(listingOwner.id),
  ),
  "42501",
  "unrelated matching",
);
await expectCode(
  creator.client.rpc(
    "list_project_resource_need_listing_matches",
    query(listingOwner.id),
  ),
  "42501",
  "stale expected creator",
);

const matches = await rpcRows(
  creator.client,
  "list_project_resource_need_listing_matches",
  query(creator.id),
);
const matched = matches.find((row) => row.listing_id === listingId);
if (
  !matched ||
  matched.resource_need_id !== needId ||
  matched.text_match_kind !== "title_phrase" ||
  matched.location_match_kind !== "same_locality" ||
  matched.listing_mode !== "donate"
) {
  throw new Error(
    "Creator matching omitted or misclassified the published listing.",
  );
}
const expectedKeys = [
  "resource_need_id",
  "listing_id",
  "cover_object_path",
  "listing_mode",
  "title",
  "description",
  "country_code",
  "locality",
  "administrative_area",
  "public_location_label",
  "published_at",
  "active_request_count",
  "text_match_kind",
  "location_match_kind",
].sort();
if (
  JSON.stringify(Object.keys(matched).sort()) !== JSON.stringify(expectedKeys)
) {
  throw new Error("Matching returned a private or unexpected field.");
}
const publicDetail = await rpcRows(anonymous, "get_public_resource_listing", {
  p_listing_id: listingId,
});
if (matched.active_request_count !== publicDetail[0]?.active_request_count) {
  throw new Error(
    "Matching request count diverged from public listing detail.",
  );
}

const outsideMode = await rpcRows(
  creator.client,
  "list_project_resource_need_listing_matches",
  query(creator.id, "anywhere", { p_listing_mode: "exchange" }),
);
if (outsideMode.some((row) => row.listing_id === listingId)) {
  throw new Error("Exchange filter returned a Dona listing.");
}
await expectCode(
  creator.client.rpc(
    "list_project_resource_need_listing_matches",
    query(creator.id, "anywhere", { p_listing_mode: "lend" }),
  ),
  "22023",
  "invalid listing mode",
);

await rpcId(listingOwner.client, "close_resource_listing", {
  p_expected_owner_profile_id: listingOwner.id,
  p_listing_id: listingId,
});
const afterClosure = await rpcRows(
  creator.client,
  "list_project_resource_need_listing_matches",
  query(creator.id),
);
if (afterClosure.some((row) => row.listing_id === listingId)) {
  throw new Error("A closed listing persisted in read-time matching.");
}

console.log(
  "Confirmed real-OTP creator authorization, public-safe reasons/count parity, explicit mode, and read-time listing closure.",
);

async function completeProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (
    anchorError &&
    (anchorError.code !== "23505" ||
      !`${anchorError.message ?? ""} ${anchorError.details ?? ""}`.includes(
        "profiles_pkey",
      ))
  ) {
    throw failure("create verifier profile", anchorError);
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error) throw failure("complete verifier profile", error);
}

async function rpcId(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error || typeof data !== "string") throw failure(name, error);
  return data;
}

async function rpcRows(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error || !Array.isArray(data)) throw failure(name, error);
  return data;
}

async function expectCode(promise, code, action) {
  const result = await promise;
  if (result.data !== null || result.error?.code !== code) {
    throw new Error(`Expected ${code} when checking ${action}.`);
  }
}

function failure(action, error) {
  const code = /^[a-z0-9_]+$/iu.test(error?.code ?? "")
    ? error.code
    : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
