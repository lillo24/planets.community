import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
export const accountId = "5e9cf144fb13c9913f8570b32d7288a8";
export const workerName = "planets-link-host03-static-staging";
export const hostedOrigin = `https://${workerName}.developer-planets-community.workers.dev`;
export function cloudflareToken() {
  const token =
    process.env.CLOUDFLARE_API_TOKEN ||
    readFileSync(
      resolve(process.env.APPDATA, "xdg.config/.wrangler/config/default.toml"),
      "utf8",
    ).match(/oauth_token\s*=\s*"([^"]+)"/)?.[1];
  assert(token, "Use existing Wrangler OAuth or CLOUDFLARE_API_TOKEN.");
  return token;
}
export async function cloudflare(path, init = {}) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}${path}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${cloudflareToken()}`,
        ...init.headers,
      },
    },
  );
  const data = await response.json();
  return { status: response.status, data };
}
export async function currentVersion() {
  const { status, data } = await cloudflare(
    `/workers/scripts/${workerName}/deployments`,
  );
  assert.equal(status, 200, "Trial deployment metadata unavailable.");
  const versions = data.result.deployments[0].versions;
  assert(
    versions.length === 1 && versions[0].percentage === 100,
    "Expected one fully deployed trial version.",
  );
  return versions[0].version_id;
}
