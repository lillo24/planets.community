import { ReleaseError } from "./errors.mjs";
import {
  STAGING_REF,
  requiredRpcs,
  requiredEdgeFunctions,
} from "./migrations.mjs";
import { readFileSync } from "node:fs";
import { sha256, sqlFingerprint } from "./sql-fingerprint.mjs";

export const historyQuery =
  "select version, name, statements from supabase_migrations.schema_migrations order by version";

export async function publicSmoke(configJson, fetcher = fetch) {
  let config;
  try {
    config = JSON.parse(configJson);
  } catch {
    throw new ReleaseError(
      "Missing/invalid STAGING_CONFIG_JSON for public HTTP verification",
    );
  }
  if (
    config.SUPABASE_URL !== `https://${STAGING_REF}.supabase.co` ||
    !/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(
      config.SUPABASE_PUBLISHABLE_KEY ?? "",
    )
  )
    throw new ReleaseError(
      "HTTP smoke requires the exact staging origin and client-safe key",
    );
  const checks = [];
  for (const [rpc, args, status, code] of [
    ["list_public_resource_listings", { p_limit: 1 }, 200],
    ["list_public_resource_listings_v2", { p_limit: 1 }, 200],
    [
      "list_public_resource_listings_v2",
      { p_limit: 1, p_category_slug: "release01_invalid_category" },
      400,
      "22023",
    ],
    [
      "get_own_message_unread_summary_with_contacts_and_discussions",
      { p_expected_profile_id: "00000000-0000-0000-0000-000000000000" },
      401,
      "42501",
    ],
  ]) {
    const response = await fetcher(
      `${config.SUPABASE_URL}/rest/v1/rpc/${rpc}`,
      {
        method: "POST",
        headers: {
          apikey: config.SUPABASE_PUBLISHABLE_KEY,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        signal: AbortSignal.timeout(60000),
      },
    );
    const data = await response.json();
    if (
      response.status !== status ||
      (code && data.code !== code) ||
      (!code && !Array.isArray(data))
    )
      throw new ReleaseError(
        `Hosted public/legacy/privacy smoke failed for ${rpc} (HTTP ${response.status})`,
      );
    checks.push({ rpc, status: response.status, ...(code && { code }) });
  }
  return checks; // Never retain returned public rows or provider error details.
}
export function verifyFunctions(root, policy, functions, variant = "staging") {
  if (
    !policy.approved_functions?.length ||
    !Object.keys(policy.approved_function_source_sha256 ?? {}).length
  )
    return false;
  if (
    requiredEdgeFunctions(root, variant).some(
      (name) => !policy.approved_functions.some((f) => f.slug === name),
    )
  )
    return false;
  for (const expected of policy.approved_functions) {
    if (
      !functions.some(
        (f) =>
          f.slug === expected.slug &&
          f.status === "ACTIVE" &&
          f.version === expected.version &&
          f.verify_jwt === expected.verify_jwt &&
          f.ezbr_sha256 === expected.ezbr_sha256,
      )
    )
      return false;
  }
  for (const [path, hash] of Object.entries(
    policy.approved_function_source_sha256,
  )) {
    if (
      !/^(?:map-provider|mock-basemap|location-search|location-preview)\/[a-z-]+\.(?:mjs|ts)$/.test(
        path,
      ) ||
      sha256(readFileSync(`${root}/supabase/functions/${path}`)) !== hash
    )
      return false;
  }
  return true;
}
export function summarizeHistory(rows) {
  return rows.map(({ version, name, statements }) => ({
    version,
    name,
    remote_sha256: sha256(statements.join("\n")),
    fingerprint: sqlFingerprint(statements.join(";\n")),
  }));
}

export function verificationQuery(root, budget) {
  const names = requiredRpcs(root)
    .map((name) => `'${name}'`)
    .join(",");
  return `select
    array(select name from unnest(array[${names}]) as name
      where not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname='public' and p.proname=name)) as missing_rpcs,
    array(select n.nspname||'.'||c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','private') and c.relkind in ('r','p') and not c.relrowsecurity
      and (has_table_privilege('anon',c.oid,'SELECT') or has_table_privilege('authenticated',c.oid,'SELECT'))
      and not exists(select 1 from pg_depend d where d.objid=c.oid and d.deptype='e')) as unsafe_tables,
    (select count(*)=2 and bool_and(not public and allowed_mime_types=array['image/webp']::text[]
      and file_size_limit=case when id='profile-photos' then 256000 else 524288 end)
      from storage.buckets where id in ('profile-photos','cover-images')) as storage_safe,
    (not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname in ('create_resource_listing_draft_v2','update_own_resource_listing_v2',
        'create_resource_saved_search_v2','update_resource_saved_search_v2','list_own_scoped_conversation_items_v7',
        'get_own_message_unread_summary_with_contacts_and_discussions','set_own_profile_photo_v2')
        and (has_function_privilege('anon',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE')))
      and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
        and p.proname='list_public_resource_listings_v2' and has_function_privilege('anon',p.oid,'EXECUTE'))) as grants_safe,
    (exists(select 1 from private.location_provider_config where singleton and enabled and tiles_enabled and center_enabled
      and cache_license_approved and tile_cache_seconds=60 and daily_units_limit between 1 and 8000)
      and exists(select 1 from private.location_search_config where singleton and enabled)
      ${budget ? "and exists(select 1 from private.map_baseline_config where singleton and enabled and license_approved and retention_seconds between 1 and 604800)" : ""}) as map_safe`;
}

export function managementClient(token, fetcher = fetch) {
  if (!token)
    throw new ReleaseError(
      "Missing SUPABASE_ACCESS_TOKEN in planets-staging environment",
    );
  async function request(path, body) {
    const response = await fetcher(
      `https://api.supabase.com/v1/projects/${STAGING_REF}${path}`,
      {
        method: body ? "POST" : "GET",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        ...(body && { body: JSON.stringify(body) }),
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!response.ok)
      throw new ReleaseError(
        `Staging management request ${path} failed (HTTP ${response.status}); inspect provider privately`,
      );
    return response.json();
  }
  return {
    identity: () => request(""),
    query: (query) => request("/database/query", { query, read_only: true }),
    functions: () => request("/functions"),
  };
}
