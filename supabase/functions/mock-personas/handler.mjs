const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const mock = "https://pnolarmzxmmjtguligfc.supabase.co";
const generation = "mock-world-2026-10-21-v1";

export class BrokerFailure extends Error {
  constructor(code, status = 503) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

export function createHandler({
  enabled,
  mockOrigin,
  rpc,
  issue,
  seal,
  open,
  revoke,
}) {
  const reply = (status, data) =>
    new Response(JSON.stringify(data), {
      status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
        Pragma: "no-cache",
      },
    });
  return async (request) => {
    try {
      if (!enabled || mockOrigin !== mock)
        throw new BrokerFailure("unavailable");
      if (request.method !== "POST")
        return reply(405, { error: "method_not_allowed" });
      // This is a deliberately public demo endpoint. Neither a normal nor a
      // persona bearer token is a client capability or an eligibility source.
      if (request.headers.has("authorization"))
        throw new BrokerFailure("invalid_client", 401);
      const text = await boundedText(request, 1024);
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        throw new BrokerFailure("invalid_request", 400);
      }
      if (!body || Array.isArray(body) || typeof body !== "object")
        throw new BrokerFailure("invalid_request", 400);
      const context = { project_ref: "pnolarmzxmmjtguligfc", generation };
      const digest = async (value) =>
        Array.from(
          new Uint8Array(
            await crypto.subtle.digest(
              "SHA-256",
              new TextEncoder().encode(value),
            ),
          ),
          (v) => v.toString(16).padStart(2, "0"),
        ).join("");
      if (body.action === "bootstrap" && Object.keys(body).length === 1) {
        const capability = Array.from(
          crypto.getRandomValues(new Uint8Array(32)),
          (v) => v.toString(16).padStart(2, "0"),
        ).join("");
        const id = await rpc("mock_control_client", {
          p_capability: await digest(capability),
        });
        if (!uuid.test(id)) throw new BrokerFailure("unavailable");
        return reply(200, { ...context, client_id: id, capability });
      }
      const capability = request.headers.get("x-mock-client");
      if (!capability || !/^[a-f0-9]{64}$/.test(capability))
        throw new BrokerFailure("invalid_client", 401);
      const hash = await digest(capability);
      const result = await rpc("mock_control_catalog", { p_capability: hash });
      const catalog = result?.personas;
      if (
        !uuid.test(result?.client_id) ||
        !Array.isArray(catalog) ||
        catalog.length > 12
      )
        throw new BrokerFailure("unavailable");
      context.client_id = result.client_id;
      if (body.action === "catalog" && Object.keys(body).length === 1) {
        return reply(200, { ...context, personas: catalog });
      }
      if (
        !["issue", "retire"].includes(body.action) ||
        Object.keys(body).sort().join(",") !==
          "action,persona_key,request_id" ||
        typeof body.persona_key !== "string" ||
        !/^[a-z]{2,20}$/.test(body.persona_key) ||
        !uuid.test(body.request_id)
      ) {
        throw new BrokerFailure("invalid_request", 400);
      }
      const args = {
        p_capability: hash,
        p_request: body.request_id,
      };
      if (body.action === "retire") {
        await rpc("mock_control_retire", {
          ...args,
          p_persona: body.persona_key,
        });
        return reply(200, { retired: true });
      }
      const persona = catalog.find((p) => p.key === body.persona_key);
      if (!persona) throw new BrokerFailure("persona_unavailable", 403);
      const claim = await rpc("mock_control_claim", {
        ...args,
        p_persona: persona.key,
      });
      if (claim.state === "replay")
        return reply(
          200,
          await open(
            claim.delivery,
            `${mock}/${generation}/${hash}/${body.request_id}/${persona.key}`,
          ),
        );
      if (claim.state !== "new")
        throw new BrokerFailure(
          claim.state === "pending" ? "pending" : "delivery_expired",
          409,
        );
      if (claim.user_id !== persona.user_id || claim.email !== persona.email)
        throw new BrokerFailure("persona_unavailable", 403);
      let session;
      try {
        session = await issue(persona);
        if (
          session.user_id !== persona.user_id ||
          !uuid.test(session.session_id)
        )
          throw new BrokerFailure("persona_unavailable", 403);
        const delivery = {
          ...context,
          persona_key: persona.key,
          user_id: persona.user_id,
          request_id: body.request_id,
          access_token: session.access_token,
          refresh_token: session.refresh_token,
        };
        const encrypted = await seal(
          delivery,
          `${mock}/${generation}/${hash}/${body.request_id}/${persona.key}`,
        );
        // Record before returning secrets. Finish and shutdown serialize on the
        // environment row; a disabled service cannot complete a fresh delivery.
        await rpc("mock_control_finish", {
          ...args,
          p_session: session.session_id,
          p_delivery: encrypted,
        });
        return reply(200, delivery);
      } catch (error) {
        if (session?.session_id)
          await revoke(session.session_id, persona.user_id);
        await rpc("mock_control_retire", { ...args, p_persona: persona.key });
        throw error;
      }
    } catch (error) {
      // Public process boundary: no provider bodies, secrets or exception text.
      return reply(error instanceof BrokerFailure ? error.status : 503, {
        error: error instanceof BrokerFailure ? error.code : "unavailable",
      });
    }
  };
}

export async function boundedText(source, maximum) {
  if (Number(source.headers.get("content-length") ?? 0) > maximum)
    throw new BrokerFailure("invalid_request", 413);
  const reader = source.body?.getReader();
  if (!reader) throw new BrokerFailure("invalid_request", 400);
  let size = 0;
  const chunks = [];
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maximum) {
        await reader.cancel();
        throw new BrokerFailure("invalid_request", 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}
