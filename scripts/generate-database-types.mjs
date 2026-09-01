import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

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
  // Normalize only the file ending; the generated TypeScript itself remains byte-for-byte output.
  writeFileSync(outputPath, `${result.stdout.trimEnd()}\n`, "utf8");
}
