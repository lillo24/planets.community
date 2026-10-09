import { cpSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const root = fileURLToPath(new URL("../../../", import.meta.url));
export const backend = fileURLToPath(
  new URL("../.wrangler/link-host03/backend/", import.meta.url),
);
const source = fileURLToPath(new URL("../../../supabase/", import.meta.url));
const mode = process.argv[2];
if (!["prepare", "start", "stop", "status"].includes(mode))
  throw new Error(
    "Choose prepare/start/stop/status for the owned LINK-HOST-03 stack.",
  );
if (mode === "prepare") {
  mkdirSync(`${backend}/supabase`, { recursive: true });
  let config = readFileSync(`${source}/config.toml`, "utf8")
    .replace(
      'project_id = "planets-community"',
      'project_id = "planets-community-link-host03"',
    )
    .replace(/5432([0-9])/gu, "5912$1")
    .replace("inspector_port = 8083", "inspector_port = 8913");
  writeFileSync(`${backend}/supabase/config.toml`, config);
  for (const entry of ["migrations", "templates", "seed.sql"])
    cpSync(`${source}/${entry}`, `${backend}/supabase/${entry}`, {
      recursive: true,
    });
  console.log(
    "Copied canonical migrations/templates into the owned local backend; repository config is unchanged.",
  );
} else {
  if (
    !readFileSync(`${backend}/supabase/config.toml`, "utf8").includes(
      'project_id = "planets-community-link-host03"',
    )
  )
    throw new Error("Owned stack configuration required.");
  const cli = require.resolve("supabase/dist/supabase.js");
  const args = [mode, "--workdir", backend];
  if (mode === "start")
    args.push("--exclude", "studio,edge-runtime,logflare,vector,supavisor");
  // Status includes credentials: keep it local and private, print only a label.
  if (mode === "status") args.push("--output", "json");
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
  });
  mkdirSync(
    fileURLToPath(new URL("../.wrangler/link-host03/", import.meta.url)),
    { recursive: true },
  );
  writeFileSync(
    fileURLToPath(
      new URL(`../.wrangler/link-host03/backend-${mode}.log`, import.meta.url),
    ),
    `${result.stdout}\n${result.stderr}`,
  );
  if (result.error || result.status !== 0)
    throw new Error(
      `Owned backend ${mode} failed; inspect private local diagnostic output.`,
    );
  console.log(`Owned backend ${mode} completed; output stays ignored.`);
}
