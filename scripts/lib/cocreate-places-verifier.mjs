import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { signInLocalOtpUser } from "./local-authenticated-user.mjs";
import { createHandler } from "../../supabase/functions/location-search/handler.mjs";
import { LocationFailure } from "../../supabase/functions/location-search/provider.mjs";

// Real OTP/Auth and service/client HTTP RPCs. Only the upstream Geoapify bytes
// are synthetic, through the SAME production normalization/receipt adapter.
export async function verifyCocreatePlaces({ sql, status }) {
  const mailpit = new URL(process.env.MAILPIT_URL ?? "http://127.0.0.1:54324");
  assert.ok(
    mailpit.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(mailpit.hostname) &&
      !mailpit.username &&
      !mailpit.password &&
      mailpit.pathname === "/" &&
      !mailpit.search &&
      !mailpit.hash,
  );
  const run = randomUUID().slice(0, 8);
  let checks = 0,
    providerAttempts = 0;
  const equal = (a, b, label) => {
    assert.deepEqual(a, b, label);
    checks++;
  };
  const actor = (p) => ({ p_expected_profile_id: p.id });
  const command = (p) => ({ ...actor(p), p_command_id: randomUUID() });
  async function rpc(p, name, args) {
    const r = await p.client.rpc(name, args);
    equal(r.error?.code ?? null, null, `${name}: ${r.error?.message ?? "ok"}`);
    return r.data;
  }
  async function denied(p, name, args, code = "42501") {
    const r = await p.client.rpc(name, args);
    equal(
      r.error?.code,
      code,
      `${name} denies: ${r.error?.message ?? "no error"}`,
    );
  }
  async function person(label) {
    const p = await signInLocalOtpUser({
      ...status,
      mailpitUrl: mailpit.toString().replace(/\/$/, ""),
      email: `places-${run}-${label}@planets.invalid`,
      verifierName: "cocreate-places",
      dataFetch: async (input, init) => {
        const request = new Request(input, init);
        return request.url === `${status.apiUrl}/functions/v1/location-search`
          ? handler(request)
          : fetch(input, init);
      },
    });
    await sql`insert into public.profiles(id,display_name) values(${p.id}::uuid,${`Synthetic Place ${label}`})`;
    await rpc(p, "accept_policy_bundle", {
      p_expected_account_id: p.id,
      p_bundle_version: "POLICY01-2026-10-08-v1",
    });
    return p;
  }
  const [settings] = await sql`select enabled from private.cocreate_settings`;
  const [searchConfig] =
    await sql`select enabled from private.location_search_config`;
  const [providerConfig] =
    await sql`select enabled,daily_units_limit from private.location_provider_config`;
  async function serviceRpc(name, args) {
    const response = await fetch(`${status.apiUrl}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: status.serviceRoleKey,
        Authorization: `Bearer ${status.serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
    });
    const value = await response.json();
    if (!response.ok)
      throw new LocationFailure(
        value.code === "42501"
          ? "unauthorized"
          : value.code === "22023"
            ? "invalid_request"
            : "metering_unavailable",
      );
    return value;
  }
  let venue = {
    label: "Synthetic football field",
    kind: "amenity",
    longitude: 11.1,
  };
  const handler = createHandler({
    enabled: true,
    key: "synthetic-not-a-live-key",
    authenticate: async (header) => {
      const response = await fetch(`${status.apiUrl}/auth/v1/user`, {
        headers: { apikey: status.publishableKey, Authorization: header ?? "" },
      });
      return response.ok ? (await response.json()).id : null;
    },
    rpc: serviceRpc,
    fetcher: async () => {
      providerAttempts++;
      return Response.json({
        results: [
          {
            country_code: "it",
            city: "Synthetic locality",
            state: "Synthetic region",
            formatted: venue.label,
            result_type: venue.kind === "address" ? "building" : "amenity",
            lat: 46.1,
            lon: venue.longitude,
            rank: { confidence: 0.9 },
            datasource: { sourcename: "openstreetmap", raw: { ignored: true } },
          },
        ],
      });
    },
  });
  async function search(p, context, overrides = {}) {
    const body = {
      operation: "search",
      expected_profile_id: p.id,
      item_kind: context.room_id ? "cocreate_room" : "cocreate_hub",
      item_id: context.episode_id,
      revision: context.version,
      slot: "exact",
      session_token: randomUUID(),
      query: venue.label,
      language: "en",
      ...overrides,
    };
    const request = async (body) => {
      const result = await p.client.functions.invoke("location-search", {
        body,
      });
      if (result.error)
        throw new Error("Local location handler transport failed.");
      return result.data;
    };
    const result = await request(body);
    return { result, request, body };
  }
  async function selection(p, context, nextVenue = venue) {
    venue = nextVenue;
    const before = providerAttempts,
      { result, request, body } = await search(p, context);
    equal(result.status, "ok", "actual search reservation/issuance succeeds");
    equal(
      providerAttempts,
      before + 1,
      "one bounded synthetic upstream request",
    );
    equal(result.suggestions.length, 1, "one normalized server receipt");
    const suggestion = result.suggestions[0];
    equal(
      suggestion.place.place_id,
      undefined,
      "opaque provider IDs remain stripped",
    );
    const { query: _query, language: _language, ...scope } = body;
    const resolved = await request({
      ...scope,
      operation: "resolve",
      receipt_id: suggestion.id,
    });
    equal(
      resolved.status,
      "ok",
      "receipt resolves through service-only authority",
    );
    equal(providerAttempts, before + 1, "resolve adds zero provider requests");
    return suggestion.id;
  }
  try {
    await sql`update private.cocreate_settings set enabled=true`;
    await sql`update private.location_search_config set enabled=false`;
    const people = [];
    for (const label of [
      "manager",
      "member",
      "other-manager",
      "racer",
      "outsider",
    ])
      people.push(await person(label));
    const [a, b, c, d, outsider] = people;
    const proposed = await rpc(a, "propose_cocreate_community", {
      ...command(a),
      p_category_id: "sports",
      p_name: `Synthetic field ${run}`,
      p_locality: "Synthetic Place locality",
    });
    for (const p of [b, c])
      await rpc(p, "mutate_cocreate_community_interest", {
        ...command(p),
        p_proposal_id: proposed.proposal_id,
        p_operation: "interest",
      });
    const { hub_id: hub } = await rpc(a, "get_cocreate_community_proposal", {
      p_proposal_id: proposed.proposal_id,
    });
    const admitted = new Map();
    for (const p of [a, b, c, d])
      admitted.set(
        p.id,
        await rpc(p, "mutate_cocreate_hub", {
          ...command(p),
          p_hub_id: hub,
          p_operation: "join",
        }),
      );
    const context = (p, room = null) =>
      rpc(p, "get_cocreate_place_context_v1", {
        ...actor(p),
        p_hub_id: hub,
        p_room_id: room?.room_id ?? null,
        p_episode_id: room?.episode_id ?? null,
      });
    const group = await rpc(a, "mutate_cocreate_numbered_group", {
      ...command(a),
      p_hub_id: hub,
      p_operation: "create",
      p_capacity: 50,
    });
    let scope = await context(a, group);
    equal(scope.usual_place, null, "locationless group stays valid");
    const beforeDisabled = providerAttempts;
    equal(
      (await search(a, scope)).result.status,
      "disabled",
      "disabled provider returns explicit status",
    );
    equal(
      providerAttempts,
      beforeDisabled,
      "disabled configuration makes zero provider attempts",
    );
    await denied(outsider, "get_cocreate_place_context_v1", {
      ...actor(outsider),
      p_hub_id: hub,
    });
    await sql`update private.location_search_config set enabled=true`;
    await sql`update private.location_provider_config set enabled=true,daily_units_limit=1000`;
    const receipt = await selection(a, scope);
    const usualArgs = {
      ...command(a),
      p_hub_id: hub,
      p_room_id: group.room_id,
      p_episode_id: group.episode_id,
      p_expected_version: scope.version,
      p_selection_receipt: receipt,
      p_discoverable: false,
    };
    const usual = await rpc(a, "set_cocreate_usual_place_v1", usualArgs);
    equal(
      await rpc(a, "set_cocreate_usual_place_v1", usualArgs),
      usual,
      "lost usual-place reply recovers exactly",
    );
    equal(
      (
        await rpc(b, "list_cocreate_places_v1", {
          ...actor(b),
          p_hub_id: hub,
          p_episode_id: admitted.get(b.id).episode_id,
        })
      ).places,
      [],
      "OFF reveals no private place/count",
    );
    await denied(b, "set_cocreate_usual_place_v1", {
      ...usualArgs,
      p_command_id: randomUUID(),
      p_expected_profile_id: a.id,
    });
    const beforeForged = providerAttempts;
    equal(
      (await search(b, scope)).result.status,
      "unauthorized",
      "another actor cannot use manager selection episode",
    );
    equal(
      providerAttempts,
      beforeForged,
      "forged target never reaches provider",
    );
    scope = await context(a, group);
    await rpc(a, "set_cocreate_usual_place_v1", {
      ...command(a),
      p_hub_id: hub,
      p_room_id: group.room_id,
      p_episode_id: group.episode_id,
      p_expected_version: scope.version,
      p_place_id: usual.place_id,
      p_discoverable: true,
    });
    const otherGroup = await rpc(c, "mutate_cocreate_numbered_group", {
      ...command(c),
      p_hub_id: hub,
      p_operation: "create",
      p_capacity: 50,
    });
    const otherScope = await context(c, otherGroup);
    const same = await rpc(c, "set_cocreate_usual_place_v1", {
      ...command(c),
      p_hub_id: hub,
      p_room_id: otherGroup.room_id,
      p_episode_id: otherGroup.episode_id,
      p_expected_version: otherScope.version,
      p_selection_receipt: await selection(c, otherScope),
      p_discoverable: true,
    });
    equal(
      same.place_id,
      usual.place_id,
      "separate verified selections deduplicate exact snapshots",
    );
    const discovery = await rpc(
      outsider,
      "list_discoverable_cocreate_places_v1",
      actor(outsider),
    );
    equal(
      discovery.places.find((p) => p.place.place_id === usual.place_id).groups,
      2,
      "public-safe venue has two opted-in usual groups",
    );
    const starts = new Date(Date.now() + 2 * 86400000).toISOString();
    const meetingArgs = {
      ...command(a),
      p_hub_id: hub,
      p_room_id: group.room_id,
      p_episode_id: group.episode_id,
      p_starts_at: starts,
      p_capacity: 2,
      p_place_id: usual.place_id,
      p_discoverable: true,
    };
    const attemptsBeforeReuse = providerAttempts;
    const meeting = await rpc(a, "schedule_cocreate_meeting_v2", meetingArgs);
    equal(
      providerAttempts,
      attemptsBeforeReuse,
      "using usual Place requires no provider request",
    );
    const races = await Promise.all(
      [b, d].map((p) =>
        p.client.rpc("join_cocreate_recruitment", {
          ...command(p),
          p_hub_id: hub,
          p_room_id: group.room_id,
          p_recruitment_id: meeting.recruitment_id,
        }),
      ),
    );
    equal(
      races.filter((r) => !r.error).length,
      1,
      "last meeting seat has one winner",
    );
    equal(
      races.filter((r) => r.error?.code === "PT409").length,
      1,
      "last-seat loser receives conflict",
    );
    const winner = races[0].error ? d : b,
      winnerReceipt = races.find((r) => !r.error).data;
    const memberPlace = await rpc(winner, "get_cocreate_current_meeting_v2", {
      ...actor(winner),
      p_room_id: group.room_id,
      p_episode_id: winnerReceipt.episode_id,
    });
    equal(
      memberPlace.occupied,
      2,
      "place association cannot overbook occurrence",
    );
    equal(
      memberPlace.place.place_id,
      usual.place_id,
      "member reviews occurrence Place",
    );
    await denied(winner, "set_cocreate_usual_place_v1", {
      ...command(winner),
      p_hub_id: hub,
      p_room_id: group.room_id,
      p_episode_id: winnerReceipt.episode_id,
      p_expected_version: (await context(a, group)).version,
      p_place_id: usual.place_id,
      p_discoverable: false,
    });
    const fresh = await context(c, otherGroup);
    const otherReceipt = await selection(c, fresh, {
      label: "Synthetic second field",
      kind: "amenity",
      longitude: 11.1000001,
    });
    const otherMeeting = await rpc(c, "schedule_cocreate_meeting_v2", {
      ...command(c),
      p_hub_id: hub,
      p_room_id: otherGroup.room_id,
      p_episode_id: otherGroup.episode_id,
      p_starts_at: new Date(Date.now() + 3 * 86400000).toISOString(),
      p_capacity: 5,
      p_selection_receipt: otherReceipt,
      p_scope_episode_id: fresh.episode_id,
      p_scope_revision: fresh.version,
      p_discoverable: true,
    });
    assert.notEqual(otherMeeting.place_id, usual.place_id);
    checks++;
    equal(
      (await context(c, otherGroup)).usual_place.place_id,
      usual.place_id,
      "different occurrence leaves usual association intact",
    );
    const detailArgs = {
      ...actor(c),
      p_hub_id: hub,
      p_episode_id: admitted.get(c.id).episode_id,
      p_place_id: usual.place_id,
    };
    const detail = await rpc(c, "get_cocreate_place_detail_v1", detailArgs);
    equal(detail.groups.length, 2, "Place detail returns both eligible groups");
    const full = detail.groups.find((g) => g.room_id === group.room_id).meeting;
    equal(
      [full.capacity, full.occupied, full.can_join],
      [2, 2, false],
      "Full is actual meeting occupancy, not group chat",
    );
    await denied(outsider, "get_cocreate_place_detail_v1", {
      ...detailArgs,
      ...actor(outsider),
    });
    const generalScope = await context(d);
    const newReceipt = await selection(d, generalScope, {
      label: "Synthetic third field",
      kind: "amenity",
      longitude: 11.2,
    });
    const newArgs = {
      ...command(d),
      p_hub_id: hub,
      p_starts_at: new Date(Date.now() + 4 * 86400000).toISOString(),
      p_capacity: 5,
      p_selection_receipt: newReceipt,
      p_scope_episode_id: generalScope.episode_id,
      p_scope_revision: 0,
      p_discoverable: true,
    };
    const newMeeting = await rpc(d, "schedule_cocreate_meeting_v2", newArgs);
    equal(
      newMeeting.place_id != null,
      true,
      "pre-command General selection commits with new group/meeting/recruitment",
    );
    equal(
      await rpc(d, "schedule_cocreate_meeting_v2", newArgs),
      newMeeting,
      "schedule reply-loss retry has no duplicate enrollment",
    );
    const aScope = await context(a, group);
    const address = await selection(a, aScope, {
      label: "Synthetic private address",
      kind: "address",
      longitude: 11.3,
    });
    const privatePlace = await rpc(a, "set_cocreate_usual_place_v1", {
      ...command(a),
      p_hub_id: hub,
      p_room_id: group.room_id,
      p_episode_id: group.episode_id,
      p_expected_version: aScope.version,
      p_selection_receipt: address,
      p_discoverable: false,
    });
    await denied(
      a,
      "set_cocreate_usual_place_v1",
      {
        ...command(a),
        p_hub_id: hub,
        p_room_id: group.room_id,
        p_episode_id: group.episode_id,
        p_expected_version: (await context(a, group)).version,
        p_place_id: privatePlace.place_id,
        p_discoverable: true,
      },
      "22023",
    );
    equal(
      (
        await rpc(
          outsider,
          "list_discoverable_cocreate_places_v1",
          actor(outsider),
        )
      ).places.some((p) => p.place.place_id === privatePlace.place_id),
      false,
      "address excluded even from aggregate counts",
    );
    equal(
      (
        await rpc(a, "get_cocreate_current_meeting_v2", {
          ...actor(a),
          p_room_id: group.room_id,
          p_episode_id: group.episode_id,
        })
      ).place.place_id,
      usual.place_id,
      "usual change does not move scheduled attendees",
    );
    const ackBefore =
      await sql`select id::text,read_sequence from private.cocreate_room_episodes order by id`;
    const calendarArgs = {
      ...actor(c),
      p_hub_id: hub,
      p_general_room_id: admitted.get(c.id).room_id,
      p_episode_id: admitted.get(c.id).episode_id,
      p_window_start: new Date().toISOString(),
      p_window_end: new Date(Date.now() + 31 * 86400000).toISOString(),
      p_limit: 1,
    };
    const old = await rpc(c, "get_cocreate_calendar_v1", calendarArgs),
      current = await rpc(c, "get_cocreate_calendar_v2", calendarArgs);
    const withoutPlace = {
      ...current,
      meetings: current.meetings.map(({ place: _place, ...row }) => row),
    };
    equal(
      withoutPlace,
      old,
      "installed calendar envelope/row/cursor stays exact",
    );
    equal(
      (
        await rpc(c, "get_cocreate_calendar_v2", {
          ...calendarArgs,
          p_cursor: old.next_cursor,
        })
      ).meetings.length,
      1,
      "old signed continuation works with new read",
    );
    await rpc(c, "get_cocreate_place_detail_v1", detailArgs);
    equal(
      await sql`select id::text,read_sequence from private.cocreate_room_episodes order by id`,
      ackBefore,
      "reads do not ACK or mutate chat",
    );
    await rpc(winner, "block_user", {
      p_expected_blocker_profile_id: winner.id,
      p_blocked_profile_id: a.id,
    });
    equal(
      (
        await rpc(winner, "get_cocreate_current_meeting_v2", {
          ...actor(winner),
          p_room_id: group.room_id,
          p_episode_id: winnerReceipt.episode_id,
        })
      ).place.place_id,
      usual.place_id,
      "blocked current member retains occurrence review",
    );
    equal(
      (
        await rpc(winner, "list_discoverable_cocreate_places_v1", actor(winner))
      ).places.some((p) => p.place.place_id === usual.place_id),
      true,
      "unblocked other group's explicit association remains independently eligible",
    );
    await rpc(d, "mutate_cocreate_meeting", {
      ...command(d),
      p_hub_id: hub,
      p_room_id: newMeeting.room_id,
      p_episode_id: newMeeting.episode_id,
      p_meeting_id: newMeeting.meeting_id,
      p_operation: "cancel",
    });
    equal(
      (
        await rpc(
          outsider,
          "list_discoverable_cocreate_places_v1",
          actor(outsider),
        )
      ).places.some((p) => p.place.place_id === newMeeting.place_id),
      false,
      "cancel removes discoverable session",
    );
    const expireScope = await context(c, otherGroup),
      expired = await selection(c, expireScope);
    await sql`update private.location_search_batches set expires_at=clock_timestamp()-interval '1 second' where id=(select batch_id from private.location_selection_receipts where id=${expired}::uuid)`;
    await denied(
      c,
      "set_cocreate_usual_place_v1",
      {
        ...command(c),
        p_hub_id: hub,
        p_room_id: otherGroup.room_id,
        p_episode_id: otherGroup.episode_id,
        p_expected_version: expireScope.version,
        p_selection_receipt: expired,
        p_discoverable: false,
      },
      "22023",
    );
    const staleScope = await context(c, otherGroup),
      staleReceipt = await selection(c, staleScope);
    await rpc(c, "set_cocreate_usual_place_v1", {
      ...command(c),
      p_hub_id: hub,
      p_room_id: otherGroup.room_id,
      p_episode_id: otherGroup.episode_id,
      p_expected_version: staleScope.version,
      p_place_id: usual.place_id,
      p_discoverable: false,
    });
    const beforeLate = providerAttempts;
    equal(
      (await search(c, staleScope)).result.status,
      "stale_selection",
      "late search cannot cross structural target replacement",
    );
    equal(
      providerAttempts,
      beforeLate,
      "stale authority consumes zero provider attempts",
    );
    await denied(
      c,
      "set_cocreate_usual_place_v1",
      {
        ...command(c),
        p_hub_id: hub,
        p_room_id: otherGroup.room_id,
        p_episode_id: otherGroup.episode_id,
        p_expected_version: staleScope.version,
        p_selection_receipt: staleReceipt,
        p_discoverable: false,
      },
      "PT409",
    );
    await sql`update private.location_search_config set enabled=false`;
    const noPlace = await rpc(b, "schedule_cocreate_meeting_v2", {
      ...command(b),
      p_hub_id: hub,
      p_starts_at: new Date(Date.now() + 5 * 86400000).toISOString(),
      p_capacity: 5,
      p_discoverable: false,
    });
    equal(
      noPlace.place_id,
      null,
      "ordinary scheduling stays usable when place provider is disabled",
    );
    equal(
      await rpc(d, "schedule_cocreate_meeting_v2", newArgs),
      newMeeting,
      "frozen command recovers even after cancellation/provider-off",
    );
    await sql`update private.cocreate_settings set enabled=false`;
    await denied(a, "list_discoverable_cocreate_places_v1", actor(a));
    console.log(
      `PLACE01 real Auth/HTTP passed (${checks} assertions, ${providerAttempts} synthetic provider requests; zero live provider requests).`,
    );
  } finally {
    await sql`update private.cocreate_settings set enabled=${settings.enabled}`;
    await sql`update private.location_search_config set enabled=${searchConfig.enabled}`;
    await sql`update private.location_provider_config set enabled=${providerConfig.enabled},daily_units_limit=${providerConfig.daily_units_limit}`;
  }
}
