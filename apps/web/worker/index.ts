import app from "vinext/server/app-router-entry";
import * as android from "../src/app/.well-known/assetlinks.json/route";
import * as apple from "../src/app/.well-known/apple-app-site-association/route";
import { isWebPath, prepareWebRequest, protectWebResponse } from "./ingress";

const stagingOrigin =
  "https://planets-web-link-host01-staging.developer-planets-community.workers.dev";
const canonicalOrigin = "https://planets.community";

const worker = {
  async fetch(...args: Parameters<typeof app.fetch>) {
    const [incoming, env, ctx] = args;
    const prepared = prepareWebRequest(incoming, [
      stagingOrigin,
      canonicalOrigin,
      "http://127.0.0.1:8796",
    ]);
    if (prepared instanceof Response) return prepared;
    const url = new URL(prepared.url);
    if (url.origin === canonicalOrigin && !isWebPath(url.pathname)) {
      // The existing Site Custom Domain is the origin behind these Routes.
      // This never fetches another Route or a workers.dev URL in the same zone.
      return fetch(prepared);
    }
    const association =
      url.pathname === "/.well-known/assetlinks.json"
        ? android
        : url.pathname === "/.well-known/apple-app-site-association"
          ? apple
          : null;
    // vinext 1.0.1 omits hidden .well-known directories during route discovery.
    // Reuse the canonical Next handlers directly, including their HEAD contract.
    if (association) {
      if (prepared.method === "GET") return association.GET();
      if (prepared.method === "HEAD") return association.HEAD();
      return new Response(null, {
        status: 405,
        headers: { Allow: "GET, HEAD", "Cache-Control": "no-store" },
      });
    }
    return protectWebResponse(
      await app.fetch(prepared, env, ctx),
      url.pathname,
    );
  },
};

export default worker;
