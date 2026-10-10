// Only the canonical public-detail projection may supply this destination.
// Text labels (including legacy directions) never become guessed Maps queries.
export function publicExactMapsUrl(
  value: unknown,
  itemId: string,
  label: string,
): string | null {
  if (value === null) return null;
  if (typeof value !== "object" || Array.isArray(value))
    throw new TypeError("Invalid public location projection");
  const preview = value as Record<string, unknown>;
  if (
    preview.item_kind !== "one_time" ||
    preview.item_id !== itemId ||
    preview.audience !== "public"
  )
    throw new TypeError("Invalid public location scope");
  if (preview.place === null || preview.scope === "area") return null;
  if (
    preview.scope !== "exact" ||
    typeof preview.place !== "object" ||
    Array.isArray(preview.place)
  )
    throw new TypeError("Invalid exact public place");
  const place = preview.place as Record<string, unknown>;
  if (
    !["address", "amenity"].includes(String(place.kind)) ||
    place.label !== label
  )
    return null;
  const { latitude, longitude } = place;
  if (
    typeof latitude !== "number" ||
    !Number.isFinite(latitude) ||
    Math.abs(latitude) > 90 ||
    typeof longitude !== "number" ||
    !Number.isFinite(longitude) ||
    Math.abs(longitude) > 180
  )
    throw new TypeError("Invalid exact public point");
  const url = new URL("https://www.google.com/maps/search/");
  url.searchParams.set("api", "1");
  url.searchParams.set("query", `${latitude},${longitude}`);
  return url.toString();
}
