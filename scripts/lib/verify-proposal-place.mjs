import { randomUUID } from "node:crypto";

// Called only by the existing explicitly disposable, loopback-only verifier.
// Authenticated REST and real transaction races; provider results are synthetic.
export async function verifyProposalPlace({
  db,
  owner,
  peer,
  server,
  anonymous,
  rpc,
  denied,
  check,
  selected,
}) {
  const id = randomUUID();
  const config = (
    await db`select * from private.location_search_config where singleton`
  )[0];
  const readArgs = {
    p_expected_profile_id: owner.id,
    p_kind: "one_time",
    p_item: id,
  };
  const read = () =>
    rpc(owner.client, "get_authorized_item_location_v1", readArgs);
  const mutation = (
    revision,
    action,
    receipt = null,
    request = randomUUID(),
  ) => ({
    p_expected_profile_id: owner.id,
    p_item: id,
    p_expected_revision: revision,
    p_request_id: request,
    p_action: action,
    p_receipt: receipt,
  });
  async function issue(revision, label) {
    const reserved = await rpc(server, "reserve_location_search_v1", {
      p_actor: owner.id,
      p_kind: "one_time",
      p_item: id,
      p_revision: revision,
      p_slot: "place",
      p_session: randomUUID(),
      p_query_hash: "e".repeat(64),
    });
    check(reserved.status === "ok", "LOCATION02 metered mixed-slot reserve");
    const result = await rpc(server, "issue_location_selections_v1", {
      p_batch: reserved.batch_id,
      p_places: [{ ...selected, label }],
    });
    check(result.status === "ok", "LOCATION02 service-issued bounded receipt");
    return result.suggestions[0].id;
  }
  try {
    await db`update private.location_search_config set enabled=true,actor_minute=20 where singleton`;
    await db.unsafe(
      "insert into public.proposals(id,creator_profile_id,title,summary,description,country_code,locality,public_location_label,lifecycle_state,published_at,starts_at,ends_at,event_timezone) values($1,$2,'LOCATION02 synthetic Project','Synthetic summary','Synthetic description','IT','Trento','Trento','published',now(),now()+interval '2 days',now()+interval '3 days','Europe/Rome')",
      [id, owner.id],
    );
    await db.unsafe(
      "insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility) values($1,'SECRET synthetic arrival directions','public')",
      [id],
    );
    await db.unsafe(
      "update public.projects set registration_capacity=10 where id=$1",
      [id],
    );
    let current = await read();
    const receipt = await issue(current.revision, "Synthetic exact venue A");
    await rpc(
      owner.client,
      "apply_proposal_place_v1",
      mutation(current.revision, "replace", receipt),
    );
    current = await read();
    check(
      current.exact_is_public === false &&
        current.exact_place.label === "Synthetic exact venue A",
      "LOCATION02 private default survives legacy public visibility",
    );
    const projection = await rpc(anonymous, "get_public_item_location_v1", {
      p_kind: "one_time",
      p_item: id,
    });
    check(
      projection.exact_place === null && projection.public_place === null,
      "LOCATION02 exact-only selection publishes no fabricated broad point",
    );
    await denied(
      peer.client,
      "get_authorized_item_location_v1",
      { ...readArgs, p_expected_profile_id: peer.id },
      "42501",
    );
    await denied(
      peer.client,
      "apply_proposal_place_v1",
      {
        ...mutation(current.revision, "public"),
        p_expected_profile_id: peer.id,
      },
      "42501",
    );
    await denied(
      anonymous,
      "apply_proposal_place_v1",
      mutation(current.revision, "public"),
      "42501",
    );
    const request = randomUUID(),
      args = mutation(current.revision, "public", null, request);
    const retries = await Promise.all([
      rpc(owner.client, "apply_proposal_place_v1", args),
      rpc(owner.client, "apply_proposal_place_v1", args),
    ]);
    check(
      retries[0] === retries[1],
      "LOCATION02 simultaneous duplicate visibility intent commits once",
    );
    check(
      Number(
        (
          await db`select count(*) from private.location_write_receipts where actor=${owner.id} and request_id=${request}`
        )[0].count,
      ) === 1,
      "LOCATION02 exactly one durable visibility receipt",
    );
    const detail = await rpc(anonymous, "get_public_proposal", {
      p_proposal_id: id,
    });
    check(
      detail[0].exact_meeting_text === "Synthetic exact venue A" &&
        !JSON.stringify(detail).includes("SECRET"),
      "LOCATION02 public detail label never contains directions",
    );
    await denied(
      peer.client,
      "get_project_participant_meeting_details",
      { p_expected_profile_id: peer.id, p_project_id: id },
      "42501",
    );
    await rpc(
      owner.client,
      "apply_proposal_place_v1",
      mutation((await read()).revision, "participants"),
    );
    current = await read();
    const replacement = await issue(
      current.revision,
      "Synthetic exact venue B",
    );
    const race = await Promise.all([
      owner.client.rpc(
        "apply_proposal_place_v1",
        mutation(current.revision, "public"),
      ),
      owner.client.rpc(
        "apply_proposal_place_v1",
        mutation(current.revision, "replace", replacement),
      ),
    ]);
    check(
      race.filter((r) => !r.error).length === 1 &&
        race.find((r) => r.error)?.error.code === "40001",
      "LOCATION02 public switch versus new private selection has one winner and one stale intent",
    );
    current = await read();
    check(
      current.exact_place.label === "Synthetic exact venue A"
        ? current.exact_is_public === true
        : current.exact_place.label === "Synthetic exact venue B" &&
            current.exact_is_public === false,
      "LOCATION02 concurrent old switch cannot publicize a newer exact place",
    );
    const oldRevision = current.revision;
    await rpc(
      owner.client,
      "apply_proposal_place_v1",
      mutation(oldRevision, "clear"),
    );
    await denied(
      owner.client,
      "apply_proposal_place_v1",
      mutation(oldRevision, "public"),
      "40001",
    );
    check(
      (await read()).exact_place === null,
      "LOCATION02 stale visibility request cannot resurrect a cleared selection",
    );
    check(
      (
        await rpc(owner.client, "get_project_participant_meeting_details", {
          p_expected_profile_id: owner.id,
          p_project_id: id,
        })
      )[0].exact_meeting_text === "SECRET synthetic arrival directions",
      "LOCATION02 place clear preserves protected directions",
    );
  } finally {
    await db.unsafe(
      "update public.proposals set lifecycle_state='cancelled',cancelled_at=now() where id=$1",
      [id],
    );
    await db`update private.location_search_config set enabled=${config.enabled},actor_minute=${config.actor_minute} where singleton`;
  }
}
