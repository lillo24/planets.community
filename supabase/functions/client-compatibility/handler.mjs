const version = /^(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})$/;
const build = /^(0|[1-9]\d{0,9})(\.(0|[1-9]\d{0,9})){0,2}$/;
const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function exactKeys(value, keys) {
  return (
    value &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.keys(value).length === keys.length &&
    keys.every((key) => Object.hasOwn(value, key))
  );
}

export function parsePolicy(source) {
  const policy = JSON.parse(source);
  if (
    !exactKeys(policy, ["schema_version", "android", "ios"]) ||
    policy.schema_version !== 1
  ) {
    throw new Error("Invalid client compatibility policy schema.");
  }
  for (const platform of ["android", "ios"]) {
    const entry = policy[platform];
    const keys = ["application_id", "minimum_version", "minimum_build"];
    if (platform === "ios") keys.push("app_store_id");
    if (
      !exactKeys(entry, keys) ||
      typeof entry.application_id !== "string" ||
      !/^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/.test(
        entry.application_id,
      ) ||
      typeof entry.minimum_version !== "string" ||
      !version.test(entry.minimum_version) ||
      typeof entry.minimum_build !== "string" ||
      !build.test(entry.minimum_build) ||
      (platform === "android" &&
        (entry.minimum_build.includes(".") ||
          Number(entry.minimum_build) > 2100000000))
    ) {
      throw new Error(`Invalid ${platform} client compatibility policy.`);
    }
    if (
      platform === "ios" &&
      entry.app_store_id !== null &&
      (typeof entry.app_store_id !== "string" ||
        !/^[1-9]\d{0,19}$/.test(entry.app_store_id))
    ) {
      throw new Error("Invalid App Store identifier.");
    }
    if (
      platform === "ios" &&
      entry.app_store_id === null &&
      (entry.minimum_version !== "0.0.0" || entry.minimum_build !== "0")
    ) {
      throw new Error(
        "An active iOS floor requires a verified App Store identifier.",
      );
    }
  }
  return policy;
}

// Public operational metadata only: no Auth, product data, database writes,
// provider requests or service key. Missing configuration is an explicit 503.
export function createHandler({ policySource }) {
  return async (request) => {
    const reply = (status, data) =>
      new Response(JSON.stringify(data), { status, headers });
    if (request.method === "OPTIONS")
      return new Response(null, { status: 204, headers });
    if (request.method !== "POST")
      return reply(405, { error: "method_not_allowed" });
    let input;
    try {
      // Bound streamed input too; Content-Length is not a trustworthy limit.
      const reader = request.body?.getReader();
      if (!reader) return reply(400, { error: "invalid_request" });
      const chunks = [];
      let size = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > 1024) {
          await reader.cancel();
          return reply(413, { error: "request_too_large" });
        }
        chunks.push(value);
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
      }
      input = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      );
    } catch {
      return reply(400, { error: "invalid_request" });
    }
    if (
      !exactKeys(input, ["platform", "application_id"]) ||
      !["android", "ios"].includes(input.platform)
    ) {
      return reply(400, { error: "invalid_request" });
    }
    let policy;
    try {
      policy = parsePolicy(policySource);
    } catch {
      return reply(503, { error: "compatibility_policy_unavailable" });
    }
    const entry = policy[input.platform];
    if (input.application_id !== entry.application_id) {
      return reply(409, { error: "unsupported_application" });
    }
    return reply(200, {
      schema_version: 1,
      platform: input.platform,
      application_id: entry.application_id,
      minimum_version: entry.minimum_version,
      minimum_build: entry.minimum_build,
      update_url:
        input.platform === "android"
          ? `https://play.google.com/store/apps/details?id=${entry.application_id}`
          : entry.app_store_id === null
            ? null
            : `https://apps.apple.com/app/id${entry.app_store_id}`,
    });
  };
}
