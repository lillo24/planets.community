import { randomUUID } from "node:crypto";
import { createPreviewHandler } from "../../supabase/functions/location-preview/handler.mjs";
import { previewPng } from "./location-preview-fixture.mjs";
// Runs only inside the existing explicitly disposable-stack verifier.
export async function verifyLocationPreviews({
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
  const config = (
    await db.unsafe(
      "select * from private.location_preview_config where singleton",
    )
  )[0];
  const id = randomUUID();
  const area = {
    ...selected,
    kind: "locality",
    result_type: "city",
    label: "Synthetic area",
    latitude: 45,
    longitude: 12,
  };
  try {
    await db.unsafe(
      "insert into public.proposals(id,creator_profile_id,title,summary,description,country_code,locality,public_location_label,lifecycle_state,published_at,starts_at,ends_at,event_timezone,selected_public_place,approximate_location) values($1,$2,'MAP03 synthetic public proposal','Synthetic summary','Synthetic description','IT','Synthetic locality','Synthetic area','published',now(),now()+interval '2 days',now()+interval '3 days','Europe/Rome',$3::jsonb,private.selected_place_point($3::jsonb))",
      [id, owner.id, area],
    );
    await db.unsafe(
      "update public.projects set registration_capacity=10 where id=$1",
      [id],
    );
    await db.unsafe(
      "insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility,selected_exact_place,exact_location) values($1,'SECRET private instructions','participants',$2::jsonb,private.selected_place_point($2::jsonb))",
      [id, selected],
    );
    const args = { p_kind: "one_time", p_item: id, p_view: "card" };
    const card = await rpc(anonymous, "get_location_preview_v1", args);
    check(
      card.scope === "area" &&
        card.place.latitude === 45 &&
        !JSON.stringify(card).includes("SECRET"),
      "MAP03 REST independent public area",
    );
    const protectedArgs = {
      ...args,
      p_view: "protected_detail",
      p_expected_profile_id: owner.id,
    };
    const exact = await rpc(
      owner.client,
      "get_location_preview_v1",
      protectedArgs,
    );
    check(
      exact.scope === "exact" && exact.audience === "protected",
      "MAP03 REST owner entitlement",
    );
    await denied(
      peer.client,
      "get_location_preview_v1",
      { ...protectedArgs, p_expected_profile_id: peer.id },
      "42501",
    );
    await denied(server, "get_location_preview_v1", protectedArgs, "42501");
    const batch = await rpc(anonymous, "get_public_location_previews_v1", {
      p_items: [
        { kind: "one_time", id },
        { kind: "one_time", id },
      ],
    });
    check(
      batch.length === 1 && batch[0].preview.scope === "area",
      "MAP03 REST public batch dedupe",
    );
    await db.unsafe(
      "update public.proposals set selected_public_place=null,approximate_location=null where id=$1",
      [id],
    );
    check(
      (await rpc(anonymous, "get_location_preview_v1", args)).place === null,
      "MAP03 exact-only Project cannot produce public image",
    );
    await db.unsafe(
      "update public.proposals set selected_public_place=$2::jsonb,approximate_location=private.selected_place_point($2::jsonb) where id=$1",
      [id, area],
    );
    await db.unsafe(
      "update private.location_preview_config set enabled=true,cache_license_approved=true,daily_credit_limit=4,account_daily_credit_limit=2000 where singleton",
    );
    await db.unsafe("delete from private.location_preview_usage");
    await db.unsafe("delete from private.location_preview_images");
    const racers = await Promise.all(
      Array.from({ length: 8 }, (_, i) =>
        rpc(server, "reserve_location_preview_v1", {
          p_image_key: String(i).repeat(64),
          p_cacheable: false,
          p_actor: null,
        }),
      ),
    );
    check(
      racers.filter((x) => x.status === "ok").length === 1 &&
        racers.filter((x) => x.status === "budget_exhausted").length === 7,
      "MAP03 atomic cap under eight concurrent requests",
    );
    await db.unsafe(
      "update private.location_preview_config set daily_credit_limit=2000,account_daily_credit_limit=4 where singleton",
    );
    const rev = (
      await db.unsafe(
        "select location_revision from public.proposals where id=$1",
        [id],
      )
    )[0].location_revision;
    check(
      (
        await rpc(server, "reserve_location_search_v1", {
          p_actor: owner.id,
          p_kind: "one_time",
          p_item: id,
          p_revision: Number(rev),
          p_slot: "area",
          p_session: randomUUID(),
          p_query_hash: "e".repeat(64),
        })
      ).status === "budget_exhausted",
      "MAP03 rendering blocks autocomplete at shared ceiling",
    );
    await db.unsafe(
      "update private.location_preview_config set account_daily_credit_limit=2000 where singleton",
    );
    await db.unsafe("delete from private.location_preview_usage");
    let renders = 0;
    const handler = createPreviewHandler({
      enabled: true,
      key: "synthetic-not-a-key",
      authenticate: async (authorization) =>
        authorization === "Bearer synthetic-fixture" ? owner.id : null,
      read: (a, authorization) =>
        rpc(
          authorization ? owner.client : anonymous,
          "get_location_preview_v1",
          a,
        ),
      rpc: (name, a) => rpc(server, name, a),
      fetcher: async () => {
        renders++;
        return new Response(previewPng, {
          headers: { "Content-Type": "image/png" },
        });
      },
    });
    const send = (p, view) =>
      handler(
        new Request("https://local.invalid/location-preview", {
          method: "POST",
          headers: { Authorization: "Bearer synthetic-fixture" },
          body: JSON.stringify({
            item_kind: "one_time",
            item_id: id,
            view,
            expected_profile_id: p.audience === "protected" ? owner.id : null,
            revision: p.revision,
            image_key: p.image_key,
          }),
        }),
      );
    const publicView = await rpc(anonymous, "get_location_preview_v1", args);
    for (let n = 0; n < 2; n++) {
      const response = await send(publicView, "card");
      check(
        response.headers.get("Content-Type") === "application/octet-stream" &&
          (await response.arrayBuffer()).byteLength === previewPng.length,
        "MAP03 canonical REST + fake binary image",
      );
    }
    check(renders === 1, "MAP03 public locality generates once across repeats");
    const protectedView = await rpc(
      owner.client,
      "get_location_preview_v1",
      protectedArgs,
    );
    const response = await send(protectedView, "protected_detail");
    check(
      (await response.arrayBuffer()).byteLength === previewPng.length,
      "MAP03 protected binary transport with real actor REST reads",
    );
    check(
      (
        await db.unsafe(
          "select count(*)::int as total from private.location_preview_images",
        )
      )[0].total === 1,
      "MAP03 protected bytes add no cache record",
    );
    await db.unsafe(
      "update public.proposal_meeting_details set exact_location_visibility='public' where proposal_id=$1",
      [id],
    );
    check(
      (
        await rpc(anonymous, "get_location_preview_v1", {
          ...args,
          p_view: "public_detail",
        })
      ).scope === "exact",
      "MAP03 public exact detail",
    );
    check(
      (await rpc(anonymous, "get_location_preview_v1", args)).scope === "area",
      "MAP03 public exact card remains broad",
    );
    await db.unsafe(
      "update public.proposal_meeting_details set exact_location_visibility='participants' where proposal_id=$1",
      [id],
    );
    check(
      (
        await rpc(anonymous, "get_location_preview_v1", {
          ...args,
          p_view: "public_detail",
        })
      ).scope === "area",
      "MAP03 public precision revoked",
    );
  } finally {
    await db.unsafe(
      "update private.location_preview_config set enabled=$1,cache_license_approved=$2,daily_credit_limit=$3,account_daily_credit_limit=$4 where singleton",
      [
        config.enabled,
        config.cache_license_approved,
        config.daily_credit_limit,
        config.account_daily_credit_limit,
      ],
    );
    await db.unsafe("delete from private.location_preview_images");
    await db.unsafe("delete from private.location_preview_usage");
  }
}
