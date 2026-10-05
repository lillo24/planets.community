// @vitest-environment node
import { createServer, type Server } from "node:http";
import { afterEach, expect, it } from "vitest";
import {
  createPublicHostHarness,
  publicPathOwner,
} from "./public-host-harness";

const servers: Server[] = [];
afterEach(async () => {
  await Promise.all(
    servers.map(
      (s) => new Promise<void>((resolve) => s.close(() => resolve())),
    ),
  );
  servers.length = 0;
});
async function listen(server: Server): Promise<string> {
  servers.push(server);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (!address || typeof address === "string")
    throw new Error("Missing test listener.");
  return `http://127.0.0.1:${address.port}`;
}

it("owns dynamic namespaces, transport, verification and unknown descendants before Site assets", () => {
  for (const path of [
    "/join/project/invalid",
    "/invite/project/invalid",
    "/proposals",
    "/proposals/id",
    "/proposals/id?intent=join",
    "/tavoli/id",
    "/auth",
    "/profile",
    "/joined/tavoli/id",
    "/admin/cases/id",
    "/_next/static/app.js",
    "/.well-known/assetlinks.json",
    "/.well-known/apple-app-site-association",
    "/join/unknown",
  ]) {
    expect(publicPathOwner(path)).toBe("web");
  }
  for (const path of [
    "/",
    "/assets/index.js",
    "/api/waitlist",
    "/api/unknown",
    "/unknown",
  ])
    expect(publicPathOwner(path)).toBe("site");
});

it("preserves methods, queries, cookies, RSC/prefetch/POST and multiple Set-Cookie; never masks disabled 404", async () => {
  const requests: {
    url?: string;
    method?: string;
    cookie?: string;
    body: string;
    rsc?: string;
    prefetch?: string;
  }[] = [];
  let siteCalls = 0;
  const webOrigin = await listen(
    createServer(async (req, res) => {
      let body = "";
      for await (const chunk of req) body += chunk;
      requests.push({
        url: req.url,
        method: req.method,
        cookie: req.headers.cookie,
        body,
        rsc: req.headers.rsc as string,
        prefetch: req.headers["next-router-prefetch"] as string,
      });
      res.writeHead(req.url?.startsWith("/.well-known/") ? 404 : 201, {
        "Content-Type": req.headers.rsc
          ? "text/x-component"
          : "application/json",
        "Set-Cookie": [
          "session=a; Path=/; HttpOnly",
          "refresh=b; Path=/; HttpOnly",
        ],
        "Cache-Control": "private, no-store",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      });
      res.end("upstream body");
    }),
  );
  const siteOrigin = await listen(
    createServer((_, res) => {
      siteCalls++;
      res.end("Site");
    }),
  );
  // Reserve port before constructing the origin-bound harness.
  const reservation = createServer();
  const publicOrigin = await listen(reservation);
  await new Promise<void>((resolve) => reservation.close(() => resolve()));
  const harness = createPublicHostHarness({
    publicOrigin,
    webOrigin,
    siteOrigin,
  });
  servers.push(harness);
  await new Promise<void>((resolve) =>
    harness.listen(Number(new URL(publicOrigin).port), "127.0.0.1", resolve),
  );
  for (const method of ["GET", "POST"]) {
    const response = await fetch(
      `${publicOrigin}/proposals/id?intent=join&intent=join&_rsc=probe`,
      {
        method,
        headers: {
          Cookie: "session=input",
          RSC: "1",
          "Next-Router-Prefetch": "1",
          Origin: publicOrigin,
        },
        body: method === "POST" ? "action=probe" : undefined,
        redirect: "manual",
      },
    );
    expect(response.status).toBe(201);
    expect(response.headers.get("content-type")).toBe("text/x-component");
    expect(response.headers.getSetCookie()).toHaveLength(2);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("x-robots-tag")).toContain("noindex");
    expect(await response.text()).toBe("upstream body");
  }
  expect(requests[1]).toMatchObject({
    method: "POST",
    url: "/proposals/id?intent=join&intent=join&_rsc=probe",
    cookie: "session=input",
    body: "action=probe",
    rsc: "1",
    prefetch: "1",
  });
  const disabled = await fetch(`${publicOrigin}/.well-known/assetlinks.json`);
  expect(disabled.status).toBe(404);
  expect(siteCalls).toBe(0);
  for (const headers of [
    { "X-Forwarded-Host": "attacker.example" },
    { Origin: "https://attacker.example" },
  ] as Record<string, string>[]) {
    expect((await fetch(`${publicOrigin}/auth`, { headers })).status).toBe(400);
  }
  expect((await fetch(`${publicOrigin}/join%2fproject/invalid`)).status).toBe(
    400,
  );
  await fetch(`${publicOrigin}/api/waitlist`, { method: "POST" });
  expect(siteCalls).toBe(1);
});
