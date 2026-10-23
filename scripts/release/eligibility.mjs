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

// Defaults/index expressions may use only side-effect-free built-ins. Cross-table
// references and unknown functions need a separately installed contract.
const pureCalls = new Set([
  "gen_random_uuid",
  "clock_timestamp",
  "statement_timestamp",
  "now",
  "coalesce",
  "nullif",
  "greatest",
  "least",
  "length",
  "char_length",
  "octet_length",
  "lower",
  "upper",
  "md5",
  "encode",
  "decode",
  "extensions.digest",
  "extensions.gen_random_uuid",
]);
const grammarCalls = new Set([
  "check",
  "key",
  "unique",
  "include",
  "exists",
  "if",
  "conflict",
  "values",
  "count",
  "ceil",
  "extract",
  "date_trunc",
  "jsonb_build_object",
  "make_interval",
  "power",
]);
function callsAreBounded(tokens, calls) {
  const operators = new Set([
    "+",
    "-",
    "*",
    "/",
    "%",
    "<",
    "<=",
    ">",
    ">=",
    "=",
    "<>",
    "!=",
    "||",
    "~",
    "!~",
    "~*",
    "!~*",
    "::",
  ]);
  for (let i = 0; i < tokens.length - 1; i++)
    if (word.test(tokens[i]) && tokens[i + 1] === "(") {
      const name =
        tokens[i - 1] === "." ? tokens[i - 2] + "." + tokens[i] : tokens[i];
      if (!calls.has(name)) return false;
    }
  for (const token of tokens)
    if (
      /^[+*/<>=~!@#%^&|?:-]+$/.test(token) &&
      !operators.has(token) &&
      ![":=", "=>", "->", "->>"].includes(token)
    )
      return false;
  return true;
}
const basemapRelations = new Set([
  "private.location_search_config",
  "private.location_provider_config",
  "private.map_baseline_config",
  "private.mock_basemap_config",
  "private.location_provider_usage",
  "private.map_provider_cache",
  "private.map_baseline_tiles",
  "private.mock_basemap_claims",
]);
const mapEffects = new Map([
  [
    "private.reserve_mock_map_provider_v1",
    {
      calls: [],
      insert: ["private.location_provider_usage"],
      delete: [
        "private.mock_basemap_claims",
        "private.location_provider_usage",
      ],
    },
  ],
  [
    "private.reserve_basemap_tile_internal_v3",
    {
      calls: [
        "private.reserve_location_provider_v1",
        "private.reserve_mock_map_provider_v1",
        "private.basemap_retry_v2",
        "private.basemap_ancestor_v2",
        "private.is_trento_baseline_v2",
        "private.basemap_tile_payload_v2",
      ],
      insert: ["private.map_baseline_tiles", "private.map_provider_cache"],
      delete: ["private.map_baseline_tiles", "private.map_provider_cache"],
    },
  ],
  [
    "public.reserve_basemap_tile_v2",
    {
      calls: ["private.reserve_basemap_tile_internal_v3"],
      insert: [],
      delete: [],
    },
  ],
  [
    "public.reserve_mock_basemap_tile_v1",
    {
      calls: ["private.reserve_basemap_tile_internal_v3"],
      insert: ["private.mock_basemap_claims"],
      delete: [],
    },
  ],
  [
    "public.finish_mock_basemap_tile_v1",
    {
      calls: ["public.finish_basemap_tile_v2"],
      insert: [],
      delete: ["private.mock_basemap_claims"],
    },
  ],
]);
function boundedMapBody(body, name) {
  const delimiter = body.match(/^\$(?:[a-z_][a-z0-9_]*)?\$/i)?.[0];
  if (!delimiter) return false;
  const tokens = sqlTokens(body.slice(delimiter.length, -delimiter.length)).map(
    (t) => t.toLowerCase(),
  );
  if (name === "private.reserve_basemap_tile_internal_v3") {
    // The existing normal actor check may inspect only existence of its own
    // profile ID. No profile field/projection becomes a mock pixel dependency.
    const probe = sqlTokens("select 1 from public.profiles where id=p_actor");
    const positions = [];
    for (let i = 0; i < tokens.length; i++)
      if (probe.every((t, j) => tokens[i + j] === t)) positions.push(i);
    if (positions.length !== 1) return false;
    tokens.splice(positions[0], probe.length, "select", "1");
  }
  const effects = mapEffects.get(name);
  const calls = new Set([
    ...pureCalls,
    ...grammarCalls,
    ...effects.calls,
    ...basemapRelations,
  ]);
  if (!callsAreBounded(tokens, calls)) return false;
  const aliases = new Set([
    "cfg",
    "mock",
    "baseline",
    "tile",
    "cached",
    "excluded",
    "c",
    "t",
  ]);
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const ref = qualified(tokens, i);
    if (
      ref &&
      tokens[i - 1] !== "." &&
      !basemapRelations.has(ref) &&
      !calls.has(ref) &&
      !aliases.has(tokens[i])
    )
      return false;
    if (
      token === "delete" &&
      qualified(tokens, i + 2) === "private.location_provider_usage"
    ) {
      const end = tokens.indexOf(";", i);
      if (
        tokens.slice(i, end < 0 ? tokens.length : end).join(" ") !==
        "delete from private . location_provider_usage where bucket < day"
      )
        return false;
    }
    if (
      [
        "drop",
        "truncate",
        "alter",
        "create",
        "copy",
        "execute",
        "grant",
        "revoke",
        "call",
        "merge",
        "reset",
        "listen",
        "notify",
        "unlisten",
      ].includes(token)
    )
      return false;
    if (token === "set" && tokens[i - 1] !== "update") return false;
    if (
      token === "insert" &&
      (tokens[i + 1] !== "into" ||
        !effects.insert.includes(qualified(tokens, i + 2)))
    )
      return false;
    if (
      token === "delete" &&
      (tokens[i + 1] !== "from" ||
        !effects.delete.includes(qualified(tokens, i + 2)))
    )
      return false;
    if (
      token === "update" &&
      tokens[i - 1] !== "for" &&
      !(tokens[i - 1] === "do" && tokens[i + 1] === "set")
    )
      return false;
    if (
      ["from", "join"].includes(token) &&
      !(
        token === "from" &&
        tokens[i - 1] === "epoch" &&
        tokens[i - 2] === "(" &&
        tokens[i - 3] === "extract"
      )
    ) {
      const relation = qualified(tokens, i + 1);
      if (relation && !basemapRelations.has(relation)) return false;
    }
  }
  return true;
}
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
          [
            "inherits",
            "partition",
            "like",
            "tablespace",
            "references",
            "generated",
            "collate",
            "using",
          ].includes(t),
        )
      )
        return hold(
          "Only isolated new private regular tables are automatic candidates",
        );
      if (
        !callsAreBounded(s.slice(6), new Set([...pureCalls, ...grammarCalls]))
      )
        return hold(
          "New private table defaults/constraints contain an unproven function effect",
        );
      tables.push(name);
    } else if (
      s[0] === "create" &&
      (s[1] === "function" || s.slice(1, 4).join(" ") === "or replace function")
    ) {
      const at = s[1] === "function" ? 2 : 4;
      const name = qualified(s, at);
      if (!["sql", "plpgsql"].includes(s[s.indexOf("language") + 1]))
        return hold(
          "Only parsed SQL/PLpgSQL bodies are supported by this additive class",
        );
      if (mapEffects.has(name)) {
        const open = at + 3;
        const close = s.indexOf(")", open + 1);
        const groups = [[]];
        for (const t of s.slice(open + 1, close))
          if (t === ",") groups.push([]);
          else groups.at(-1).push(t);
        const types = new Set([
          "uuid",
          "text",
          "boolean",
          "integer",
          "bigint",
          "smallint",
          "jsonb",
          "timestamptz",
          "date",
        ]);
        const literal = (t) =>
          ["null", "true", "false"].includes(t) ||
          /^\d+$/.test(t ?? "") ||
          /^'(?:[^']|'')*'$/.test(t ?? "");
        if (
          s[open] !== "(" ||
          close < 0 ||
          !["text", "jsonb"].includes(s[s.indexOf("returns") + 1]) ||
          groups.some(
            (g) =>
              g.length &&
              (!word.test(g[0]) ||
                !types.has(g[1]) ||
                !(
                  g.length === 2 ||
                  (g.length === 4 &&
                    ["default", "="].includes(g[2]) &&
                    literal(g[3]))
                )),
          )
        )
          return hold(
            "Basemap signatures require built-in inputs and literal defaults",
          );
      }
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
      if (mapEffects.has(name) && !boundedMapBody(body, name))
        return hold(
          "Basemap body exceeds its predeclared relation/call/write effects",
        );
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
      if (
        !callsAreBounded(
          s.slice(on + 5),
          new Set([...pureCalls, ...grammarCalls]),
        )
      )
        return hold(
          "New index expression contains an unproven function effect",
        );
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
      if (
        !s
          .slice(s.indexOf("values") + 1)
          .every(
            (t) =>
              [
                "(",
                ")",
                ",",
                "-",
                "+",
                "true",
                "false",
                "null",
                "default",
              ].includes(t) ||
              /^\d+(?:\.\d+)?$/.test(t) ||
              /^'(?:[^']|'')*'$/.test(t),
          )
      )
        return hold(
          "Initial private values must be literal; unproven expressions are held",
        );
    } else if (
      ["set", "reset"].includes(s[0]) &&
      ["lock_timeout", "statement_timeout"].includes(s[1])
    ) {
      if (
        s[0] === "set" &&
        s[3] !== (s[1] === "lock_timeout" ? "'5s'" : "'60s'")
      )
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
   'extension_owned',exists(select 1 from pg_depend e where e.classid='pg_class'::regclass and e.objid=c.oid and e.deptype='e'),
   'expressions_safe',not exists(
    select 1 from (
      select 'pg_attrdef'::regclass classid,d.oid from pg_attrdef d where d.adrelid=c.oid
      union all select 'pg_constraint'::regclass,k.oid from pg_constraint k where k.conrelid=c.oid
      union all select 'pg_class'::regclass,i.indexrelid from pg_index i where i.indrelid=c.oid
    ) expression join pg_depend dep on dep.classid=expression.classid and dep.objid=expression.oid
    left join pg_proc f on dep.refclassid='pg_proc'::regclass and dep.refobjid=f.oid
    left join pg_operator o on dep.refclassid='pg_operator'::regclass and dep.refobjid=o.oid
    left join pg_opclass op on dep.refclassid='pg_opclass'::regclass and dep.refobjid=op.oid
    where (f.oid is not null and f.pronamespace<>'pg_catalog'::regnamespace and not
      (f.pronamespace='extensions'::regnamespace and f.proname in ('digest','gen_random_uuid')
       and exists(select 1 from pg_depend e where e.classid='pg_proc'::regclass and e.objid=f.oid and e.deptype='e')))
      or (o.oid is not null and o.oprnamespace<>'pg_catalog'::regnamespace)
      or (op.oid is not null and op.opcnamespace<>'pg_catalog'::regnamespace)),
   'rls',c.relrowsecurity,'forced',c.relforcerowsecurity,
   'access',(select jsonb_object_agg(r.rolname,(select jsonb_object_agg(privilege,has_table_privilege(r.oid,c.oid,privilege)) from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) privilege)) from pg_roles r where r.rolname in ('anon','authenticated','service_role')),
   'columns',(select coalesce(jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated,'acl',coalesce(a.attacl::text,'')) order by a.attnum),'[]') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped)) x
  from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p')) q),
 'functions',(select coalesce(jsonb_agg(x order by x->>'id'),'[]') from (
  select jsonb_build_object('id',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')','oid',p.oid,'owner',pg_get_userbyid(p.proowner),
   'extension_owned',exists(select 1 from pg_depend e where e.classid='pg_proc'::regclass and e.objid=p.oid and e.deptype='e'),
   'returns',pg_get_function_result(p.oid),'arguments',pg_get_function_arguments(p.oid),'input_names',coalesce(p.proargnames[1:p.pronargs],array[]::text[]),'definer',p.prosecdef,'config',p.proconfig,
   'volatility',p.provolatile,'parallel',p.proparallel,'strict',p.proisstrict,'leakproof',p.proleakproof,
   'language',(select lanname from pg_language where oid=p.prolang),'binary',p.probin,'postgres_execute',has_function_privilege('postgres',p.oid,'execute'),
   'body',md5(pg_get_functiondef(p.oid)),'source_body',md5(p.prosrc),
   'acl',(select coalesce(jsonb_agg(item order by item::text),'[]') from (
     select jsonb_build_object('grantee',case when grantee=0 then 'PUBLIC' else pg_get_userbyid(grantee) end,
       'grantor',pg_get_userbyid(grantor),'privilege',privilege_type,'grantable',is_grantable) item
     from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))) a),
   'access',(select jsonb_object_agg(r.rolname,has_function_privilege(r.oid,p.oid,'execute')) from pg_roles r where r.rolname in ('anon','authenticated','service_role'))) x
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname in ('public','private','auth','storage') or (n.nspname='extensions' and p.proname in ('digest','gen_random_uuid'))) and p.prokind in ('f','p')) q),
 'policies',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||p.polname,'definition',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),'command',p.polcmd,'permissive',p.polpermissive,'roles',(select array_agg(coalesce(r.rolname,'PUBLIC') order by r.rolname) from unnest(p.polroles) a left join pg_roles r on r.oid=a)) order by n.nspname,c.relname,p.polname),'[]') from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace),
 'triggers',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||t.tgname,'definition',pg_get_triggerdef(t.oid),'enabled',t.tgenabled) order by n.nspname,c.relname,t.tgname),'[]') from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal),
 'constraints',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname||'.'||t.conname,'definition',pg_get_constraintdef(t.oid)) order by n.nspname,c.relname,t.conname),'[]') from pg_constraint t join pg_class c on c.oid=t.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage')),
 'indexes',(select coalesce(jsonb_agg(jsonb_build_object('id',schemaname||'.'||indexname,'table',schemaname||'.'||tablename,'definition',indexdef) order by schemaname,indexname),'[]') from pg_indexes where schemaname in ('public','private','auth','storage')),
 'views',(select coalesce(jsonb_agg(jsonb_build_object('id',n.nspname||'.'||c.relname,'definition',pg_get_viewdef(c.oid,true),'acl',coalesce(c.relacl::text,''),'extension_owned',exists(select 1 from pg_depend e where e.classid='pg_class'::regclass and e.objid=c.oid and e.deptype='e')) order by n.nspname,c.relname),'[]') from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('v','m') and n.nspname in ('public','private','auth','storage'))
) as catalog`;

// Compare canonical application objects before any hosted write. Provider-owned
// Auth/Storage internals and extension objects vary independently; application
// Storage policies and the approved pgcrypto callees remain in scope.
export function predecessorCatalog(catalog) {
  const owned = (v) => /^(?:public|private)\./.test(v.id) && !v.extension_owned;
  const tables = new Set(catalog.tables.filter(owned).map((t) => t.id));
  const onOwnedTable = (v) => [...tables].some((t) => v.id.startsWith(t + "."));
  return Object.fromEntries(
    Object.entries(catalog).map(([section, objects]) => [
      section,
      objects
        .filter((v) => {
          if (section === "tables") return tables.has(v.id);
          if (section === "functions")
            return (
              owned(v) || /^extensions\.(?:digest|gen_random_uuid)\(/.test(v.id)
            );
          if (section === "indexes") return tables.has(v.table);
          if (section === "views") return owned(v);
          if (section === "policies")
            return onOwnedTable(v) || v.id.startsWith("storage.");
          return onOwnedTable(v);
        })
        .map((v) => {
          if (section === "functions" && v.id.startsWith("extensions."))
            return {
              id: v.id,
              owner: ["postgres", "supabase_admin"].includes(v.owner)
                ? "provider-admin"
                : v.owner,
              returns: v.returns,
              arguments: v.arguments,
              source_body: v.source_body,
              binary: v.binary,
              language: v.language,
              definer: v.definer,
              extension_owned: v.extension_owned,
              postgres_execute: v.postgres_execute,
            };
          return v;
        }),
    ]),
  );
}
export function assertPredecessorCatalog(expected, actual) {
  const drift = catalogEffects(expected, predecessorCatalog(actual));
  if (drift.length)
    throw new ReleaseError(
      "Unverified live predecessor catalog drift: " +
        drift
          .slice(0, 8)
          .map((d) => d.id)
          .join(", "),
    );
}
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
        if (JSON.stringify(a.access) !== JSON.stringify(b.access))
          throw new ReleaseError(
            `Existing table permission contract changed: ${a.id}`,
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
    if (
      candidate.classification !== "established-contract-candidate" &&
      !table.expressions_safe
    )
      throw new ReleaseError(
        `New private expressions depend on an unproven function/operator: ${table.id}`,
      );
    if (
      candidate.classification !== "established-contract-candidate" &&
      table.columns.some(
        (c) =>
          ![
            "boolean",
            "smallint",
            "integer",
            "bigint",
            "text",
            "uuid",
            "jsonb",
            "date",
            "timestamp with time zone",
          ].includes(c.type),
      )
    )
      throw new ReleaseError(
        `New private table uses an unproven type: ${table.id}`,
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
        fn.leakproof ||
        fn.parallel !== "u" ||
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
  if (
    evidence?.policy_version !== POLICY_VERSION ||
    evidence.project_ref !== STAGING_REF ||
    evidence.source_sha !== source ||
    evidence.source_tree !== tree ||
    evidence.policy_module_sha256 !== policyModuleHash() ||
    evidence.inventory_sha256 !== inventoryDigest(local) ||
    !evidence.predecessor_catalog ||
    evidence.predecessor_catalog_sha256 !==
      sha256(JSON.stringify(evidence.predecessor_catalog)) ||
    !evidence.no_op_retry ||
    !evidence.resource_auth_rest ||
    !evidence.generated_types ||
    !evidence.trusted_security_tests ||
    !evidence.real_actor_denials ||
    !evidence.storage_objects_preserved ||
    !evidence.policy_negative_probes ||
    !evidence.single_writer_probe ||
    !evidence.cli_startup_bounds ||
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
