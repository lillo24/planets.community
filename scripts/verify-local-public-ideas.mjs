import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

// Invoked by proposal:verify:local. These real OTP/JWT scenarios write synthetic
// fixtures only, and require the same disposable designation as check:db.
export async function verifyPublicIdeas() {
  assert.ok(
    process.env.PLANETS_DISPOSABLE_QA === "1" || process.env.CI === "true",
    "IDEA01A requires an explicitly disposable QA stack",
  );
  const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
    process.cwd(),
  );
  // Standard CI uses the repository's local Mailpit port. Isolated nonstandard
  // stacks must provide MAILPIT_URL, as in the other proposal verifiers.
  const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
  for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
    assert.ok(
      url &&
        ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
      "IDEA01A requires loopback API/database/mailbox URLs",
    );
  }
  const db = postgres(databaseUrl, { max: 6, onnotice: () => {} });
  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  let checks = 0;
  const check = (condition, label) => {
    assert.ok(condition, label);
    checks++;
  };
  const call = async (user, name, params) => {
    const { data, error } = await user.client.rpc(name, params);
    if (error) throw new Error(`IDEA01A ${name} failed (${error.code})`);
    return data;
  };
  const denied = async (user, name, params, code) => {
    const { error } = await user.client.rpc(name, params);
    check(error?.code === code, `${name} must reject with ${code}`);
  };
  const identity = (user, id) => ({
    p_expected_profile_id: user.id,
    p_proposal_id: id,
  });
  const publication = (user, id) => ({
    p_expected_creator_profile_id: user.id,
    p_proposal_id: id,
  });
  const input = (user, fields = {}) => ({
    p_expected_creator_profile_id: user.id,
    p_title: "IDEA01A synthetic collaboration",
    p_summary: "Work together to agree the date and place.",
    p_description: null,
    p_starts_at: null,
    p_ends_at: null,
    p_event_timezone: null,
    p_country_code: null,
    p_locality: null,
    p_administrative_area: null,
    p_public_location_label: null,
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: null,
    p_count_organizers_toward_capacity: false,
    ...fields,
  });
  const complete = {
    p_description: "Plan a real multi-day collaboration after discussion.",
    p_starts_at: new Date(Date.now() + 3 * 86400000).toISOString(),
    p_ends_at: new Date(Date.now() + 5 * 86400000).toISOString(),
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    // Keep completed race fixtures out of the separate Trento demo's bounded
    // discovery page. This city is synthetic; no geometry/provider is involved.
    p_locality: "IDEA01A synthetic city",
    p_public_location_label: "IDEA01A synthetic city, IT",
    p_registration_capacity: 4,
  };
  const draft = (user, fields) =>
    call(user, "create_proposal_draft", input(user, fields));
  const idea = async (user, fields) => {
    const id = await draft(user, fields);
    await call(user, "publish_proposal_idea", publication(user, id));
    return id;
  };
  const edit = (user, id, fields) =>
    call(user, "update_own_proposal", {
      ...input(user, fields),
      p_proposal_id: id,
    });
  const publicDetail = async (id) =>
    (
      await call({ client: anonymous }, "get_public_proposal_v2", {
        p_proposal_id: id,
      })
    )[0];
  const invite = async (owner, id) =>
    (
      await call(owner, "create_project_participant_invitation", {
        p_expected_profile_id: owner.id,
        p_project_id: id,
      })
    )[0];
  const acceptParams = (user, link, action = randomUUID()) => ({
    p_expected_profile_id: user.id,
    p_token: link.invite_token,
    p_client_action_id: action,
  });
  const delegate = async (owner, user, id, role) => {
    const [link] = await call(owner, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: owner.id,
      p_project_id: id,
      p_requested_authority_role: role,
    });
    return call(user, "accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: user.id,
      p_token: link.invite_token,
    });
  };
  try {
    const [owner, member, peer, coCreator, organizer] = await Promise.all(
      ["owner", "member", "peer", "cocreator", "organizer"].map((role) =>
        signInLocalOtpUser({
          apiUrl,
          publishableKey,
          mailpitUrl,
          email: `idea01a-${role}@planets.invalid`,
          verifierName: "IDEA01A",
        }),
      ),
    );
    for (const user of [owner, member, peer, coCreator, organizer]) {
      const { error } = await user.client
        .from("profiles")
        .insert({ id: user.id });
      if (error && error.code !== "23505")
        throw new Error(`IDEA01A profile anchor (${error.code})`);
      await call(user, "update_own_profile", {
        p_expected_profile_id: user.id,
        p_display_name: "Synthetic Idea actor",
        p_bio: null,
        p_skill_ids: [],
        p_display_name_audience: "public",
        p_bio_audience: "private",
        p_skills_audience: "public",
      });
      await ensureLocalProfilePhoto(user);
    }

    const id = await idea(owner);
    const published = (
      await db`select published_at from public.proposals where id=${id}`
    )[0].published_at;
    const detail = await publicDetail(id);
    check(
      detail.definition_phase === "idea" &&
        detail.derived_status === null &&
        detail.starts_at === null &&
        detail.locality === null,
      "honest nullable public JWT detail",
    );
    check(
      (
        await call({ client: anonymous }, "list_public_proposals_v2", {
          p_definition_phase: "idea",
        })
      ).some((p) => p.proposal_id === id),
      "anonymous city-less List discovery",
    );
    for (const name of ["get_public_proposal", "get_own_proposal"]) {
      check(
        (
          await call(
            owner,
            name,
            name === "get_own_proposal"
              ? publication(owner, id)
              : { p_proposal_id: id },
          )
        ).length === 0,
        "legacy direct links exclude Idea",
      );
    }
    await denied(peer, "promote_proposal_idea", identity(peer, id), "42501");
    await denied(peer, "promote_proposal_idea", identity(owner, id), "42501");
    const requestId = await call(member, "request_to_join_project", {
      p_expected_requester_profile_id: member.id,
      p_project_id: id,
      p_request_message: null,
    });
    const membershipId = await call(owner, "accept_project_join_request", {
      p_expected_creator_profile_id: owner.id,
      p_request_id: requestId,
    });
    const [chat] = await call(member, "get_own_project_group_chat", {
      p_expected_profile_id: member.id,
      p_project_id: id,
    });
    const [message] = await call(member, "send_project_chat_message", {
      p_expected_profile_id: member.id,
      p_chat_id: chat.chat_id,
      p_body: "Let us agree the date and city together.",
    });
    check(
      Boolean(message),
      "accepted Idea participant sends canonical durable chat message",
    );
    await denied(
      peer,
      "get_project_participant_meeting_details",
      {
        p_expected_profile_id: peer.id,
        p_project_id: id,
      },
      "42501",
    );
    await edit(owner, id, {
      p_exact_meeting_text: "Synthetic protected meeting instructions",
    });
    check(
      (await publicDetail(id)).exact_meeting_text === null &&
        (await publicDetail(id)).exact_location_restricted,
      "participants-only Idea details remain protected",
    );
    await edit(owner, id, {
      p_exact_meeting_text: "Synthetic explicitly public instructions",
      p_exact_location_visibility: "public",
    });
    check(
      (await publicDetail(id)).exact_meeting_text ===
        "Synthetic explicitly public instructions",
      "explicit public precise-text choice remains honored",
    );
    await edit(owner, id, {
      p_starts_at: new Date(Date.now() - 5 * 86400000).toISOString(),
      p_ends_at: new Date(Date.now() - 4 * 86400000).toISOString(),
    });
    check(
      (await publicDetail(id)).derived_status === null,
      "tentative past dates do not complete Idea",
    );

    await edit(owner, id, complete);
    for (const field of [
      "description",
      "starts_at",
      "ends_at",
      "event_timezone",
      "country_code",
      "locality",
      "public_location_label",
      "registration_capacity",
    ]) {
      await edit(owner, id, { ...complete, [`p_${field}`]: null });
      const preview = await call(
        owner,
        "get_proposal_promotion_requirements",
        identity(owner, id),
      );
      const missing = field;
      check(
        preview.missing_fields.length === 1 &&
          preview.missing_fields[0] === missing,
        `promotion preview identifies only missing ${missing}`,
      );
      const { error } = await owner.client.rpc(
        "promote_proposal_idea",
        identity(owner, id),
      );
      check(
        error?.code === "PT422" &&
          JSON.parse(error.details).missing_fields.includes(missing),
        `atomic promotion rejects missing ${missing}`,
      );
    }
    await edit(owner, id, complete);
    const coId = await delegate(owner, coCreator, id, "co_creator");
    await delegate(owner, organizer, id, "co_organizer");
    await denied(
      organizer,
      "promote_proposal_idea",
      identity(organizer, id),
      "42501",
    );
    // Keep actual public storage/photo setup; only temporarily remove the metadata
    // on this disposable fixture to test current trust revalidation.
    const [photo] =
      await db`delete from public.profile_photos where profile_id=${owner.id} returning *`;
    await denied(
      coCreator,
      "promote_proposal_idea",
      identity(coCreator, id),
      "PT422",
    );
    await db`insert into public.profile_photos ${db(photo)}`;
    await call(owner, "revoke_project_delegate", {
      p_expected_owner_profile_id: owner.id,
      p_delegate_id: coId,
    });
    await denied(
      coCreator,
      "promote_proposal_idea",
      identity(coCreator, id),
      "42501",
    );
    await delegate(owner, coCreator, id, "co_creator");
    const link = await invite(owner, id);
    const promoted = await Promise.all([
      coCreator.client.rpc("promote_proposal_idea", identity(coCreator, id)),
      owner.client.rpc("promote_proposal_idea", identity(owner, id)),
      peer.client.rpc(
        "accept_project_participant_invitation",
        acceptParams(peer, link),
      ),
    ]);
    check(
      promoted.every((r) => !r.error),
      "promotion retries serialize with direct invitation admission",
    );
    const after = await publicDetail(id);
    check(
      after.definition_phase === "defined" &&
        new Date(after.starts_at).getTime() ===
          new Date(complete.p_starts_at).getTime() &&
        new Date(after.ends_at).getTime() ===
          new Date(complete.p_ends_at).getTime(),
      "Co-creator promotes the complete multi-day interval unchanged",
    );
    check(
      (
        await db`select published_at from public.proposals where id=${id}`
      )[0].published_at.getTime() === published.getTime(),
      "promotion preserves original publication timestamp",
    );
    check(
      (
        await db`select count(*)::int n from private.audit_events where target_id=${id}
      and action='proposal.promoted'`
      )[0].n === 1,
      "raced promotion creates one audit event",
    );
    check(
      (
        await call(member, "get_own_project_group_chat", {
          p_expected_profile_id: member.id,
          p_project_id: id,
        })
      )[0].chat_id === chat.chat_id,
      "promotion preserves membership/chat identity",
    );
    await call(member, "leave_project", {
      p_expected_participant_profile_id: member.id,
      p_membership_id: membershipId,
    });
    await denied(
      member,
      "send_project_chat_message",
      {
        p_expected_profile_id: member.id,
        p_chat_id: chat.chat_id,
        p_body: "Forbidden post-leave message",
      },
      "42501",
    );
    await denied(
      member,
      "get_project_participant_meeting_details",
      {
        p_expected_profile_id: member.id,
        p_project_id: id,
      },
      "42501",
    );

    await db`update public.proposals set starts_at=now()-interval '1 hour',ends_at=now()+interval '1 day' where id=${id}`;
    await denied(
      owner,
      "update_own_proposal",
      {
        ...input(owner, complete),
        p_proposal_id: id,
      },
      "55000",
    );

    for (let round = 0; round < 3; round++) {
      const roleId = await idea(owner, complete);
      const delegateId = await delegate(owner, coCreator, roleId, "co_creator");
      const outcomes = await Promise.all([
        owner.client.rpc("revoke_project_delegate", {
          p_expected_owner_profile_id: owner.id,
          p_delegate_id: delegateId,
        }),
        coCreator.client.rpc(
          "promote_proposal_idea",
          identity(coCreator, roleId),
        ),
      ]);
      check(
        !outcomes[0].error &&
          (!outcomes[1].error || outcomes[1].error.code === "42501"),
        "Co-creator revocation/promotion race respects serialized authority",
      );
      await denied(
        coCreator,
        "promote_proposal_idea",
        identity(coCreator, roleId),
        "42501",
      );
    }

    for (let round = 0; round < 3; round++) {
      const editId = await idea(owner, complete);
      const outcomes = await Promise.all([
        owner.client.rpc("promote_proposal_idea", identity(owner, editId)),
        owner.client.rpc("update_own_proposal", {
          ...input(owner, { ...complete, p_registration_capacity: null }),
          p_proposal_id: editId,
        }),
      ]);
      check(
        outcomes.every(
          (r) => !r.error || ["PT422", "22023"].includes(r.error.code),
        ),
        "promotion/capacity-clear race has canonical validation outcomes",
      );
      const [state] =
        await db`select p.definition_phase,c.registration_capacity from public.proposals p
        join public.projects c on c.id=p.id where p.id=${editId}`;
      check(
        state.definition_phase !== "defined" ||
          state.registration_capacity !== null,
        "concurrent editing cannot leave Defined with undecided capacity",
      );
    }

    // Real JWT races: either legal lock order is acceptable; never overbook a finite cap.
    for (let round = 0; round < 3; round++) {
      const raceId = await idea(owner);
      const raceLink = await invite(owner, raceId);
      const results = await Promise.all([
        owner.client.rpc("update_own_proposal", {
          ...input(owner, { p_registration_capacity: 1 }),
          p_proposal_id: raceId,
        }),
        member.client.rpc(
          "accept_project_participant_invitation",
          acceptParams(member, raceLink),
        ),
        peer.client.rpc(
          "accept_project_participant_invitation",
          acceptParams(peer, raceLink),
        ),
      ]);
      check(
        results.every(
          (r) => !r.error || ["22023", "PT409"].includes(r.error.code),
        ),
        "capacity/admission race only returns canonical bounded outcomes",
      );
      const [capacity] = await call(
        { client: anonymous },
        "list_public_project_capacity_statuses",
        { p_project_ids: [raceId] },
      );
      check(
        capacity.registration_capacity === null ||
          capacity.capacity_used_count <= capacity.registration_capacity,
        "capacity/admission race preserves finite floor",
      );
      const configured = await idea(owner, {
        ...complete,
        p_registration_capacity: 1,
      });
      const finiteLink = await invite(owner, configured);
      const paramsA = acceptParams(member, finiteLink);
      const finite = await Promise.all([
        member.client.rpc("accept_project_participant_invitation", paramsA),
        peer.client.rpc(
          "accept_project_participant_invitation",
          acceptParams(peer, finiteLink),
        ),
      ]);
      check(
        finite.filter((r) => !r.error).length === 1 &&
          finite.filter((r) => r.error?.code === "PT409").length === 1,
        "finite Idea direct-invite race admits exactly one participant",
      );
      if (!finite[0].error) {
        const retry = await call(
          member,
          "accept_project_participant_invitation",
          paramsA,
        );
        check(
          retry[0].replayed &&
            retry[0].membership_id === finite[0].data[0].membership_id,
          "same action recovers canonical admission receipt",
        );
      }
    }
    const revocationId = await idea(owner);
    const revoked = await invite(owner, revocationId);
    await call(owner, "revoke_project_participant_invitation", {
      p_expected_profile_id: owner.id,
      p_project_id: revocationId,
      p_invitation_id: revoked.invitation_id,
    });
    await denied(
      member,
      "accept_project_participant_invitation",
      acceptParams(member, revoked),
      "PT409",
    );
    for (let round = 0; round < 3; round++) {
      const revokeId = await idea(owner);
      const revokeLink = await invite(owner, revokeId);
      const outcomes = await Promise.all([
        owner.client.rpc("revoke_project_participant_invitation", {
          p_expected_profile_id: owner.id,
          p_project_id: revokeId,
          p_invitation_id: revokeLink.invitation_id,
        }),
        member.client.rpc(
          "accept_project_participant_invitation",
          acceptParams(member, revokeLink),
        ),
      ]);
      check(
        !outcomes[0].error &&
          (!outcomes[1].error || outcomes[1].error.code === "PT409"),
        "revocation/admission race has a legal serialized result",
      );
      await denied(
        peer,
        "accept_project_participant_invitation",
        acceptParams(peer, revokeLink),
        "PT409",
      );
    }
    for (let round = 0; round < 3; round++) {
      const cancelId = await idea(owner, complete);
      const outcomes = await Promise.all([
        owner.client.rpc("promote_proposal_idea", identity(owner, cancelId)),
        owner.client.rpc("cancel_proposal", publication(owner, cancelId)),
      ]);
      check(
        !outcomes[1].error &&
          (!outcomes[0].error || outcomes[0].error.code === "55000"),
        "promotion/cancellation race has a legal serialized result",
      );
      check(
        !(await publicDetail(cancelId)),
        "cancelled Idea/Defined remains absent from public detail",
      );
      await denied(
        member,
        "request_to_join_project",
        {
          p_expected_requester_profile_id: member.id,
          p_project_id: cancelId,
          p_request_message: null,
        },
        "55000",
      );
    }
    console.log(
      `IDEA01A ${checks} real OTP/JWT checks passed: public Idea, normal join/chat, nullable/private fields, field-by-field promotion, roles/trust, history, capacity/invite/cancellation races.`,
    );
  } finally {
    await db.end();
  }
}
