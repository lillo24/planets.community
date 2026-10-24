import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import postgres from "postgres";

assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
const directory = path.resolve(process.argv[2]);
assert.equal(path.dirname(directory), os.tmpdir());
assert.ok(path.basename(directory).startsWith("planets-a1-"));
const status = JSON.parse(
  await readFile(path.join(directory, "private-status.json"), "utf8"),
);
assert.equal(new URL(status.databaseUrl).hostname, "127.0.0.1");
assert.equal(new URL(status.databaseUrl).port, "61322");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
try {
  const names = (await readdir("supabase/migrations")).filter((n) =>
    n.endsWith("_a1_unified_private_conversations.sql"),
  );
  assert.equal(names.length, 1);
  const source = await readFile(
    path.join("supabase/migrations", names[0]),
    "utf8",
  );
  const mode = process.argv[3];
  assert.ok(["--apply", "--refresh-functions", "--test"].includes(mode));
  if (mode === "--apply") await sql.unsafe(source);
  if (mode === "--refresh-functions") {
    // Only this task's disposable iteration; canonical replay still uses the
    // unchanged migration file. No original domain function is replaced here.
    await sql.unsafe(
      "drop function if exists public.list_own_private_pair_contexts_v1(uuid,uuid,integer,text,uuid)",
    );
    await sql.unsafe("drop function if exists private.a1_messages(uuid,uuid)");
    for (const match of source.matchAll(/create function [\s\S]*?\$\$;/g))
      await sql.unsafe(
        match[0].replace("create function ", "create or replace function "),
      );
    const grants = source.indexOf("revoke all on function private.a1_actor");
    assert.ok(grants >= 0, "A1 grants block must be present.");
    await sql.unsafe(source.slice(grants));
  }
  console.log(`A1 owned local ${mode}: ${names[0]}`);
  if (process.argv[4]) {
    await sql.unsafe(
      "create extension if not exists pgtap with schema extensions; set search_path=public,extensions",
    );
    const result = await sql.unsafe(await readFile(process.argv[4], "utf8"));
    const text = result
      .flatMap((set) =>
        Array.isArray(set)
          ? set.flatMap((r) => Object.values(r))
          : Object.values(set),
      )
      .join("\n");
    await writeFile(path.join(directory, "private-verification.txt"), text);
    console.log(
      text
        .split("\n")
        .filter((line) => /^(not ok |#|1\.\.)/.test(line))
        .join("\n"),
    );
    console.log(
      `${text.split("\n").filter((line) => /^ok /.test(line)).length} pgTAP assertions passed.`,
    );
    assert.ok(!/^not ok /m.test(text), "A1 pgTAP assertion failed");
  }
} finally {
  await sql.end({ timeout: 5 });
}
