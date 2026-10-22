import { ReleaseError } from "./errors.mjs";
import { sha256, sqlTokens } from "./sql-fingerprint.mjs";

export const inventoryDigest = (rows) =>
  sha256(
    JSON.stringify(
      rows
        .map((m) => ({
          version: m.version,
          sha256: m.sha256 ?? m.canonical_sha256,
        }))
        .sort((a, b) => a.version.localeCompare(b.version)),
    ),
  );
const identifier = /^[a-z_][a-z_0-9]*$/;
const types = new Set([
  "boolean",
  "smallint",
  "integer",
  "bigint",
  "text",
  "uuid",
  "jsonb",
  "date",
  "timestamptz",
]);

// This is an allowlisted complete grammar, not a dangerous-keyword denylist.
// Privileged code, data changes, grants, constraints/defaults and unknown syntax
// are never inferred safe. Catalog and populated-data witnesses are also required.
export function classifyMigration(sql) {
  let tokens;
  try {
    tokens = sqlTokens(sql);
  } catch {
    return {
      classification: "review-required",
      reason: "SQL cannot be reliably classified",
      effects: [],
    };
  }
  const statements = [];
  let current = [];
  for (const token of tokens) {
    if (token === ";") {
      if (current.length) statements.push(current);
      current = [];
    } else current.push(token);
  }
  if (current.length) statements.push(current);
  const normalized = statements.map((s) => s.map((t) => t.toLowerCase()));
  const settings = [
    ["set", "lock_timeout", "=", "'5s'"],
    ["set", "statement_timeout", "=", "'60s'"],
  ];
  const resets = [
    ["reset", "lock_timeout"],
    ["reset", "statement_timeout"],
  ];
  const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const unknown = () => ({
    classification: "review-required",
    reason:
      "Unsupported effects: review contracts, data preservation, privileges/RLS/Storage, triggers and operational risk",
    effects: [],
  });
  if (
    normalized.length < 5 ||
    !settings.every((s, i) => equal(s, normalized[i])) ||
    !resets.every((s, i) => equal(s, normalized.at(i - 2)))
  )
    return unknown();
  const effects = [];
  for (const s of normalized.slice(2, -2)) {
    // ALTER TABLE public/private.name ADD COLUMN name built-in-type [NULL].
    if (s.length !== 9 && s.length !== 10) return unknown();
    if (
      !equal(s.slice(0, 2), ["alter", "table"]) ||
      !["public", "private"].includes(s[2]) ||
      s[3] !== "." ||
      !identifier.test(s[4]) ||
      !equal(s.slice(5, 7), ["add", "column"]) ||
      !identifier.test(s[7]) ||
      !types.has(s[8]) ||
      (s.length === 10 && s[9] !== "null")
    )
      return unknown();
    effects.push({ schema: s[2], table: s[4], column: s[7], type: s[8] });
  }
  if (
    !effects.length ||
    new Set(effects.map((e) => `${e.schema}.${e.table}.${e.column}`)).size !==
      effects.length
  )
    return unknown();
  return {
    classification: "routine-candidate",
    reason:
      "Only timeout-bounded nullable columns; requires before/after security and populated-row proof",
    effects,
  };
}

// Only metadata/hashes leave the server; no Auth records or routine bodies.
export const catalogQuery = `select jsonb_build_object(
 'tables',(select coalesce(jsonb_agg(x order by x->>'name'),'[]') from (
 select jsonb_build_object('name',n.nspname||'.'||c.relname,'owner',pg_get_userbyid(c.relowner),'kind',c.relkind,'rls',c.relrowsecurity,
 'inherited',exists(select 1 from pg_inherits i where i.inhparent=c.oid or i.inhrelid=c.oid),
 'client_access',exists(select 1 from pg_roles r where r.rolname in ('anon','authenticated','service_role') and has_table_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')),
 'security',md5(coalesce(c.relacl::text,'')||c.relforcerowsecurity::text),
 'columns',(select coalesce(jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated) order by a.attnum),'[]') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped)) x
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p')) t),
 'security',(select md5(coalesce(string_agg(x,E'\\n' order by x),'')) from (
 select 'routine:'||p.oid::text||':'||md5(pg_get_functiondef(p.oid)||coalesce(p.proacl::text,'')) x from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private','auth','storage') and p.prokind in ('f','p')
 union all select 'policy:'||oid||':'||polrelid||':'||md5(polname::text||polpermissive::text||polroles::text||polcmd::text||coalesce(pg_get_expr(polqual,polrelid),'')||coalesce(pg_get_expr(polwithcheck,polrelid),'')) from pg_policy
 union all select 'trigger:'||oid||':'||md5(pg_get_triggerdef(oid)||tgenabled::text) from pg_trigger where not tgisinternal
 union all select 'constraint:'||oid||':'||md5(pg_get_constraintdef(oid)) from pg_constraint
 union all select 'index:'||indexrelid||':'||md5(pg_get_indexdef(indexrelid)) from pg_index
 union all select 'view:'||c.oid||':'||md5(pg_get_viewdef(c.oid,true)||coalesce(c.relacl::text,'')) from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('v','m') and n.nspname in ('public','private','auth','storage')
 ) s)) as catalog`;

export function assertRoutineTargets(before, effects) {
  for (const e of effects) {
    const prior = before.tables.find(
      (t) => t.name === `${e.schema}.${e.table}`,
    );
    if (
      !prior ||
      prior.kind !== "r" ||
      !prior.rls ||
      prior.inherited ||
      prior.client_access ||
      !["postgres", "supabase_admin"].includes(prior.owner) ||
      prior.columns.some((c) => c.name === e.column)
    )
      throw new ReleaseError(
        "Routine target must be an existing RLS/RPC-only regular table with a new column",
      );
  }
}
export function assertRoutineCatalog(before, after, effects) {
  assertRoutineTargets(before, effects);
  const copy = structuredClone(after);
  for (const e of effects) {
    const name = `${e.schema}.${e.table}`;
    const prior = before.tables.find((t) => t.name === name),
      next = copy.tables.find((t) => t.name === name);
    if (
      !prior ||
      !next ||
      prior.kind !== "r" ||
      !prior.rls ||
      prior.inherited ||
      prior.client_access ||
      !["postgres", "supabase_admin"].includes(prior.owner) ||
      prior.columns.some((c) => c.name === e.column)
    )
      throw new ReleaseError(
        "Routine target must be an existing RLS/RPC-only regular table with a new column",
      );
    const column = next.columns.find((c) => c.name === e.column);
    const type = e.type === "timestamptz" ? "timestamp with time zone" : e.type;
    if (
      !column ||
      column.type !== type ||
      column.not_null ||
      column.default !== null ||
      column.identity ||
      column.generated
    )
      throw new ReleaseError(
        "Routine column has unexpected default, type, generation or nullability",
      );
    next.columns = next.columns.filter((c) => c.name !== e.column);
  }
  if (JSON.stringify(before) !== JSON.stringify(copy))
    throw new ReleaseError(
      "Routine migration changed existing contracts/security/catalog outside its declared nullable columns",
    );
}

export function assertRehearsal(evidence, source, local) {
  if (
    evidence?.source_sha !== source ||
    evidence.inventory_sha256 !== inventoryDigest(local) ||
    evidence.no_op_retry !== true ||
    evidence.resource_auth_rest !== true ||
    evidence.generated_types !== true ||
    !Array.isArray(evidence.migration_safety)
  )
    throw new ReleaseError(
      "Missing/stale exact-source populated rehearsal and security witnesses",
    );
}

export function authorizePending(
  diff,
  local,
  evidence,
  source,
  reviews,
  reconciliation,
) {
  if (diff.drift.length)
    throw new ReleaseError("Migration drift blocks staging");
  if (!diff.pending.length) return [];
  assertRehearsal(evidence, source, local);
  const applied = local.filter(
    (m) => !diff.pending.some((p) => p.version === m.version),
  );
  const pending = diff.pending.map((p) =>
    local.find((m) => m.version === p.version),
  );
  if (
    pending.some(
      (m, i) =>
        !m || sha256(m.sql) !== m.sha256 || diff.pending[i].sha256 !== m.sha256,
    )
  )
    throw new ReleaseError("Canonical migration bytes changed");
  const historical = diff.pending.some((m) => m.historical);
  if (
    historical &&
    (reconciliation?.enabled !== true ||
      reconciliation.migrations?.length !== 2 ||
      reconciliation.predecessor_sha256 !== diff.predecessor_sha256 ||
      JSON.stringify(reconciliation.migrations) !==
        JSON.stringify(
          diff.pending
            .slice(0, 2)
            .map((m) => ({ version: m.version, sha256: m.sha256 })),
        ) ||
      diff.pending.slice(2).some((m) => m.historical))
  )
    throw new ReleaseError(
      "Historical catch-up requires the exact two-file reconciliation and observed predecessor; no global include-all",
    );
  const decisions = [];
  for (const migration of pending) {
    const predecessor = inventoryDigest(applied),
      result = classifyMigration(migration.sql);
    const witness = evidence.migration_safety.find(
      (w) =>
        w.version === migration.version &&
        w.sha256 === migration.sha256 &&
        w.predecessor_inventory_sha256 === predecessor,
    );
    if (witness?.preserved_rows !== true)
      throw new ReleaseError("Missing matching populated predecessor witness");
    const reviewed = reviews.some(
      (r) =>
        r.version === migration.version &&
        r.sha256 === migration.sha256 &&
        r.predecessor_inventory_sha256 === predecessor,
    );
    if (
      (result.classification !== "routine-candidate" ||
        (historical &&
          reconciliation.migrations.some(
            (m) => m.version === migration.version,
          ))) &&
      !reviewed
    )
      throw new ReleaseError(
        `Migration ${migration.version} needs verifiable pre-merge owner review for its exact hash/predecessor`,
      );
    if (!reviewed && witness.routine_security_preserved !== true)
      throw new ReleaseError("Routine before/after security proof missing");
    decisions.push({
      version: migration.version,
      sha256: migration.sha256,
      predecessor_inventory_sha256: predecessor,
      authorization: reviewed ? "pre-merge-owner-review" : "routine-verified",
    });
    applied.push(migration);
  }
  return decisions;
}
