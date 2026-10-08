import assert from "node:assert/strict";
import { verifyLocationPreviews } from "./lib/verify-location-previews.mjs";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { normalizeResults } from "../supabase/functions/location-search/provider.mjs";

// This verifier mutates only an explicitly disposable loopback QA stack.
assert.ok(
  process.env.PLANETS_DISPOSABLE_QA === "1" || process.env.CI === "true",
  "MAP01 requires disposable QA designation",
);
const { apiUrl, databaseUrl, publishableKey, serviceRoleKey } =
  readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL;
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  assert.ok(
    url && ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
    "MAP01 requires explicit loopback API/database/mailbox URLs",
  );
}
const db = postgres(databaseUrl, { max: 4, onnotice: () => {} });
const options = { auth: { autoRefreshToken: false, persistSession: false } };
const server = createClient(apiUrl, serviceRoleKey, options);
const anonymous = createClient(apiUrl, publishableKey, options);
let checks = 0;
function check(value, label) {
  assert.ok(value, label);
  checks++;
}
async function rpc(client, name, params) {
  const { data, error } = await client.rpc(name, params);
  if (error) throw new Error(`MAP01 ${name} failed (${error.code})`);
  return data;
}
async function denied(client, name, params, code) {
  const { error } = await client.rpc(name, params);
  check(error?.code === code, `${name}: ${code} expected`);
}
const original = (
  await db`select * from private.location_search_config where singleton`
)[0];
try {
  const [owner, peer] = await Promise.all(
    ["owner", "peer"].map((role) =>
      signInLocalOtpUser({
        apiUrl,
        publishableKey,
        mailpitUrl,
        email: `map01-${role}@planets.invalid`,
        verifierName: `MAP01 ${role}`,
      }),
    ),
  );
  await db`insert into public.profiles(id,display_name) values(${owner.id},'MAP01 synthetic owner'),(${peer.id},'MAP01 synthetic peer')
    on conflict(id) do update set display_name=excluded.display_name`;
  const proposal = await rpc(owner.client, "create_proposal_draft", {
    p_expected_creator_profile_id: owner.id,
    p_title: "MAP01 sparse draft",
    p_summary: null,
    p_description: null,
    p_starts_at: null,
    p_ends_at: null,
    p_event_timezone: "Europe/Paris",
    p_country_code: "FR",
    p_locality: "Legacy locality",
    p_administrative_area: null,
    p_public_location_label: "Legacy manual area",
    p_exact_meeting_text: "Private user instructions",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  const saved = await rpc(owner.client, "get_authorized_item_location_v1", {
    p_expected_profile_id: owner.id,
    p_kind: "one_time",
    p_item: proposal,
  });
  const scope = {
    p_actor: owner.id,
    p_kind: "one_time",
    p_item: proposal,
    p_revision: saved.revision,
    p_slot: "exact",
    p_session: randomUUID(),
    p_query_hash: "a".repeat(64),
  };
  await db`update private.location_search_config set enabled=false where singleton`;
  check(
    (await rpc(server, "reserve_location_search_v1", scope)).status ===
      "disabled",
    "Database disabled reserves zero calls",
  );
  await denied(owner.client, "reserve_location_search_v1", scope, "42501");
  await denied(anonymous, "reserve_location_search_v1", scope, "42501");
  await db`update private.location_search_config set enabled=true where singleton`;
  const reserved = await rpc(server, "reserve_location_search_v1", scope);
  const normalized = normalizeResults(
    {
      results: [
        {
          country_code: "it",
          city: "Synthetic locality",
          state: "Synthetic region",
          result_type: "building",
          formatted: "SECRET synthetic meeting",
          lat: 44,
          lon: 10,
          rank: { confidence: 0.9 },
          datasource: { sourcename: "openstreetmap" },
        },
      ],
    },
    "it",
  );
  const issued = await rpc(server, "issue_location_selections_v1", {
    p_batch: reserved.batch_id,
    p_places: normalized,
  });
  check(
    issued.status === "ok" && issued.suggestions.length === 1,
    "Real REST service-only issue boundary",
  );
  const receipt = issued.suggestions[0].id;
  const repeated = await rpc(server, "reserve_location_search_v1", scope);
  check(
    repeated.cached && repeated.suggestions[0].id === receipt,
    "Duplicate query reuses server receipt",
  );
  const resolved = await rpc(server, "resolve_location_selection_v1", {
    ...Object.fromEntries(
      Object.entries(scope).filter(([k]) => k !== "p_query_hash"),
    ),
    p_receipt: receipt,
  });
  check(
    resolved.selection.place.longitude === 10,
    "Resolve validates server point without new provider lookup",
  );
  const requestId = randomUUID();
  const mutation = {
    p_expected_profile_id: owner.id,
    p_kind: "one_time",
    p_item: proposal,
    p_expected_revision: saved.revision,
    p_request_id: requestId,
    p_public_action: "unchanged",
    p_public_receipt: null,
    p_exact_action: "replace",
    p_exact_receipt: receipt,
  };
  await denied(server, "apply_item_location_v1", mutation, "42501");
  await denied(
    peer.client,
    "apply_item_location_v1",
    { ...mutation, p_expected_profile_id: peer.id },
    "42501",
  );
  const revisions = await Promise.all([
    rpc(owner.client, "apply_item_location_v1", mutation),
    rpc(owner.client, "apply_item_location_v1", mutation),
  ]);
  check(
    revisions[0] === revisions[1],
    "Concurrent duplicate mutations serialize on parent and converge",
  );
  const authorized = await rpc(
    owner.client,
    "get_authorized_item_location_v1",
    { p_expected_profile_id: owner.id, p_kind: "one_time", p_item: proposal },
  );
  check(
    authorized.public_place === null && authorized.exact_place.latitude === 44,
    "Exact-only choice has no inferred public area",
  );
  await denied(
    peer.client,
    "get_authorized_item_location_v1",
    { p_expected_profile_id: peer.id, p_kind: "one_time", p_item: proposal },
    "42501",
  );
  check(
    (await rpc(anonymous, "get_public_item_location_v1", {
      p_kind: "one_time",
      p_item: proposal,
    })) === null,
    "Private draft has no public JSON projection",
  );
  const clear = {
    ...mutation,
    p_expected_revision: authorized.revision,
    p_request_id: randomUUID(),
    p_exact_action: "clear",
    p_exact_receipt: null,
  };
  const replacements = await Promise.allSettled([
    rpc(owner.client, "apply_item_location_v1", clear),
    rpc(owner.client, "apply_item_location_v1", {
      ...clear,
      p_request_id: randomUUID(),
    }),
  ]);
  // A no-op clear may keep the same revision; two explicit clears cannot restore
  // data. The conflicting-edit race below uses actual distinct content instead.
  check(
    replacements.every(
      (x) => x.status === "fulfilled" || x.reason.message.includes("40001"),
    ),
    "Concurrent clears preserve revision contract",
  );
  const current = (
    await db`select location_revision from public.proposals where id=${proposal}`
  )[0].location_revision;
  const nextScope = {
    ...scope,
    p_revision: Number(current),
    p_session: randomUUID(),
    p_query_hash: "b".repeat(64),
  };
  const nextReserve = await rpc(
    server,
    "reserve_location_search_v1",
    nextScope,
  );
  const nextIssue = await rpc(server, "issue_location_selections_v1", {
    p_batch: nextReserve.batch_id,
    p_places: normalized,
  });
  await db`update private.location_search_config set actor_minute=1 where singleton`;
  const racers = await Promise.all(
    ["c", "d"].map((q) =>
      rpc(server, "reserve_location_search_v1", {
        ...nextScope,
        p_session: randomUUID(),
        p_query_hash: q.repeat(64),
      }),
    ),
  );
  check(
    racers.every((x) => x.status === "rate_limited"),
    "Concurrent reservations share enforced actor meter",
  );
  await db`update private.location_search_config set enabled=false where singleton`;
  await denied(
    owner.client,
    "apply_item_location_v1",
    {
      ...mutation,
      p_expected_revision: Number(current),
      p_request_id: randomUUID(),
      p_exact_receipt: nextIssue.suggestions[0].id,
    },
    "55000",
  );
  check(
    (
      await db`select exact_location is null as empty,country_code from public.proposal_meeting_details m join public.proposals p on p.id=m.proposal_id where p.id=${proposal}`
    )[0].empty,
    "Disabled failed replace leaves manual draft intact",
  );

  // MAP02: editor bootstrap and canonical receipts in the other domains.
  // The normalized provider fixture stays entirely synthetic.
  await db`update private.location_search_config set enabled=true,actor_minute=10 where singleton`;
  for (const kind of ["recurring", "resource"]) {
    const domain =
      kind === "recurring" ? "recurring_activity" : "resource_listing";
    const expectedKey =
      kind === "recurring"
        ? "p_expected_creator_profile_id"
        : "p_expected_owner_profile_id";
    const args = {
      [expectedKey]: owner.id,
      p_client_request_id: randomUUID(),
      p_title: "MAP02 sparse editor draft",
      p_description: "",
      p_country_code: "FR",
      p_locality: "Legacy locality",
      p_administrative_area: null,
      p_public_location_label: "Legacy text",
      ...(kind === "resource"
        ? { p_listing_mode: "donate" }
        : {
            p_summary: "",
            p_topic: null,
            p_exact_meeting_text: "Private user instructions",
            p_exact_location_visibility: "participants",
            p_recurrence_type: null,
            p_weekday: null,
            p_day_of_month: null,
            p_local_start_time: null,
            p_duration_minutes: null,
            p_event_timezone: null,
            p_effective_from: null,
            p_registration_capacity: null,
            p_count_organizers_toward_capacity: false,
          }),
    };
    const createName = "create_editor_" + domain + "_draft";
    const ids = await Promise.all([
      rpc(owner.client, createName, args),
      rpc(owner.client, createName, args),
    ]);
    check(ids[0] === ids[1], kind + " duplicate draft deliveries converge");
    const item = ids[0],
      recoverName = "recover_editor_" + domain + "_draft";
    check(
      (await rpc(owner.client, recoverName, {
        [expectedKey]: owner.id,
        p_client_request_id: args.p_client_request_id,
      })) === item,
      kind + " lost creation response recovers canonical ID",
    );
    check(
      (await rpc(peer.client, recoverName, {
        [expectedKey]: peer.id,
        p_client_request_id: args.p_client_request_id,
      })) === null,
      kind + " recovery is actor-bound",
    );
    await denied(
      owner.client,
      createName,
      { ...args, p_title: "Changed retry intent" },
      "22023",
    );
    await denied(anonymous, createName, args, "42501");
    await denied(server, createName, args, "42501");
    const readArgs = {
      p_expected_profile_id: owner.id,
      p_kind: kind,
      p_item: item,
    };
    const initial = await rpc(
      owner.client,
      "get_authorized_item_location_v1",
      readArgs,
    );
    const slots = kind === "resource" ? ["public"] : ["area", "exact"];
    let latest = initial;
    for (const slot of slots) {
      const broad = slot === "area";
      const fixture = broad
        ? normalizeResults(
            {
              results: [
                {
                  country_code: "it",
                  city: "Trento",
                  state: "Trentino",
                  result_type: "city",
                  formatted: "Trento, Trentino",
                  lat: 46,
                  lon: 11,
                  rank: { confidence: 1 },
                  datasource: { sourcename: "openstreetmap" },
                },
              ],
            },
            "it",
          )
        : normalized;
      const bound = {
        p_actor: owner.id,
        p_kind: kind,
        p_item: item,
        p_revision: latest.revision,
        p_slot: slot,
        p_session: randomUUID(),
        p_query_hash: (slot === "area" ? "e" : "f").repeat(64),
      };
      const reservedSlot = await rpc(
        server,
        "reserve_location_search_v1",
        bound,
      );
      const issuedSlot = await rpc(server, "issue_location_selections_v1", {
        p_batch: reservedSlot.batch_id,
        p_places: fixture,
      });
      const receiptSlot = issuedSlot.suggestions[0].id;
      await rpc(server, "resolve_location_selection_v1", {
        ...Object.fromEntries(
          Object.entries(bound).filter(([k]) => k !== "p_query_hash"),
        ),
        p_receipt: receiptSlot,
      });
      const write = {
        ...readArgs,
        p_expected_revision: latest.revision,
        p_request_id: randomUUID(),
        p_public_action: slot === "exact" ? "unchanged" : "replace",
        p_public_receipt: slot === "exact" ? null : receiptSlot,
        p_exact_action: slot === "exact" ? "replace" : "unchanged",
        p_exact_receipt: slot === "exact" ? receiptSlot : null,
      };
      await denied(
        peer.client,
        "apply_item_location_v1",
        { ...write, p_expected_profile_id: peer.id },
        "42501",
      );
      const appliedRevision = await rpc(
        owner.client,
        "apply_item_location_v1",
        write,
      );
      check(
        (await rpc(owner.client, "apply_item_location_v1", write)) ===
          appliedRevision,
        kind + " " + slot + " response-loss retry retains mutation ID",
      );
      latest = await rpc(
        owner.client,
        "get_authorized_item_location_v1",
        readArgs,
      );
      check(
        latest.revision === appliedRevision,
        kind + " canonical reread matches committed revision",
      );
    }
    check(
      latest.public_place !== null,
      kind + " independently selected public place",
    );
    check(
      kind === "resource"
        ? latest.exact_place === null
        : latest.exact_place !== null,
      kind + " precision/privacy shape is canonical",
    );
    if (kind === "recurring") {
      const [meeting] =
        await db`select exact_meeting_text,exact_location_visibility from public.recurring_activity_meeting_details where recurring_activity_id=${item}`;
      check(
        meeting.exact_meeting_text === "Private user instructions" &&
          meeting.exact_location_visibility === "participants",
        "Tavolo selections preserve instructions and visibility",
      );
    }
    await denied(
      peer.client,
      "get_authorized_item_location_v1",
      { ...readArgs, p_expected_profile_id: peer.id },
      "42501",
    );
    check(
      (await rpc(anonymous, "get_public_item_location_v1", {
        p_kind: kind,
        p_item: item,
      })) === null,
      kind + " draft has no public selection projection",
    );
    await rpc(owner.client, "apply_item_location_v1", {
      ...readArgs,
      p_expected_revision: latest.revision,
      p_request_id: randomUUID(),
      p_public_action: "clear",
      p_public_receipt: null,
      p_exact_action: "unchanged",
      p_exact_receipt: null,
    });
    const cleared = await rpc(
      owner.client,
      "get_authorized_item_location_v1",
      readArgs,
    );
    check(
      cleared.public_place === null &&
        (kind === "resource" || cleared.exact_place !== null),
      kind + " clear changes only the requested slot",
    );
  }
  await db.unsafe(
    "update private.location_search_config set enabled=true,actor_minute=20 where singleton",
  );
  await verifyLocationPreviews({
    db,
    owner,
    peer,
    server,
    anonymous,
    rpc,
    denied,
    check,
    selected: authorized.exact_place,
  });
  console.log(
    `MAP01/MAP02/MAP03 ${checks} authenticated REST/concurrency checks passed; fake provider only, no Geoapify traffic.`,
  );
} finally {
  await db`update private.location_search_config set enabled=${original.enabled},global_daily=${original.global_daily},actor_daily=${original.actor_daily},actor_minute=${original.actor_minute} where singleton`;
  await db.end();
}
