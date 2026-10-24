// Only a bounded scrubbed phase tail may leave the private CI directory.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
const [directory, world, phase, evidence] = process.argv.slice(2);
if (!/^[a-z-]+$/.test(phase)) throw new Error("Invalid diagnostic phase.");
const secrets = new Set();
function collect(value) {
  if (typeof value === "string" && value.length >= 8) secrets.add(value);
  else if (value && typeof value === "object")
    for (const child of Object.values(value)) collect(child);
}
for (const file of [
  "private-environment.json",
  "private-status.json",
  "private-defines.json",
  "private-world.json",
  "private-native-world.json",
  "supabase/signing_keys.json",
]) {
  try {
    collect(JSON.parse(await readFile(path.join(world, file), "utf8")));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}
let tail = await readFile(path.join(directory, `${phase}.log`), "utf8").catch(
  (error) => {
    if (error.code === "ENOENT") return "No phase log was produced.";
    throw error;
  },
);
for (const secret of [...secrets].sort((a, b) => b.length - a.length))
  tail = tail.replaceAll(secret, "[private]");
tail = tail
  .replace(
    /\b(?:sb_(?:secret|publishable)_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){1,2})\b/g,
    "[credential]",
  )
  .replace(/\b\d{6}\b/g, "[six-digit value]")
  .replace(
    /((?:authorization|apikey|refresh_token|access_token)\s*[=:]\s*)[^\s,}\]]+/gi,
    "$1[credential]",
  );
tail = tail.slice(-10000);
await writeFile(
  path.join(evidence, "diagnostic.json"),
  JSON.stringify({ phase, tail }),
);
console.log(`A1 failed during ${phase}. Scrubbed diagnostic:\n${tail}`);
