// Routes run before the existing Site Custom Domain. Only these paths belong
// to the dynamic app; a prefix Route match outside them returns to Site.
export function isWebPath(path: string): boolean {
  return (
    ["auth", "profile", "admin", "proposals", "tavoli", "_next"].some(
      (name) => path === `/${name}` || path.startsWith(`/${name}/`),
    ) ||
    [
      "/join/project/",
      "/invite/project/",
      "/joined/proposals/",
      "/joined/tavoli/",
    ].some((prefix) => path.startsWith(prefix)) ||
    [
      "/.well-known/assetlinks.json",
      "/.well-known/apple-app-site-association",
    ].includes(path)
  );
}

export function prepareWebRequest(
  request: Request,
  allowedOrigins: readonly string[],
): Request | Response {
  const url = new URL(request.url);
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");
  if (
    !allowedOrigins.includes(url.origin) ||
    (host !== null && host !== url.host) ||
    (origin !== null && origin !== url.origin)
  ) {
    return new Response("Invalid web ingress request.", {
      status: 400,
      headers: {
        "Cache-Control": "private, no-store, max-age=0",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      },
    });
  }
  const headers = new Headers(request.headers);
  for (const name of [...headers.keys()]) {
    if (name === "forwarded" || name.startsWith("x-forwarded-"))
      headers.delete(name);
  }
  // Derive the advertised origin only from the validated request URL.
  headers.set("host", url.host);
  headers.set("x-forwarded-host", url.host);
  headers.set("x-forwarded-proto", url.protocol.slice(0, -1));
  return new Request(request, { headers });
}

export function protectWebResponse(response: Response, path: string): Response {
  if (!/^\/(?:join|invite|joined|auth|profile|admin)(?:\/|$)/u.test(path))
    return response;
  const headers = new Headers(response.headers);
  headers.set("Cache-Control", "private, no-store, max-age=0");
  headers.set("Referrer-Policy", "no-referrer");
  headers.set("X-Robots-Tag", "noindex, nofollow, noarchive");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
