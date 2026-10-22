import { ReleaseError, reportFailure } from "./errors.mjs";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  copyFileSync,
} from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { stagingRelease } from "./staging.mjs";
import { releaseConfig } from "./config.mjs";
import {
  playAccessToken,
  playClient,
  selectTrack,
  allocateCode,
} from "./play.mjs";

export function manualCode(env, policy, now = Date.now()) {
  const code = Number(env.PLAY_VERIFIED_UNUSED_CODE);
  const checked = Date.parse(env.PLAY_CONSOLE_CHECKED_AT ?? "");
  if (
    !Number.isSafeInteger(code) ||
    code <= policy.historical_version_code_floor ||
    code > 2100000000 ||
    !Number.isFinite(checked) ||
    checked > now ||
    now - checked > 86400000
  )
    throw new ReleaseError(
      "Manual build needs a fresh Console check and verified unused code",
    );
  return code;
}

export function prepareSigning(env, root) {
  const configPath = resolve(root, "apps/mobile/config/staging.json");
  const propertiesPath = resolve(root, "apps/mobile/android/key.properties");
  const keyPath = resolve(root, "apps/mobile/android/release01-upload.jks");
  const paths = [configPath, propertiesPath, keyPath];
  if (paths.some(existsSync))
    throw new ReleaseError(
      "Release refuses to overwrite local signing/config files",
    );
  for (const name of [
    "STAGING_CONFIG_JSON",
    "ANDROID_UPLOAD_KEYSTORE_BASE64",
    "ANDROID_UPLOAD_STORE_PASSWORD",
    "ANDROID_UPLOAD_KEY_PASSWORD",
    "ANDROID_UPLOAD_KEY_ALIAS",
  ]) {
    if (!env[name])
      throw new ReleaseError(`Missing protected environment secret ${name}`);
  }
  const config = releaseConfig(env);
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(env.ANDROID_UPLOAD_KEYSTORE_BASE64))
    throw new ReleaseError("Invalid original upload keystore encoding");
  // Java Properties escapes every character, including newlines/backslashes.
  const property = (value) =>
    value
      .split("")
      .map((c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`)
      .join("");
  const properties = {
    storeFile: keyPath.replaceAll("\\", "/"),
    storePassword: env.ANDROID_UPLOAD_STORE_PASSWORD,
    keyAlias: env.ANDROID_UPLOAD_KEY_ALIAS,
    keyPassword: env.ANDROID_UPLOAD_KEY_PASSWORD,
  };
  if (properties.keyAlias === "androiddebugkey")
    throw new ReleaseError("Original upload signing key required");
  mkdirSync(resolve(root, "apps/mobile/config"), { recursive: true });
  mkdirSync(resolve(root, "apps/mobile/android"), { recursive: true });
  try {
    writeFileSync(configPath, JSON.stringify(config), {
      mode: 0o600,
      flag: "wx",
    });
    writeFileSync(
      keyPath,
      Buffer.from(env.ANDROID_UPLOAD_KEYSTORE_BASE64, "base64"),
      { mode: 0o600, flag: "wx" },
    );
    writeFileSync(
      propertiesPath,
      Object.entries(properties)
        .map(([key, value]) => `${key}=${property(value)}`)
        .join("\n"),
      { mode: 0o600, flag: "wx" },
    );
  } catch (error) {
    for (const path of paths) rmSync(path, { force: true });
    throw error;
  }
  return () => {
    for (const path of paths) rmSync(path, { force: true });
  };
}

function command(program, args, cwd) {
  const result = spawnSync(program, args, {
    cwd,
    encoding: "utf8",
    timeout: 1800000,
    maxBuffer: 16 * 1024 * 1024,
    shell: process.platform === "win32",
  });
  // Builds may echo compile-time config: retain no raw logs or secret values.
  if (result.error || result.status !== 0)
    throw new ReleaseError(
      `${program} release step failed; raw output withheld; reproduce using the runbook`,
    );
  return result.stdout.trim();
}

export async function androidRelease(mode, env = process.env) {
  if (mode !== "build")
    throw new ReleaseError(
      "Use android.mjs build; publication is a separate approval job",
    );
  const root = process.cwd();
  const policy = JSON.parse(
    readFileSync("scripts/release/policy.json", "utf8"),
  );
  const validated = JSON.parse(
    readFileSync("build/release01/validation.json", "utf8"),
  );
  if (
    env.GITHUB_REF !== "refs/heads/main" ||
    validated.source_sha !== env.GITHUB_SHA ||
    command("git", ["rev-parse", "HEAD"], root) !== env.GITHUB_SHA ||
    command("git", ["status", "--porcelain"], root)
  )
    throw new ReleaseError("Android requires clean exact tested main");
  const currentMain = () =>
    command("git", ["ls-remote", "origin", "refs/heads/main"], root).split(
      /\s/,
    )[0];
  if (currentMain() !== env.GITHUB_SHA)
    throw new ReleaseError("Main advanced; start a new release run");
  await stagingRelease("verify", env);
  let api;
  let code;
  if (env.PLAY_SERVICE_ACCOUNT_JSON) {
    api = playClient(await playAccessToken(env.PLAY_SERVICE_ACCOUNT_JSON));
    const edit = await api.create();
    try {
      const inventory = await api.inventory(edit.id);
      selectTrack(inventory.tracks, policy);
      code = allocateCode(
        policy,
        Number(env.GITHUB_RUN_NUMBER),
        inventory.tracks,
        inventory.bundles,
        inventory.apks,
      );
    } finally {
      await api.discard(edit.id);
    }
  } else {
    code = manualCode(env, policy);
  }
  const cleanup = prepareSigning(env, root);
  try {
    console.log(
      `Building map-enabled upload-signed AAB with verified version code ${code}`,
    );
    command("flutter", ["pub", "get"], resolve(root, "apps/mobile"));
    const args = [
      "run",
      "tool/build_map_live_staging.dart",
      "appbundle",
      String(code),
      ...(policy.budget_basemap ? ["--budget-basemap"] : []),
    ];
    command("dart", args, resolve(root, "apps/mobile"));
    command(
      "python3",
      [
        "scripts/release/artifact.py",
        "apps/mobile/build/app/outputs/bundle/release/app-release.aab",
        String(code),
      ],
      root,
    );
    const evidence = JSON.parse(
      readFileSync("build/release01/artifact.json", "utf8"),
    );
    const name = `planets-staging-${code}-${env.GITHUB_SHA.slice(0, 12)}.aab`;
    copyFileSync(
      "apps/mobile/build/app/outputs/bundle/release/app-release.aab",
      `build/release01/${name}`,
    );
    console.log(`Verified manual-upload artifact: build/release01/${name}`);
  } finally {
    cleanup();
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  androidRelease(process.argv[2]).catch((error) =>
    reportFailure("Android delivery", error),
  );
}
