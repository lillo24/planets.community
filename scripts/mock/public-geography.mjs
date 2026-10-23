// Mock-only, deterministic public reference fixtures. These are not evidence of
// hosted geocoding. Never derive a public point from protected meeting details.
export async function seedPublicReference(context, kind, id) {
  const { sql } = context;
  return sql.begin(async (tx) => {
    await context.guard(tx);
    const place = {
      provider: "geoapify",
      kind: "locality",
      result_type: "city",
      label: "Trento",
      country_code: "IT",
      locality: "Trento",
      latitude: 46.0748,
      longitude: 11.1217,
      source: "openstreetmap",
      attribution: "Powered by Geoapify | © OpenStreetMap contributors",
      source_license: "https://www.openstreetmap.org/copyright",
      verified_at: "2026-10-23T00:00:00Z",
    };
    // Only unchanged original fixture locality fields with no existing point
    // are eligible. The caller records an ordinary once-only fixture receipt;
    // later tester edits/removals are never repaired by a repeat seed.
    let rows;
    if (kind === "project")
      rows =
        await tx`update public.proposals set selected_public_place=${tx.json(place)},
      approximate_location=extensions.st_setsrid(extensions.st_makepoint(11.1217,46.0748),4326)::extensions.geography
      where id=${id}::uuid and creator_profile_id='81000000-0000-4000-8000-000000000001'
      and country_code='IT' and locality='Trento' and public_location_label='Trento · Povo'
      and selected_public_place is null and approximate_location is null returning id`;
    else if (kind === "tavolo")
      rows =
        await tx`update public.recurring_activities set selected_public_place=${tx.json(place)},
      approximate_location=extensions.st_setsrid(extensions.st_makepoint(11.1217,46.0748),4326)::extensions.geography
      where id=${id}::uuid and creator_profile_id='81000000-0000-4000-8000-000000000002'
      and country_code='IT' and locality='Trento' and public_location_label='Trento · Povo'
      and selected_public_place is null and approximate_location is null returning id`;
    else if (kind === "resource")
      rows =
        await tx`update public.resource_listings set selected_public_place=${tx.json(place)},
      public_location=extensions.st_setsrid(extensions.st_makepoint(11.1217,46.0748),4326)::extensions.geography
      where id=${id}::uuid and owner_profile_id='81000000-0000-4000-8000-000000000002'
      and country_code='IT' and locality='Trento' and public_location_label='Trento · Povo'
      and selected_public_place is null and public_location is null returning id`;
    else throw new Error("Unsupported mock public reference kind");
    return { public_reference_added: rows.length === 1 };
  });
}
