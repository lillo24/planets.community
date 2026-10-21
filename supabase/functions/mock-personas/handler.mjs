const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const normal = "https://cllpvruvrrvxczjitlqd.supabase.co";
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
  normalOrigin,
  mockOrigin,
  authenticate,
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
      if (!enabled || normalOrigin !== normal || mockOrigin !== mock)
        throw new BrokerFailure("unavailable");
      if (request.method !== "POST")
        return reply(405, { error: "method_not_allowed" });
      const authorization = request.headers.get("authorization");
      if (!authorization?.startsWith("Bearer ") || authorization.length > 8192)
        throw new BrokerFailure("unauthorized", 401);
      // Auth /user on the fixed NORMAL origin validates the signature and current
      // user. Decoded client claims are never an entitlement source.
      const tester = await authenticate(authorization);
      if (!tester || !uuid.test(tester.id))
        throw new BrokerFailure("unauthorized", 401);
      const text = await boundedText(request, 1024);
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        throw new BrokerFailure("invalid_request", 400);
      }
      if (!body || Array.isArray(body) || typeof body !== "object")
        throw new BrokerFailure("invalid_request", 400);
      const issuer = `${normal}/auth/v1`;
      // Every action, including recovery/retirement, checks current enrollment.
      const catalog = await rpc("mock_control_catalog", {
        p_issuer: issuer,
        p_tester: tester.id,
      });
      if (!Array.isArray(catalog) || catalog.length > 12)
        throw new BrokerFailure("unavailable");
      const context = { project_ref: "pnolarmzxmmjtguligfc", generation };
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
        p_issuer: issuer,
        p_tester: tester.id,
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
            `${tester.id}/${body.request_id}/${persona.key}`,
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
          `${tester.id}/${body.request_id}/${persona.key}`,
        );
        // Record before returning secrets. Offboard and finish serialize on the
        // tester row; a revoked tester can never complete a delivery.
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
