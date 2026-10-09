import { trialRoute } from "./routes";

type Assets = { fetch(request: Request): Promise<Response> };
const privacy = {
  "Cache-Control": "private, no-store",
  "Referrer-Policy": "no-referrer",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
};
const worker = {
  async fetch(request: Request, env: { ASSETS: Assets }) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD")
      return new Response("Method not allowed", {
        status: 405,
        headers: { ...privacy, Allow: "GET, HEAD" },
      });
    const route = trialRoute(url.pathname);
    // No blanket SPA fallback: authority, well-known, API, public discovery,
    // admin, malformed paths and direct index.html are genuinely unavailable.
    if (!route)
      return new Response(request.method === "HEAD" ? null : "Not found", {
        status: 404,
        headers: privacy,
      });
    const assetUrl = new URL("/index.html", url.origin);
    const asset = await env.ASSETS.fetch(
      new Request(assetUrl, { method: request.method }),
    );
    const headers = new Headers(asset.headers);
    for (const [key, value] of Object.entries(privacy)) headers.set(key, value);
    headers.delete("Set-Cookie");
    return new Response(asset.body, { status: asset.status, headers });
  },
};
export default worker;
