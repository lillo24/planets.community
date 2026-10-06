import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { applyParticipationRpcNullability } from "./lib/participation-rpc-nullability.mjs";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const outputPath = fileURLToPath(
  new URL("../apps/web/src/types/database.generated.ts", import.meta.url),
);
const argumentsList = [
  "gen",
  "types",
  "typescript",
  "--local",
  "--schema",
  "public",
];

const result = spawnSync("supabase", argumentsList, {
  cwd: repositoryRoot,
  encoding: "utf8",
  maxBuffer: 64 * 1024 * 1024,
  shell: process.platform === "win32",
});

if (result.stderr) {
  process.stderr.write(result.stderr);
}

if (result.error) {
  throw new Error(
    `Failed to start the project-scoped Supabase CLI: ${result.error.message}`,
  );
}

if (result.status !== 0) {
  process.exitCode = result.status ?? 1;
} else if (!result.stdout.trim()) {
  throw new Error(
    "Supabase type generation succeeded without producing TypeScript output.",
  );
} else {
  // The pg-meta process and shell redirection can differ by one terminal newline across hosts.
  // pg-meta omits RETURNS TABLE nullability; apply the documented participation
  // and MSG01 result contracts, then normalize the terminal newline. Never hand-edit.
  const generatedTypes = applyParticipationRpcNullability(
    result.stdout.trimEnd(),
  );
  writeFileSync(outputPath, `${generatedTypes}\n`, "utf8");
}
