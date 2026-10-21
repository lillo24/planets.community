import { readFile } from "node:fs/promises";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import {
  assertTarget,
  migrationInventory,
  MOCK_REF,
  MOCK_ORIGIN,
  NORMAL_ORIGIN,
  GENERATION,
  publicKey,
  databaseTarget,
} from "./target.mjs";

export async function operator(configPath) {
  const config = JSON.parse(await readFile(configPath, "utf8"));
  // Validate BEFORE connecting, including the independent DB endpoint.
  const inventory = await migrationInventory();
  const expected = {
    project_ref: MOCK_REF,
    generation: GENERATION,
    schema_fingerprint: inventory.fingerprint,
    operator_confirmed: true,
  };
  assertTarget(config, expected, inventory.fingerprint);
  const databaseUrl = process.env.MOCK_DATABASE_URL;
  const { temporary } = databaseTarget(databaseUrl);
  const sql = postgres(databaseUrl, {
    max: 4,
    ssl: "require",
    connect_timeout: 15,
    // Applied to every connection, including replacements. PostgreSQL itself
    // checks role membership; no grant or privilege bypass is attempted here.
    ...(temporary ? { connection: { options: "-c role=postgres" } } : {}),
    onnotice: () => {},
  });
  async function guard(tx = sql) {
    const [marker] =
      await tx`select * from mock_control.environment where singleton`;
    assertTarget(config, marker, inventory.fingerprint);
    return marker;
  }
  try {
    if (temporary) {
      const [identity] = await sql`select current_user`;
      if (identity.current_user !== "postgres")
        throw new Error("Temporary CLI connection did not assume postgres.");
    }
    await guard();
  } catch (error) {
    await sql.end();
    throw error;
  }
  return {
    config,
    inventory,
    sql,
    guard,
    client: () =>
      createClient(MOCK_ORIGIN, publicKey(config.publishableKey), {
        auth: { persistSession: false, autoRefreshToken: false },
      }),
    admin: () => {
      const key = process.env.MOCK_SERVICE_ROLE_KEY;
      if (!key)
        throw new Error(
          "MOCK_SERVICE_ROLE_KEY is required for Auth provisioning only.",
        );
      return createClient(MOCK_ORIGIN, key, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
    },
  };
}

export async function setup(context) {
  const { sql, guard, inventory } = context;
  await guard();
  await sql`create table if not exists mock_control.applied_migrations(name text primary key,sha256 text not null)`;
  await sql`alter table mock_control.applied_migrations enable row level security`;
  await sql`revoke all on mock_control.applied_migrations from public,anon,authenticated`;
  for (const migration of inventory.migrations) {
    const source = (
      await readFile(`supabase/migrations/${migration.name}`, "utf8")
    ).replaceAll("\r\n", "\n");
    await sql.begin(async (tx) => {
      await guard(tx);
      await tx`select pg_advisory_xact_lock(684026240991818)`;
      const [existing] =
        await tx`select sha256 from mock_control.applied_migrations where name=${migration.name}`;
      if (existing) {
        if (existing.sha256 !== migration.sha256)
          throw new Error("Reviewed migration drift; upgrade refused.");
        return;
      }
      // One historical migration includes its own transaction wrapper. Preserve
      // its statements inside this atomic, recorded application transaction.
      await tx.unsafe(
        source.replace(/^begin;\s*$/gim, "").replace(/^commit;\s*$/gim, ""),
      );
      await tx`insert into mock_control.applied_migrations values(${migration.name},${migration.sha256})`;
    });
  }
  await guard();
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
}

export async function shutdown(context) {
  await context.sql.begin(async (tx) => {
    await context.guard(tx);
    await tx`select public.mock_control_shutdown()`;
  });
}

export async function maintenance(context) {
  await context.sql.begin(async (tx) => {
    await context.guard(tx);
    // Delivery ciphertext lasts 2 minutes; audit bindings last seven days.
    await tx`update mock_control.client_deliveries set encrypted_delivery=null where expires_at<=now()`;
    await tx`delete from mock_control.client_deliveries where state='retired' and created_at<now()-interval '7 days'`;
  });
}

if (process.argv[1]?.replaceAll("\\", "/").endsWith("/mock/operator.mjs")) {
  try {
    const [action, configPath] = process.argv.slice(2);
    if (action === "inventory" && !configPath) {
      const { fingerprint, migrations } = await migrationInventory();
      console.log(
        JSON.stringify({
          project_ref: MOCK_REF,
          generation: GENERATION,
          schema_fingerprint: fingerprint,
          migrations: migrations.length,
        }),
      );
    } else {
      if (
        !["dry-run", "setup", "shutdown", "maintenance"].includes(action) ||
        !configPath
      )
        throw new Error(
          "Use inventory | dry-run/setup/shutdown/maintenance <private-config>.",
        );
      const context = await operator(configPath);
      try {
        if (action === "setup") await setup(context);
        if (action === "shutdown") await shutdown(context);
        if (action === "maintenance") await maintenance(context);
        console.log(
          JSON.stringify({
            action,
            project_ref: MOCK_REF,
            generation: GENERATION,
            schema_fingerprint: context.inventory.fingerprint,
            success: true,
          }),
        );
      } finally {
        await context.sql.end();
      }
    }
  } catch {
    console.error(
      "Mock operator failed; check exact target, marker, schema and required private inputs. No secrets are logged.",
    );
    process.exitCode = 1;
  }
}
