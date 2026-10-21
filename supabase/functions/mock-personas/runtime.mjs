import { BrokerFailure, boundedText, createHandler } from "./handler.mjs";
const mock = "https://pnolarmzxmmjtguligfc.supabase.co";
export function createRuntime({
  service,
  deliveryKey,
  enabled,
  mockOrigin,
  fetcher = fetch,
}) {
  async function json(url, key, authorization, body, method) {
    const response = await fetcher(url, {
      method: method ?? (body === undefined ? "GET" : "POST"),
      redirect: "error",
      signal: AbortSignal.timeout(10000),
      headers: {
        apikey: key,
        Authorization: authorization,
        "Content-Type": "application/json",
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    // PostgREST returns 204 for void control RPCs. Empty success is a valid
    // transport result here; it is not an absent broker session/delivery.
    const text =
      response.status === 204 ? "" : await boundedText(response, 32768);
    const result = text ? JSON.parse(text) : null;
    if (!response.ok)
      throw new BrokerFailure(
        [401, 403].includes(response.status) || result?.code === "42501"
          ? "denied"
          : result?.code === "PT409"
            ? "request_conflict"
            : result?.code === "PT429"
              ? "rate_limited"
              : "unavailable",
        [401, 403].includes(response.status) || result?.code === "42501"
          ? 403
          : result?.code === "PT409"
            ? 409
            : result?.code === "PT429"
              ? 429
              : 503,
      );
    return result;
  }
  const rpc = (name, args) =>
    json(`${mock}/rest/v1/rpc/${name}`, service, `Bearer ${service}`, args);
  const auth = (path, body) =>
    json(`${mock}/auth/v1/${path}`, service, `Bearer ${service}`, body);

  async function cryptKey() {
    const bytes = Uint8Array.from(atob(deliveryKey), (c) => c.charCodeAt(0));
    if (bytes.length !== 32) throw new BrokerFailure("unavailable");
    return crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
      "encrypt",
      "decrypt",
    ]);
  }
  const encode = (bytes) => btoa(String.fromCharCode(...bytes));
  const decode = (value) =>
    Uint8Array.from(atob(value), (c) => c.charCodeAt(0));

  return createHandler({
    enabled:
      enabled && Boolean(service) && /^[A-Za-z0-9+/]{43}=$/.test(deliveryKey),
    mockOrigin,
    rpc,
    issue: async (persona) => {
      // Independent request-scoped REST calls have no shared mutable Auth client.
      const user = await auth(`admin/users/${persona.user_id}`);
      if (
        user.id !== persona.user_id ||
        user.email !== persona.email ||
        user.role !== "authenticated"
      )
        throw new BrokerFailure("persona_unavailable", 403);
      const link = await auth("admin/generate_link", {
        type: "magiclink",
        email: persona.email,
      });
      if (link.id !== persona.user_id || !link.hashed_token)
        throw new BrokerFailure("persona_unavailable", 403);
      const session = await auth("verify", {
        type: "magiclink",
        token_hash: link.hashed_token,
      });
      if (session.user?.id !== persona.user_id)
        throw new BrokerFailure("persona_unavailable", 403);
      // This is the just-issued server response, verified again against Auth /user;
      // decoding session_id here is not verification of an untrusted client JWT.
      const verified = await json(
        `${mock}/auth/v1/user`,
        service,
        `Bearer ${session.access_token}`,
      );
      if (verified.id !== persona.user_id || verified.role !== "authenticated")
        throw new BrokerFailure("persona_unavailable", 403);
      const segment = session.access_token
        .split(".")[1]
        .replaceAll("-", "+")
        .replaceAll("_", "/");
      return {
        user_id: verified.id,
        session_id: JSON.parse(atob(segment)).session_id,
        access_token: session.access_token,
        refresh_token: session.refresh_token,
      };
    },
    revoke: (session, user) =>
      rpc("mock_control_retire_candidate", {
        p_session: session,
        p_user: user,
      }),
    seal: async (data, binding) => {
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const encrypted = await crypto.subtle.encrypt(
        {
          name: "AES-GCM",
          iv,
          additionalData: new TextEncoder().encode(binding),
        },
        await cryptKey(),
        new TextEncoder().encode(JSON.stringify(data)),
      );
      return `${encode(iv)}.${encode(new Uint8Array(encrypted))}`;
    },
    open: async (value, binding) => {
      const [iv, data] = value.split(".");
      const bytes = await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: decode(iv),
          additionalData: new TextEncoder().encode(binding),
        },
        await cryptKey(),
        decode(data),
      );
      return JSON.parse(new TextDecoder().decode(bytes));
    },
  });
}
