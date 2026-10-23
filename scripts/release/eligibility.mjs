import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { ReleaseError } from "./errors.mjs";
import { sha256, sqlTokens } from "./sql-fingerprint.mjs";
import { classifyMigration, inventoryDigest } from "./safety.mjs";
import { STAGING_REF } from "./migrations.mjs";

// The policy-only PR is reviewed against this already-merged product baseline.
// Its SQL still needs populated replay, independent security tests and observed
// catalog effects. This is not authorization to apply arbitrary merged SQL.
export const TRUSTED_PRODUCT_BASE = "ec4c57060331b96577d512794b8c5bd78ac16d2b";
export const POLICY_VERSION = 2;
export class UnsafeCatalogError extends ReleaseError {}
export const policyModuleHash = () =>
  sha256(readFileSync(fileURLToPath(import.meta.url)));
export const policyPath = (path) =>
  /^(scripts\/release\/.*\.(?:mjs|json|crt)$|\.github\/workflows\/(?:validation|staging-release)\.yml$|package(?:-lock)?\.json$|docs\/development\/evidence\/release01\/)/.test(
    path,
  ) && !/\.(?:md|mdx)$/.test(path);
export function assertPolicySeparation(paths) {
  if (
    paths.some((p) => /^supabase\/migrations\/.*\.sql$/.test(p)) &&
    paths.some(policyPath)
  )
    throw new ReleaseError(
      "Policy/validator/dependency changes and product SQL require separate PRs against a trusted pre-change base",
    );
}

export function statements(sql) {
  const result = [];
  let current = [];
  for (const token of sqlTokens(sql)) {
    if (token === ";") {
      if (current.length) result.push(current);
      current = [];
    } else current.push(token);
  }
  if (current.length) result.push(current);
  if (!result.length)
    throw new ReleaseError("Empty migration cannot be rehearsed");
  return result;
}
const names = new Set([
  "private.reserve_mock_map_provider_v1",
  "private.reserve_basemap_tile_internal_v3",
  "public.reserve_basemap_tile_v2",
  "public.reserve_mock_basemap_tile_v1",
  "public.finish_mock_basemap_tile_v1",
]);
const word = /^[a-z_][a-z0-9_]*$/;
const qualified = (s, at) =>
  word.test(s[at] ?? "") && s[at + 1] === "." && word.test(s[at + 2] ?? "")
    ? s.slice(at, at + 3).join("")
    : null;
export function inspectAdditive(sql) {
  let parsed;
  try {
    parsed = statements(sql).map((s) => s.map((t) => t.toLowerCase()));
  } catch {
    return {
      classification: "blocked-unsafe",
      reason: "Unparseable SQL",
      tables: [],
      functions: [],
    };
  }
  const tables = [],
    functions = [];
  const hold = (reason) => ({
    classification: "review-required-for-hosted",
    reason,
    tables,
    functions,
  });
  for (const s of parsed) {
    if (
      ["drop", "truncate"].includes(s[0]) ||
      (s[0] === "alter" && s[1] === "table" && s.includes("drop")) ||
      (s[0] === "alter" &&
        ["role", "user", "system", "database"].includes(s[1]))
    )
      return {
        classification: "blocked-unsafe",
        reason: "Destructive or role/system DDL",
        tables,
        functions,
      };
    if (s[0] === "create" && s[1] === "table") {
      const name = qualified(s, 2);
      if (
        !name?.startsWith("private.") ||
        s[5] !== "(" ||
        s.some((t) =>
          ["inherits", "partition", "like", "tablespace"].includes(t),
        )
      )
        return hold(
          "Only isolated new private regular tables are automatic candidates",
        );
      tables.push(name);
    } else if (
      s[0] === "create" &&
      (s[1] === "function" || s.slice(1, 4).join(" ") === "or replace function")
    ) {
      const at = s[1] === "function" ? 2 : 4;
      const name = qualified(s, at);
      if (
        !name ||
        !["public", "private"].includes(s[at]) ||
        !s.some(
          (t, i) =>
            t === "search_path" && s[i + 1] === "=" && s[i + 2] === "''",
        )
      )
        return hold("Privileged functions require an empty secure search path");
      const body = s.find((t) => /^\$(?:[a-z_][a-z0-9_]*)?\$/.test(t));
      if (
        !body ||
        /\b(?:execute|dblink|lo_import|pg_read_file|copy|alter\s+role)\b/.test(
          body,
        )
      )
        return hold(
          "Dynamic or external privileged effects need a targeted contract",
        );
      functions.push(name);
    } else if (s[0] === "alter" && s[1] === "table") {
      if (
        !tables.includes(qualified(s, 2)) ||
        s.slice(5).join(" ") !== "enable row level security"
      )
        return hold(
          "Existing table or RLS changes need an established contract",
        );
    } else if (s[0] === "create" && ["index", "unique"].includes(s[1])) {
      const on = s.indexOf("on");
      if (!tables.includes(qualified(s, on + 1)))
        return hold("Index must belong to a declared new private table");
    } else if (s[0] === "revoke") {
      if (
        s[1] !== "all" ||
        !s.includes("from") ||
        s
          .slice(s.indexOf("from") + 1)
          .some(
            (t) =>
              ![
                ",",
                "public",
                "anon",
                "authenticated",
                "service_role",
              ].includes(t),
          )
      )
        return hold("Unknown privilege revocation");
    } else if (s[0] === "grant") {
      if (
        s.slice(0, 4).join(" ") !== "grant execute on function" ||
        s.slice(s.lastIndexOf("to") + 1).join(" ") !== "service_role"
      )
        return hold(
          "New direct client grants are outside the private/service-only class",
        );
    } else if (s[0] === "insert") {
      if (
        !tables.includes(qualified(s, 2)) ||
        !s.includes("values") ||
        s.includes("select") ||
        s.includes("conflict")
      )
        return hold(
          "Only initial values in a new isolated private table are candidates",
        );
    } else if (
      ["set", "reset"].includes(s[0]) &&
      ["lock_timeout", "statement_timeout"].includes(s[1])
    ) {
      if (s[0] === "set" && !["'5s'", "'60s'"].includes(s[3]))
        return hold("Unbounded migration timeout");
    } else
      return hold("Unsupported SQL effects require targeted hosted evidence");
  }
  if (!tables.length && !functions.length)
    return hold("No bounded additive effects");
  const map =
    functions.length &&
    functions.every((n) => names.has(n)) &&
    tables.every((n) =>
      ["private.mock_basemap_config", "private.mock_basemap_claims"].includes(
        n,
      ),
    );
  if (functions.length && !map)
    return hold(
      "Service function bodies need an independently installed security contract",
    );
  return {
    classification: map
      ? "mock-basemap-contract-candidate"
      : "private-additive-candidate",
    reason:
      "Requires actual catalog, role denials, populated rows and independent contract proof",
    tables,
    functions,
  };
}
export function migrationCandidate(migration, root = process.cwd()) {
  try {
    const old = execFileSync(
      "git",
      ["show", `${TRUSTED_PRODUCT_BASE}:supabase/migrations/${migration.file}`],
      { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    );
    if (sha256(old) === migration.sha256)
      return {
        classification: "established-contract-candidate",
        reason:
          "Exact trusted product baseline; effects and independent security witnesses still required",
      };
  } catch {
    /* A new migration must satisfy the bounded policy below. */
  }
  const routine = classifyMigration(migration.sql);
  return routine.classification === "routine-candidate"
    ? routine
    : inspectAdditive(migration.sql);
}

// Stable identities and effective role privileges, plus OIDs to prove in-place
// replacement. Raw bodies, user rows and credentials never enter the receipt.
export const effectCatalogQuery = `select jsonb_build_object(
 'tables',(select coalesce(jsonb_agg(x order by x->>'id'),'[]') from (
  select jsonb_build_object('id',n.nspname||'.'||c.relname,'kind',c.relkind,'owner',pg_get_userbyid(c.relowner),
   'rls',c.relrowsecurity,'forced',c.relforcerowsecurity,
   'access',(select jsonb_object_agg(r.rolname,(select jsonb_object_agg(privilege,has_table_privilege(r.oid,c.oid,privilege)) from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) privilege)) from pg_roles r where r.rolname in ('anon','authenticated','service_role')),
   'columns',(select coalesce(jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated,'acl',coalesce(a.attacl::text,'')) order by a.attnum),'[]') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped)) x
  from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p')) q),
 'functions',(select coalesce(jsonb_agg(x order by x->>'id'),'[]') from (
  select jsonb_build_object('id',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')','oid',p.oid,'owner',pg_get_userbyid(p.proowner),
   'returns',pg_get_function_result(p.oid),'arguments',pg_get_function_arguments(p.oid),'input_names',coalesce(p.proargnames[1:p.pronargs],array[]::text[]),'definer',p.prosecdef,'config',p.proconfig,
   'volatility',p.provolatile,'parallel',p.proparallel,'strict',p.proisstrict,'leakproof',p.proleakproof,
   'body',md5(pg_get_functiondef(p.oid)),'source_body',md5(p.prosrc),
   'acl',(select coalesce(jsonb_agg(item order by item::text),'[]') from (
     select jsonb_build_object('grantee',case when grantee=0 then 'PUBLIC' else pg_get_userbyid(grantee) end,
       'grantor',pg_get_userbyid(grantor),'privilege',privilege_type,'grantable',is_grantable) item
     from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))) a),
   'access',(select jsonb_object_agg(r.rolname,has_function_privilege(r.oid,p.oid,'execute')) from pg_roles r where r.rolname in ('anon','authenticated','service_role'))) x
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private','auth','storage') and p.prokind in ('f','p')) q),
 'policies',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||p.polname,'definition',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),'command',p.polcmd,'permissive',p.polpermissive,'roles',(select array_agg(coalesce(r.rolname,'PUBLIC') order by r.rolname) from unnest(p.polroles) a left join pg_roles r on r.oid=a)) order by n.nspname,c.relname,p.polname),'[]') from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace),
 'triggers',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||t.tgname,'definition',pg_get_triggerdef(t.oid),'enabled',t.tgenabled) order by n.nspname,c.relname,t.tgname),'[]') from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal),
 'constraints',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||t.conname,'definition',pg_get_constraintdef(t.oid)) order by n.nspname,c.relname,t.conname),'[]') from pg_constraint t join pg_class c on c.oid=t.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage')),
 'indexes',(select coalesce(jsonb_agg(jsonb_build_object('id',schemaname||'.'||indexname,'definition',indexdef) order by schemaname,indexname),'[]') from pg_indexes where schemaname in ('public','private','auth','storage')),
 'views',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname,'definition',pg_get_viewdef(c.oid,true),'acl',coalesce(c.relacl::text,'')) order by n.nspname,c.relname),'[]') from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('v','m') and n.nspname in ('public','private','auth','storage'))
) as catalog`;
const normalized = (value) => {
  const copy = structuredClone(value);
  if (copy && typeof copy === "object") delete copy.oid;
  return copy;
};
export function catalogEffects(before, after) {
  const changes = [];
  for (const section of Object.keys(before).sort()) {
    const prior = new Map(before[section].map((v) => [v.id, v]));
    const next = new Map(after[section].map((v) => [v.id, v]));
    for (const id of [...new Set([...prior.keys(), ...next.keys()])].sort()) {
      const a = prior.get(id),
        b = next.get(id);
      if (JSON.stringify(normalized(a)) !== JSON.stringify(normalized(b))) {
        changes.push({
          section,
          id,
          before: a ? sha256(JSON.stringify(normalized(a))) : null,
          after: b ? sha256(JSON.stringify(normalized(b))) : null,
          ...(section === "functions" && a && b
            ? { oid_retained: a.oid === b.oid }
            : {}),
        });
      }
    }
  }
  return changes;
}
export function assertBoundedCatalog(before, after, candidate) {
  const changes = catalogEffects(before, after);
  const sameContext = (a, b) =>
    [
      "owner",
      "returns",
      "arguments",
      "acl",
      "definer",
      "config",
      "volatility",
      "parallel",
      "strict",
      "leakproof",
      "access",
    ].every((key) => JSON.stringify(a[key]) === JSON.stringify(b[key]));
  for (const section of [
    "tables",
    "functions",
    "policies",
    "views",
    "constraints",
    "indexes",
    "triggers",
  ]) {
    for (const a of before[section]) {
      const b = after[section].find((v) => v.id === a.id);
      if (!b)
        throw new UnsafeCatalogError(
          `Existing ${section} contract removed: ${a.id}`,
        );
      if (section === "tables") {
        if (a.owner !== b.owner)
          throw new UnsafeCatalogError(`Existing table owner changed: ${a.id}`);
        for (const column of a.columns)
          if (
            JSON.stringify(b.columns.find((v) => v.name === column.name)) !==
            JSON.stringify(column)
          )
            throw new UnsafeCatalogError(
              `Existing column contract changed: ${a.id}.${column.name}`,
            );
        if ((a.rls && !b.rls) || (a.forced && !b.forced))
          throw new UnsafeCatalogError(`RLS weakened: ${a.id}`);
        for (const role of ["anon", "authenticated", "service_role"])
          for (const privilege of Object.keys(b.access[role]))
            if (!a.access[role][privilege] && b.access[role][privilege])
              throw new UnsafeCatalogError(
                `Existing table grant widened: ${a.id}/${role}/${privilege}`,
              );
      }
      if (section === "functions") {
        // FILL01's exact already-merged private delegation retains the original
        // object/body and old public contracts. It is not a general OID waiver.
        const delegate =
          candidate.classification === "established-contract-candidate" &&
          a.id === "private.cocreate_recruitment_projection(p_id uuid)" &&
          after.functions.find(
            (f) =>
              f.id ===
                "private.cocreate_recruitment_before_meetings(p_id uuid)" &&
              f.oid === a.oid &&
              f.source_body === a.source_body &&
              sameContext(a, f),
          );
        if (!sameContext(a, b) || (a.oid !== b.oid && !delegate))
          throw new ReleaseError(
            `Existing function identity/ACL/context changed: ${a.id}`,
          );
      }
    }
  }
  for (const table of after.tables.filter(
    (t) => !before.tables.some((p) => p.id === t.id),
  )) {
    if (!table.rls || !["postgres", "supabase_admin"].includes(table.owner))
      throw new ReleaseError(`New table lacks safe RLS/owner: ${table.id}`);
    if (
      candidate.classification !== "established-contract-candidate" &&
      (!table.id.startsWith("private.") ||
        table.columns.some((c) => Boolean(c.acl)) ||
        Object.values(table.access).some((privileges) =>
          Object.values(privileges).some(Boolean),
        ))
    )
      throw new ReleaseError(
        `New table exposes direct client privileges: ${table.id}`,
      );
  }
  if (candidate.classification !== "established-contract-candidate") {
    if (
      changes.some((c) => ["policies", "triggers", "views"].includes(c.section))
    )
      throw new ReleaseError("Undeclared policy/trigger/view change");
    for (const fn of after.functions.filter(
      (f) => !before.functions.some((p) => p.id === f.id),
    )) {
      if (
        fn.access.anon ||
        fn.access.authenticated ||
        !["postgres", "supabase_admin"].includes(fn.owner) ||
        (fn.definer && !fn.config?.includes('search_path=""'))
      )
        throw new ReleaseError(
          `New function has unsafe grants/context: ${fn.id}`,
        );
    }
  }
  return changes;
}

export function authorizeVerifiedPending(diff, local, evidence, source, tree) {
  if (diff.project_ref !== STAGING_REF)
    throw new ReleaseError("Standing migration policy is staging-only");
  if (diff.drift.length)
    throw new ReleaseError("Canonical/remote SQL drift blocks staging");
  if (!diff.pending.length) return [];
  if (
    evidence?.policy_version !== POLICY_VERSION ||
    evidence.project_ref !== STAGING_REF ||
    evidence.source_sha !== source ||
    evidence.source_tree !== tree ||
    evidence.policy_module_sha256 !== policyModuleHash() ||
    evidence.inventory_sha256 !== inventoryDigest(local) ||
    !evidence.no_op_retry ||
    !evidence.resource_auth_rest ||
    !evidence.generated_types ||
    !evidence.trusted_security_tests ||
    !evidence.real_actor_denials ||
    !evidence.storage_objects_preserved ||
    !evidence.policy_negative_probes ||
    !evidence.single_writer_probe ||
    !Array.isArray(evidence.migration_safety)
  )
    throw new ReleaseError(
      "Missing/stale independently verified staging receipt",
    );
  const applied = local.filter(
    (m) => !diff.pending.some((p) => p.version === m.version),
  );
  const decisions = [];
  for (const pending of diff.pending) {
    const m = local.find((v) => v.version === pending.version);
    const w = evidence.migration_safety.find(
      (v) => v.version === pending.version,
    );
    if (
      !m ||
      sha256(m.sql) !== m.sha256 ||
      pending.sha256 !== m.sha256 ||
      w?.sha256 !== m.sha256 ||
      w.predecessor_inventory_sha256 !== inventoryDigest(applied) ||
      !w.preserved_rows ||
      !w.catalog_verified ||
      !w.independent_contracts ||
      w.status !== "auto-eligible-for-staging" ||
      !Array.isArray(w.catalog_effects) ||
      w.effect_sha256 !== sha256(JSON.stringify(w.catalog_effects))
    )
      throw new ReleaseError(
        `Migration ${pending.version} withheld: ${w?.reason ?? "missing or stale security/population witness"}`,
      );
    decisions.push({
      version: m.version,
      sha256: m.sha256,
      predecessor_inventory_sha256: w.predecessor_inventory_sha256,
      authorization: "standing-verified-policy",
      historical: pending.historical,
      effect_sha256: w.effect_sha256,
    });
    applied.push(m);
  }
  return decisions;
}
