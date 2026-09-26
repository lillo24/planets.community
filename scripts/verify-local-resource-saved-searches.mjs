import { randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing the direct database URL required for saved-search predicate verification.",
  );
}

const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false },
});
const sql = postgres(databaseUrl, { max: 2, onnotice: () => {} });
const runMarker = randomUUID().slice(0, 8);

try {
  await verifyResourceSavedSearches();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyResourceSavedSearches() {
  const [searchOwner, listingOwner] = await Promise.all([
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-saved-search-owner@planets.invalid",
      verifierName: "Resource saved-search verifier",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-saved-search-listing-owner@planets.invalid",
      verifierName: "Resource saved-search verifier",
    }),
  ]);

  await Promise.all([
    completeProfile(searchOwner, "Saved Search Owner"),
    completeProfile(listingOwner, "Saved Search Listing Owner"),
  ]);
  await Promise.all([
    clearSavedSearches(searchOwner),
    clearSavedSearches(listingOwner),
  ]);

  await expectCode(
    anonymous.rpc("create_resource_saved_search", {
      p_expected_profile_id: searchOwner.id,
      p_query: "trapano",
      p_listing_mode: null,
      p_locality: null,
    }),
    "42501",
    "anonymous saved-search creation",
  );
  await expectCode(
    anonymous.rpc("list_own_resource_saved_searches", {
      p_expected_profile_id: searchOwner.id,
      p_limit: 20,
      p_cursor_updated_at: null,
      p_cursor_id: null,
    }),
    "42501",
    "anonymous saved-search list",
  );
  await expectCode(
    searchOwner.client.rpc("create_resource_saved_search", {
      p_expected_profile_id: searchOwner.id,
      p_query: " ",
      p_listing_mode: null,
      p_locality: " ",
    }),
    "22023",
    "empty saved-search definition",
  );

  const queryId = await createSavedSearch(searchOwner, {
    query: `  Trapano ${runMarker}  `,
  });
  const modeId = await createSavedSearch(searchOwner, {
    listingMode: " DONATE ",
  });
  const localityId = await createSavedSearch(searchOwner, {
    locality: `  Trento ${runMarker}  `,
  });
  const allFiltersId = await createSavedSearch(searchOwner, {
    query: `  Trapano ${runMarker}  `,
    listingMode: " DONATE ",
    locality: "  Trento  ",
  });

  const allFilters = await getSavedSearch(searchOwner, allFiltersId);
  assertExactKeys(allFilters, [
    "saved_search_id",
    "query",
    "listing_mode",
    "locality",
    "created_at",
    "updated_at",
  ]);
  if (
    allFilters.query !== `Trapano ${runMarker}` ||
    allFilters.listing_mode !== "donate" ||
    allFilters.locality !== "Trento"
  ) {
    throw new Error("Saved-search normalization diverged from public browse.");
  }

  await expectCode(
    searchOwner.client.rpc("create_resource_saved_search", {
      p_expected_profile_id: searchOwner.id,
      p_query: ` trapano ${runMarker.toUpperCase()} `,
      p_listing_mode: "donate",
      p_locality: " trento ",
    }),
    "PT409",
    "semantic duplicate creation",
  );

  const otherSameFiltersId = await createSavedSearch(listingOwner, {
    query: `Trapano ${runMarker}`,
    listingMode: "donate",
    locality: "Trento",
  });
  const otherExactRead = await rpcRows(
    listingOwner.client,
    "get_own_resource_saved_search",
    {
      p_expected_profile_id: listingOwner.id,
      p_saved_search_id: allFiltersId,
    },
  );
  if (otherExactRead.length !== 0) {
    throw new Error("Another profile read a guessed private saved-search ID.");
  }
  await expectCode(
    listingOwner.client.rpc("update_resource_saved_search", {
      p_expected_profile_id: listingOwner.id,
      p_saved_search_id: allFiltersId,
      p_query: "Cross-account edit",
      p_listing_mode: null,
      p_locality: null,
    }),
    "42501",
    "cross-profile saved-search update",
  );
  await expectCode(
    listingOwner.client.rpc("delete_resource_saved_search", {
      p_expected_profile_id: listingOwner.id,
      p_saved_search_id: allFiltersId,
    }),
    "42501",
    "cross-profile saved-search delete",
  );

  const { data: directRows, error: directError } = await searchOwner.client
    .from("resource_saved_searches")
    .select("id,query,locality");
  if (!directError || directRows !== null) {
    throw new Error("Direct saved-search table reads did not fail closed.");
  }

  const listingId = await createListing(listingOwner, {
    title: `Trapano ${runMarker} Bosch`,
    description: `Kit Bosch 18V ${runMarker}`,
    locality: "Trento",
  });
  await rpcId(listingOwner.client, "publish_resource_listing", {
    p_expected_owner_profile_id: listingOwner.id,
    p_listing_id: listingId,
  });

  const browseRows = await rpcRows(anonymous, "list_public_resource_listings", {
    p_limit: 50,
    p_cursor_published_at: null,
    p_cursor_id: null,
    p_listing_mode: allFilters.listing_mode,
    p_locality: allFilters.locality,
    p_query: allFilters.query,
  });
  if (!browseRows.some((row) => row.listing_id === listingId)) {
    throw new Error(
      "A saved current-filter definition did not reproduce browse.",
    );
  }

  const [predicateMatch] = await sql`
    select private.resource_listing_matches_saved_search_filters(
      listing.listing_mode,
      listing.title,
      listing.description,
      listing.locality,
      ${allFilters.listing_mode},
      ${allFilters.query},
      ${allFilters.locality}
    ) as matches
    from public.resource_listings as listing
    where listing.id = ${listingId}::uuid
  `;
  if (predicateMatch?.matches !== true) {
    throw new Error("The private predicate diverged from public browse.");
  }

  const [literalChecks] = await sql`
    select
      private.resource_listing_matches_saved_search_filters(
        listing.listing_mode, listing.title, listing.description,
        listing.locality, null, 'drill', null
      ) as synonym_match,
      private.resource_listing_matches_saved_search_filters(
        listing.listing_mode, listing.title, listing.description,
        listing.locality, null, 'Bosch 18', null
      ) as description_match
    from public.resource_listings as listing
    where listing.id = ${listingId}::uuid
  `;
  if (
    literalChecks?.synonym_match !== false ||
    literalChecks?.description_match !== true
  ) {
    throw new Error("Saved-search matching was not literal field matching.");
  }

  const beforeUpdate = await getSavedSearch(searchOwner, allFiltersId);
  await rpcId(searchOwner.client, "update_resource_saved_search", {
    p_expected_profile_id: searchOwner.id,
    p_saved_search_id: allFiltersId,
    p_query: "  Bosch 18  ",
    p_listing_mode: " donate ",
    p_locality: " trento ",
  });
  const afterUpdate = await getSavedSearch(searchOwner, allFiltersId);
  if (
    afterUpdate.created_at !== beforeUpdate.created_at ||
    afterUpdate.query !== "Bosch 18" ||
    afterUpdate.listing_mode !== "donate" ||
    afterUpdate.locality !== "trento" ||
    Date.parse(afterUpdate.updated_at) < Date.parse(beforeUpdate.updated_at)
  ) {
    throw new Error(
      "Saved-search update timestamps or filters were incorrect.",
    );
  }

  const pageOne = await listSavedSearches(searchOwner, {
    limit: 1,
  });
  if (pageOne.length !== 1) {
    throw new Error("Saved-search first cursor page was not bounded.");
  }
  const pageTwo = await listSavedSearches(searchOwner, {
    limit: 1,
    cursorUpdatedAt: pageOne[0].updated_at,
    cursorId: pageOne[0].saved_search_id,
  });
  if (
    pageTwo.length !== 1 ||
    pageTwo[0].saved_search_id === pageOne[0].saved_search_id
  ) {
    throw new Error(
      "Saved-search descending keyset repeated or skipped its boundary.",
    );
  }
  await expectCode(
    searchOwner.client.rpc("list_own_resource_saved_searches", {
      p_expected_profile_id: searchOwner.id,
      p_limit: 20,
      p_cursor_updated_at: pageOne[0].updated_at,
      p_cursor_id: null,
    }),
    "22023",
    "partial saved-search cursor",
  );

  const concurrentDefinition = {
    p_expected_profile_id: searchOwner.id,
    p_query: `Concurrent ${runMarker}`,
    p_listing_mode: "exchange",
    p_locality: null,
  };
  const concurrentCreates = await Promise.all([
    searchOwner.client.rpc(
      "create_resource_saved_search",
      concurrentDefinition,
    ),
    searchOwner.client.rpc(
      "create_resource_saved_search",
      concurrentDefinition,
    ),
  ]);
  const createSuccesses = concurrentCreates.filter(
    (result) => typeof result.data === "string" && !result.error,
  );
  const createConflicts = concurrentCreates.filter(
    (result) => result.data === null && result.error?.code === "PT409",
  );
  if (createSuccesses.length !== 1 || createConflicts.length !== 1) {
    throw new Error(
      "Concurrent semantic duplicate creation was not one success plus PT409.",
    );
  }
  const concurrentId = createSuccesses[0].data;

  const updateRaceA = await createSavedSearch(searchOwner, {
    query: `Race A ${runMarker}`,
  });
  const updateRaceB = await createSavedSearch(searchOwner, {
    query: `Race B ${runMarker}`,
  });
  const concurrentUpdates = await Promise.all([
    searchOwner.client.rpc("update_resource_saved_search", {
      p_expected_profile_id: searchOwner.id,
      p_saved_search_id: updateRaceA,
      p_query: `Race target ${runMarker}`,
      p_listing_mode: null,
      p_locality: null,
    }),
    searchOwner.client.rpc("update_resource_saved_search", {
      p_expected_profile_id: searchOwner.id,
      p_saved_search_id: updateRaceB,
      p_query: `Race target ${runMarker}`,
      p_listing_mode: null,
      p_locality: null,
    }),
  ]);
  const updateSuccesses = concurrentUpdates.filter(
    (result) => typeof result.data === "string" && !result.error,
  );
  const updateConflicts = concurrentUpdates.filter(
    (result) => result.data === null && result.error?.code === "PT409",
  );
  if (updateSuccesses.length !== 1 || updateConflicts.length !== 1) {
    throw new Error(
      "Concurrent updates toward one semantic tuple did not preserve uniqueness.",
    );
  }

  const ownedIds = [
    queryId,
    modeId,
    localityId,
    allFiltersId,
    concurrentId,
    updateRaceA,
    updateRaceB,
  ];
  for (const savedSearchId of ownedIds) {
    await deleteIfOwned(searchOwner, savedSearchId);
  }
  await deleteIfOwned(listingOwner, otherSameFiltersId);

  const afterDelete = await getSavedSearchRows(searchOwner, allFiltersId);
  if (afterDelete.length !== 0) {
    throw new Error("Hard delete retained a private saved-search row.");
  }

  await rpcId(listingOwner.client, "close_resource_listing", {
    p_expected_owner_profile_id: listingOwner.id,
    p_listing_id: listingId,
  });

  console.log(
    "Confirmed real-OTP saved-search CRUD, canonical filters, ownership isolation, browse/predicate parity, stable keyset pagination, literal matching, hard delete, and deterministic concurrent duplicate conflicts.",
  );
}

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

async function createListing(user, { title, description, locality }) {
  return rpcId(user.client, "create_resource_listing_draft", {
    p_expected_owner_profile_id: user.id,
    p_listing_mode: "donate",
    p_title: title,
    p_description: description,
    p_country_code: "IT",
    p_locality: locality,
    p_administrative_area: null,
    p_public_location_label: locality,
  });
}

async function createSavedSearch(user, input) {
  return rpcId(user.client, "create_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_query: input.query ?? null,
    p_listing_mode: input.listingMode ?? null,
    p_locality: input.locality ?? null,
  });
}

async function getSavedSearch(user, savedSearchId) {
  const rows = await getSavedSearchRows(user, savedSearchId);
  if (rows.length !== 1) {
    throw new Error("An owned saved search was not returned exactly once.");
  }
  return rows[0];
}

async function getSavedSearchRows(user, savedSearchId) {
  return rpcRows(user.client, "get_own_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_saved_search_id: savedSearchId,
  });
}

async function listSavedSearches(user, options) {
  return rpcRows(user.client, "list_own_resource_saved_searches", {
    p_expected_profile_id: user.id,
    p_limit: options.limit ?? 20,
    p_cursor_updated_at: options.cursorUpdatedAt ?? null,
    p_cursor_id: options.cursorId ?? null,
  });
}

async function deleteIfOwned(user, savedSearchId) {
  const rows = await getSavedSearchRows(user, savedSearchId);
  if (rows.length === 0) return;
  await rpcId(user.client, "delete_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_saved_search_id: savedSearchId,
  });
}

async function clearSavedSearches(user) {
  for (;;) {
    const rows = await listSavedSearches(user, { limit: 50 });
    if (rows.length === 0) return;
    for (const row of rows) {
      await rpcId(user.client, "delete_resource_saved_search", {
        p_expected_profile_id: user.id,
        p_saved_search_id: row.saved_search_id,
      });
    }
  }
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

function assertExactKeys(value, expectedKeys) {
  if (
    value === null ||
    Array.isArray(value) ||
    typeof value !== "object" ||
    JSON.stringify(Object.keys(value).sort()) !==
      JSON.stringify([...expectedKeys].sort())
  ) {
    throw new Error("A saved-search RPC returned an unexpected shape.");
  }
}

function failure(action, error) {
  const code = /^[a-z0-9_]+$/iu.test(error?.code ?? "")
    ? error.code
    : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
