import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(
  new URL("../collect-contact-native-evidence.mjs", import.meta.url),
);
// Tiny fictional files only; no SDK, container, credentials or external service.
async function fixture() {
  const base = await mkdtemp(
    resolve(tmpdir(), "planets-native-evidence-test-"),
  );
  const privateRoot = resolve(base, "private");
  const checkout = resolve(base, "checkout");
  await mkdir(privateRoot);
  await mkdir(checkout);
  execFileSync("git", ["init", "-q"], { cwd: checkout });
  execFileSync(
    "git",
    [
      "-c",
      "user.name=Fictional QA",
      "-c",
      "user.email=qa@planets.invalid",
      "-c",
      "commit.gpgsign=false",
      "commit",
      "--allow-empty",
      "-qm",
      "Fictional collector fixture",
    ],
    { cwd: checkout },
  );
  const png = Buffer.from("89504e470d0a1a0a", "hex");
  const secret = "fictional-collector-secret-only";
  for (const [lane, feature] of [
    ["d", "group-contact"],
    ["m", "member-contact"],
  ]) {
    await writeFile(
      resolve(privateRoot, `${lane}-defines.json`),
      JSON.stringify({ ACCESS_TOKEN: secret }),
    );
    await writeFile(resolve(privateRoot, `${lane}-driver-passed`), "");
    const directory = resolve(
      checkout,
      "apps/mobile/build",
      `${feature}-screenshots`,
    );
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "synthetic.png"), png);
    await writeFile(
      resolve(
        checkout,
        "apps/mobile/build",
        `${feature.replaceAll("-", "_")}_response_data.json`,
      ),
      JSON.stringify({
        stored_screenshots: [
          { screenshotName: "synthetic", byteCount: png.length },
        ],
        sample: secret,
      }),
    );
  }
  return {
    privateRoot,
    checkout,
    secret,
    run: (result = "0", phase = "complete") =>
      spawnSync(process.execPath, [script, privateRoot, result, phase], {
        cwd: checkout,
        encoding: "utf8",
        env: {
          ...process.env,
          GITHUB_ACTIONS: "true",
          RUNNER_ENVIRONMENT: "github-hosted",
        },
      }),
  };
}

test("collects both complete drivers and redacts private metadata/diagnostics", async () => {
  const f = await fixture();
  let result = f.run();
  assert.equal(result.status, 0, result.stderr);
  const output = resolve(f.checkout, "contact-native-evidence");
  const manifest = JSON.parse(
    await readFile(resolve(output, "manifest.json"), "utf8"),
  );
  assert.deepEqual(manifest.driverPassed, { d: true, m: true });
  assert.deepEqual(manifest.responseFramesMatch, { d: true, m: true });
  assert.equal(manifest.files.length, 2);
  assert.ok(
    !(await readFile(resolve(output, "d-response.json"), "utf8")).includes(
      f.secret,
    ),
  );
  await writeFile(
    resolve(f.privateRoot, "d-drive.log"),
    `Bearer ${f.secret}\neyJfake.aaa.bbb\nsb_secret_fictional postgres://postgres:fictional-password@127.0.0.1:54322/postgres`,
  );
  result = f.run("1", "d-drive");
  assert.equal(result.status, 0, result.stderr);
  const diagnostic = await readFile(resolve(output, "failure.txt"), "utf8");
  for (const value of [
    f.secret,
    "eyJfake.aaa.bbb",
    "sb_secret_fictional",
    "fictional-password",
  ])
    assert.ok(!diagnostic.includes(value));
});

test("rejects duplicate checkpoint names even when overwritten bytes match", async () => {
  const f = await fixture();
  const path = resolve(
    f.checkout,
    "apps/mobile/build/group_contact_response_data.json",
  );
  const response = JSON.parse(await readFile(path, "utf8"));
  response.stored_screenshots.push({ ...response.stored_screenshots[0] });
  await writeFile(path, JSON.stringify(response));
  const result = f.run();
  assert.notEqual(result.status, 0);
  const manifest = JSON.parse(
    await readFile(
      resolve(f.checkout, "contact-native-evidence/manifest.json"),
      "utf8",
    ),
  );
  assert.equal(manifest.responseFramesMatch.d, false);
});

test("rejects duplicated image bytes in compact response metadata", async () => {
  const f = await fixture();
  await writeFile(
    resolve(f.checkout, "apps/mobile/build/group_contact_response_data.json"),
    JSON.stringify({ screenshots: [{ bytes: [1] }] }),
  );
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Duplicate screenshot byte payload/);
});
