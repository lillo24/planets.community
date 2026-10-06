import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdtemp,
  readFile,
  writeFile,
  cp,
  rm,
  symlink,
  realpath,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const inputs = {
  main: "cbfbf0ae6de9eb73906361c5980b113ec6bc2046",
  template: "63bfb83120af76af404055a9999d3298181f3c34",
};
const started = performance.now();
const workspace = await mkdtemp(
  path.join(tmpdir(), "planets-tw-stack01-upgrades-"),
);
const ownedRoot = await realpath(workspace);
function run(command, args, cwd, env = {}, timeout = 180000) {
  const result = spawnSync(command, args, {
    cwd,
    env: { ...process.env, ...env },
    encoding: "utf8",
    shell: process.platform === "win32" && command === "supabase",
    timeout,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    if (
      command === process.execPath &&
      args[0].endsWith("verify-local-stack-upgrade-state.mjs")
    )
      process.stderr.write(result.stderr);
    // Supabase start/status and auth output may contain credentials. Fail with
    // operation and exit status; keep no raw output in CI or persistent logs.
    throw new Error(
      `Upgrade ${path.basename(command)} ${args[0]} failed (${result.status ?? result.error?.code}).`,
    );
  }
  return result.stdout;
}
try {
  for (const [direction, head] of Object.entries(inputs)) {
    assert.equal(run("git", ["cat-file", "-t", head], root).trim(), "commit");
    const directory = path.join(workspace, direction);
    const archive = path.join(workspace, `${direction}.tar`);
    run("git", ["archive", "--format=tar", `--output=${archive}`, head], root);
    await import("node:fs/promises").then(({ mkdir }) => mkdir(directory));
    run("tar", ["-xf", archive, "-C", directory], root);
    await symlink(
      path.join(root, "node_modules"),
      path.join(directory, "node_modules"),
      process.platform === "win32" ? "junction" : "dir",
    );
    const configPath = path.join(directory, "supabase/config.toml");
    // Stay below the CLI's container-name project-ID truncation boundary.
    const project = `planets-tws01-${direction}-${process.pid}`;
    const config = (await readFile(configPath, "utf8"))
      .replace('project_id = "planets-community"', `project_id = "${project}"`)
      .replaceAll("543", "550")
      .replace("inspector_port = 8083", "inspector_port = 8113");
    await writeFile(configPath, config);
    let began = false;
    try {
      began = true;
      run("supabase", ["start"], directory);
      run("supabase", ["db", "reset", "--local"], directory);
      run(process.execPath, ["scripts/seed-local-demo-world.mjs"], directory, {
        MAILPIT_URL: "http://127.0.0.1:55024",
      });
      const checkpoint = path.join(workspace, `${direction}.json`);
      const checker = path.join(
        root,
        "scripts/verify-local-stack-upgrade-state.mjs",
      );
      console.log(
        run(
          process.execPath,
          [checker, "--before", direction, checkpoint],
          directory,
        ).trim(),
      );
      await cp(
        path.join(root, "supabase/migrations"),
        path.join(directory, "supabase/migrations"),
        { recursive: true },
      );
      // CLI --include-all applies missing interleaved timestamps; the populated
      // database is never reset after its snapshot and no history is repaired.
      run(
        "supabase",
        ["migration", "up", "--local", "--include-all"],
        directory,
      );
      run(
        "supabase",
        ["migration", "up", "--local", "--include-all"],
        directory,
      );
      console.log(
        run(
          process.execPath,
          [checker, "--after", direction, checkpoint],
          directory,
        ).trim(),
      );
      await cp(path.join(root, "scripts"), path.join(directory, "scripts"), {
        recursive: true,
      });
      // Separate, explicit mutation after preservation has been proved. Both
      // predecessor worlds must converge and then remain stable on plain rerun.
      console.log(
        run(
          process.execPath,
          [checker, "--seed-rerun", direction, checkpoint],
          directory,
          { MAILPIT_URL: "http://127.0.0.1:55024" },
        ).trim(),
      );
    } finally {
      if (began)
        run(
          "supabase",
          ["stop", "--project-id", project, "--no-backup"],
          directory,
        );
      assert.ok(
        !run("docker", ["ps", "-a", "--format", "{{.Names}}"], root)
          .split(/\r?\n/u)
          .some((name) => name.endsWith(`_${project}`)),
        `Upgrade cleanup left owned project ${project}.`,
      );
      // Remove the junction itself before recursively removing the owned temp
      // directory. The shared dependency target never belongs to this cleanup.
      await rm(path.join(directory, "node_modules"), { force: true });
    }
  }
  console.log(
    `Both divergent populated upgrades passed (${((performance.now() - started) / 1000).toFixed(1)}s).`,
  );
} finally {
  assert.equal(await realpath(workspace), ownedRoot);
  assert.ok(
    ownedRoot.startsWith(
      path.join(await realpath(tmpdir()), "planets-tw-stack01-upgrades-"),
    ),
  );
  await rm(workspace, { recursive: true, force: true });
}
