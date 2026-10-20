// Exports only fictional UI PNGs, bounded driver metadata and scrubbed diagnostics.
// Private session defines, APKs and raw runtime logs never enter the artifact.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import {
  copyFile,
  mkdir,
  readFile,
  readdir,
  stat,
  writeFile,
} from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";
import { tmpdir } from "node:os";

const [directory, result, phase] = process.argv.slice(2);
const privateRoot = resolve(directory ?? "");
const insideTemporary = relative(tmpdir(), privateRoot);
if (
  process.env.GITHUB_ACTIONS !== "true" ||
  process.env.RUNNER_ENVIRONMENT !== "github-hosted" ||
  !insideTemporary ||
  insideTemporary.startsWith("..") ||
  isAbsolute(insideTemporary) ||
  !/^[0-9]+$/.test(result ?? "") ||
  !/^[a-z-]+$/.test(phase ?? "")
)
  throw new Error(
    "Evidence collection requires the private CI temporary directory and explicit outcome.",
  );
const output = resolve("contact-native-evidence");
await mkdir(output, { recursive: true });
const secretValues = [];
for (const lane of ["d", "m"]) {
  try {
    const defines = JSON.parse(
      await readFile(resolve(privateRoot, `${lane}-defines.json`), "utf8"),
    );
    for (const [key, value] of Object.entries(defines)) {
      if (
        /token|key|secret|password/i.test(key) &&
        typeof value === "string" &&
        value.length > 12
      )
        secretValues.push(value);
    }
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}
function scrub(value) {
  let text = value;
  for (const secret of secretValues)
    text = text.replaceAll(secret, "[redacted]");
  return text
    .replace(/sb_(?:secret|publishable)_[A-Za-z0-9_-]+/g, "[redacted-key]")
    .replace(
      /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
      "[redacted-jwt]",
    )
    .replace(/Bearer\s+\S+/gi, "Bearer [redacted]")
    .replace(/(postgres(?:ql)?:\/\/[^:\s/]+:)[^@\s]+@/gi, "$1[redacted]@");
}
const files = [];
const responses = {};
for (const [lane, feature] of [
  ["d", "group-contact"],
  ["m", "member-contact"],
]) {
  const source = resolve("apps/mobile/build", `${feature}-screenshots`);
  let names;
  try {
    names = await readdir(source);
  } catch (error) {
    if (error.code === "ENOENT") continue;
    throw error;
  }
  await mkdir(resolve(output, feature), { recursive: true });
  for (const name of names) {
    if (!/^[a-zA-Z0-9_-]+\.png$/.test(name))
      throw new Error("Unexpected native evidence filename.");
    const path = resolve(source, name);
    if (!(await stat(path)).isFile())
      throw new Error("Unexpected native evidence entry.");
    const bytes = await readFile(path);
    if (bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a")
      throw new Error("Native evidence must be PNG.");
    await copyFile(path, resolve(output, feature, name));
    files.push({
      lane,
      file: `${feature}/${name}`,
      bytes: bytes.length,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    });
  }
  const response = resolve(
    "apps/mobile/build",
    `${feature.replaceAll("-", "_")}_response_data.json`,
  );
  try {
    if ((await stat(response)).size > 1024 * 1024)
      throw new Error("Native response metadata exceeds its 1 MiB bound.");
    const metadata = JSON.parse(await readFile(response, "utf8"));
    if (Object.hasOwn(metadata, "screenshots"))
      throw new Error("Duplicate screenshot byte payload is forbidden.");
    if (!Array.isArray(metadata.stored_screenshots))
      throw new Error("Missing native screenshot metadata.");
    const frames = metadata.stored_screenshots;
    responses[lane] =
      frames.length === files.filter((file) => file.lane === lane).length &&
      new Set(frames.map((frame) => frame.screenshotName)).size ===
        frames.length &&
      frames.every((frame) =>
        files.some(
          (file) =>
            file.lane === lane &&
            file.file === `${feature}/${frame.screenshotName}.png` &&
            file.bytes === frame.byteCount,
        ),
      );
    await writeFile(
      resolve(output, `${lane}-response.json`),
      scrub(JSON.stringify(metadata, null, 2)),
    );
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}
const passed = {};
for (const lane of ["d", "m"]) {
  passed[lane] = await stat(resolve(privateRoot, `${lane}-driver-passed`)).then(
    () => true,
    (error) => {
      if (error.code !== "ENOENT") throw error;
      return false;
    },
  );
}
await writeFile(
  resolve(output, "manifest.json"),
  JSON.stringify(
    {
      head: execFileSync("git", ["rev-parse", "HEAD"], {
        encoding: "utf8",
      }).trim(),
      runId: process.env.GITHUB_RUN_ID,
      runAttempt: process.env.GITHUB_RUN_ATTEMPT,
      collectedAt: new Date().toISOString(),
      exitCode: Number(result),
      phase,
      driverPassed: passed,
      responseFramesMatch: responses,
      viewport: "720x1600 / density 360 / 320dp / 2x in-app text",
      files,
    },
    null,
    2,
  ),
);
if (result !== "0") {
  try {
    // CLI startup may print local service/S3 credentials before defines exist.
    // Fixture preparation also owns Auth credentials. Export neither raw log.
    const log = ["backend", "d-fixture", "m-fixture"].includes(phase)
      ? `Contact native failed during ${phase}; credential-bearing runtime log remains private.`
      : await readFile(resolve(privateRoot, `${phase}.log`), "utf8");
    const diagnostic = scrub(log.split("\n").slice(-90).join("\n"));
    await writeFile(resolve(output, "failure.txt"), diagnostic);
    process.stderr.write(diagnostic);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}
if (
  result === "0" &&
  ["d", "m"].some(
    (lane) =>
      !passed[lane] ||
      !responses[lane] ||
      !files.some((file) => file.lane === lane),
  )
)
  throw new Error(
    "Native success requires both complete drivers and actual frames.",
  );
console.log(
  `Contact evidence: ${files.length} PNGs; driver D=${passed.d}, M=${passed.m}; phase=${phase}, exit=${result}.`,
);
