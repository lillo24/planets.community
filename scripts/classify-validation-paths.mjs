import { appendFileSync, readFileSync } from "node:fs";

import { classifyValidationPaths } from "./lib/validation-paths.mjs";

const { forceAll, githubOutputPath } = parseArguments(process.argv.slice(2));
const paths = forceAll ? [] : readChangedPaths(readFileSync(0));
const areas = classifyValidationPaths(paths, { forceAll });
const output = Object.entries(areas)
  .map(([area, enabled]) => `${area}=${enabled}`)
  .join("\n");

appendFileSync(githubOutputPath, `${output}\n`, "utf8");
process.stdout.write(
  `${forceAll ? "Manual full validation" : `${paths.length} changed path(s)`}: ${output.replaceAll("\n", ", ")}\n`,
);

function parseArguments(argumentsList) {
  let forceAll = false;
  let githubOutputPath;

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--all") {
      forceAll = true;
      continue;
    }
    if (argument === "--github-output") {
      githubOutputPath = argumentsList[index + 1];
      index += 1;
      continue;
    }
    throw new Error(`Unknown argument: ${argument}`);
  }

  if (!githubOutputPath) {
    throw new Error("--github-output requires the GitHub output file path.");
  }

  return { forceAll, githubOutputPath };
}

function readChangedPaths(input) {
  if (input.length === 0) {
    return [];
  }

  return input
    .toString("utf8")
    .split("\0")
    .filter((path) => path.length > 0);
}
