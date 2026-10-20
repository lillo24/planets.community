import { fetchTile, validateTilePng } from "./provider.mjs";
import { LocationFailure } from "../location-search/provider.mjs";

const encode = (bytes) => {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value);
};
const decode = (value) => {
  if (typeof value !== "string" || value.length > 350000)
    throw new LocationFailure("invalid_image");
  return validateTilePng(
    Uint8Array.from(atob(value.replace(/\s/g, "")), (c) => c.charCodeAt(0)),
  );
};

// v2 keeps source XYZ and immutable expiry beside the bytes. Never label an
// ancestor as a child image. SQL alone decides cache eligibility and charges.
export async function basemapTileV2({ body, actor, key, rpc, fetcher }) {
  const coords = { p_z: body.z, p_x: body.x, p_y: body.y };
  let claim;
  try {
    claim = await rpc("reserve_basemap_tile_v2", {
      p_actor: actor,
      ...coords,
      p_cache_only: body.cache_only,
    });
    if (claim.status !== "ok") return claim;
    if (claim.cached) {
      decode(claim.image_base64);
      return claim;
    }
    // Defense in depth: even a defective reservation response cannot cause
    // cache-only IO to reach Geoapify or schedule a background fill.
    if (body.cache_only || typeof claim.token !== "string")
      throw new LocationFailure("unavailable");
    const bytes = await fetchTile({ tile: body, key, enabled: true, fetcher });
    const finished = await rpc("finish_basemap_tile_v2", {
      ...coords,
      p_token: claim.token,
      p_image_base64: encode(bytes),
    });
    claim = null;
    if (finished.status === "ok") decode(finished.image_base64);
    return finished;
  } catch (error) {
    if (claim?.token && !body.cache_only) {
      try {
        await rpc("finish_basemap_tile_v2", {
          ...coords,
          p_token: claim.token,
        });
      } catch {
        /* Explicit failure below, no stale success. */
      }
    }
    return {
      status: error instanceof LocationFailure ? error.status : "unavailable",
    };
  }
}
