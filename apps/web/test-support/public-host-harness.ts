// Disposable local contract rehearsal, not approved production infrastructure.
import { createServer, request, type IncomingHttpHeaders } from "node:http";
import { pathToFileURL } from "node:url";

const webNamespaces = [
  "proposals",
  "tavoli",
  "join",
  "invite",
  "joined",
  "auth",
  "profile",
  "admin",
  "_next",
  ".well-known",
];
const hopHeaders = [
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
];

export function publicPathOwner(path: string): "web" | "site" {
  return webNamespaces.includes(path.split("/")[1]) ? "web" : "site";
}

function localOrigin(value: string): URL {
  const url = new URL(value);
  if (
    url.protocol !== "http:" ||
    !["127.0.0.1", "localhost"].includes(url.hostname) ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    throw new Error("PI04 harness requires explicit loopback HTTP origins.");
  }
  return url;
}

function endToEndHeaders(headers: IncomingHttpHeaders): IncomingHttpHeaders {
  const copy = { ...headers };
  const names = [
    ...hopHeaders,
    ...(headers.connection?.split(",").map((h) => h.trim().toLowerCase()) ??
      []),
  ];
  names.forEach((name) => delete copy[name]);
  return copy;
}

export function createPublicHostHarness(config: {
  publicOrigin: string;
  webOrigin: string;
  siteOrigin: string;
}) {
  const publicUrl = localOrigin(config.publicOrigin);
  const web = localOrigin(config.webOrigin);
  const site = localOrigin(config.siteOrigin);
  if (new Set([publicUrl.origin, web.origin, site.origin]).size !== 3) {
    throw new Error("PI04 harness requires three distinct origins.");
  }
  return createServer((incoming, outgoing) => {
    const target = incoming.url ?? "";
    // Never print requests/errors: capabilities may be in the path or encoded query.
    // This single-hop rehearsal rejects client-supplied forwarding metadata rather
    // than allowing it to choose a redirect/cookie origin.
    if (
      !target.startsWith("/") ||
      target.startsWith("//") ||
      target.includes("\\") ||
      /%(?:2f|5c|2e|25)/iu.test(target.split("?")[0]) ||
      incoming.headers.host !== publicUrl.host ||
      Object.keys(incoming.headers).some(
        (h) => h === "forwarded" || h.startsWith("x-forwarded-"),
      ) ||
      (incoming.headers.origin && incoming.headers.origin !== publicUrl.origin)
    ) {
      outgoing.writeHead(400, { "Cache-Control": "no-store" });
      outgoing.end("Invalid local ingress request.");
      return;
    }
    const path = target.split("?")[0];
    const owner = publicPathOwner(path);
    const upstream = owner === "web" ? web : site;
    const headers = endToEndHeaders(incoming.headers);
    headers.host = publicUrl.host;
    headers["x-forwarded-host"] = publicUrl.host;
    headers["x-forwarded-proto"] = "http";
    const proxy = request(
      {
        hostname: upstream.hostname,
        port: upstream.port,
        method: incoming.method,
        path: target,
        headers,
      },
      (response) => {
        // Node retains Set-Cookie as an array: no comma folding, redirect following,
        // body transforms, cache, or static fallback (including upstream 404).
        outgoing.writeHead(
          response.statusCode ?? 502,
          endToEndHeaders(response.headers),
        );
        response.pipe(outgoing);
      },
    );
    proxy.on("error", () => {
      if (!outgoing.headersSent) {
        outgoing.writeHead(502, { "Cache-Control": "no-store" });
        outgoing.end("Local upstream unavailable.");
      } else outgoing.destroy();
    });
    incoming.on("aborted", () => proxy.destroy());
    incoming.pipe(proxy);
  });
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const { PI04_PUBLIC_ORIGIN, PI04_WEB_ORIGIN, PI04_SITE_ORIGIN } = process.env;
  if (!PI04_PUBLIC_ORIGIN || !PI04_WEB_ORIGIN || !PI04_SITE_ORIGIN) {
    throw new Error(
      "Set PI04_PUBLIC_ORIGIN, PI04_WEB_ORIGIN and PI04_SITE_ORIGIN.",
    );
  }
  const origin = localOrigin(PI04_PUBLIC_ORIGIN);
  createPublicHostHarness({
    publicOrigin: origin.origin,
    webOrigin: PI04_WEB_ORIGIN,
    siteOrigin: PI04_SITE_ORIGIN,
  }).listen(Number(origin.port), origin.hostname, () => {
    console.log(
      "PI04 local public-origin harness ready (request logging disabled).",
    );
  });
}
