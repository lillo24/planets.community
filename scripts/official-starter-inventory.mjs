import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Read-only operator tooling: emit reviewed SQL or check anonymous public HTTP.
// This script has no migration, provisioning, reset, upload or mutation mode.
const catalog = JSON.parse(
  readFileSync(
    new URL(
      "../supabase/catalog/official-starter-templates.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const mode = process.argv[2];
if (mode === "--preflight-sql") {
  console.log(`begin read only;
select (select count(*) from public.proposals) as proposals,
       (select count(*) from public.profiles) as profiles,
       (select count(*) from private.proposal_templates) as templates,
       to_regclass('private.official_starter_template_content') as official_catalog;
select version from supabase_migrations.schema_migrations order by version;
commit;`);
} else if (mode === "--catalog-sql") {
  const values = catalog
    .map(
      (t) =>
        `('${t.template_id}'::uuid,'${t.key}',$ost01$${JSON.stringify(t.content)}$ost01$::jsonb)`,
    )
    .join(",\n");
  console.log(`begin read only;
with expected(id,key,content) as (values ${values})
select e.key,e.id,t.starter_key,t.removed_at,
  case when t.id is null then 'MISSING'
       when t.template_kind <> 'official_starter' or t.starter_key <> e.key then 'IDENTITY_DRIFT'
       when c.content is distinct from e.content then 'CONTENT_DRIFT'
       when t.removed_at is not null then 'RETIRED'
       else 'MATCH' end as status,
  private.proposal_template_content_version(c.content) as raw_content_hash
from expected e left join private.proposal_templates t on t.id=e.id
left join private.official_starter_template_content c on c.template_id=t.id order by e.key;
select (select count(*) from public.proposals) as proposals,
       (select count(*) from public.profiles) as profiles;
set local role anon;
select template_id,title,is_official,creator_display_name,source_proposal_id,
       original_creator_profile_id,cover_asset_key
from public.list_public_proposal_templates_v2(p_limit=>50) where is_official;
commit;`);
} else if (mode === "--readback") {
  const apiUrl = process.env.PLANETS_STARTER_API_URL;
  const key = process.env.PLANETS_STARTER_PUBLISHABLE_KEY;
  assert.ok(
    apiUrl && key,
    "Set PLANETS_STARTER_API_URL and PLANETS_STARTER_PUBLISHABLE_KEY.",
  );
  const target = new URL(apiUrl);
  assert.ok(
    target.protocol === "https:" ||
      ["localhost", "127.0.0.1", "[::1]"].includes(target.hostname),
    "Remote readback requires HTTPS.",
  );
  const official = [];
  let cursor = {};
  for (let page = 0; page < 1000; page++) {
    const response = await fetch(
      new URL("/rest/v1/rpc/list_public_proposal_templates_v2", target),
      {
        method: "POST",
        headers: { apikey: key, "Content-Type": "application/json" },
        body: JSON.stringify({ p_limit: 50, ...cursor }),
      },
    );
    if (!response.ok)
      throw new Error(
        `Official catalog readback failed: HTTP ${response.status}. Check migration deployment and API schema reload.`,
      );
    const rows = await response.json();
    assert.ok(Array.isArray(rows), "Public Workshop RPC must return rows.");
    official.push(...rows.filter((r) => r.is_official === true));
    if (official.length >= 8 || rows.length < 50) break;
    const last = rows.at(-1);
    cursor = {
      p_cursor_linked_at: last.linked_at,
      p_cursor_id: last.template_id,
    };
  }
  assert.equal(
    official.length,
    8,
    "Expected eight visible official templates through Workshop pagination.",
  );
  for (const expected of catalog) {
    const row = official.find((r) => r.template_id === expected.template_id);
    assert.ok(row, `Missing official template: ${expected.key}`);
    assert.equal(row.title, expected.content.title);
    assert.equal(row.creator_display_name, "Planets Community Official");
    assert.equal(row.source_proposal_id, null);
    assert.equal(row.original_creator_profile_id, null);
  }
  console.log(
    `Verified eight official examples through anonymous public RPC at ${target.origin}.`,
  );
} else {
  throw new Error(
    "Choose --preflight-sql, --catalog-sql, or --readback; all modes are read-only.",
  );
}
