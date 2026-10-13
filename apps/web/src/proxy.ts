import { NextResponse, type NextRequest } from "next/server";

import { updateSupabaseSession } from "@/features/auth/update-session";

export async function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  if (
    (path.startsWith("/join/group") || path.startsWith("/invite/group")) &&
    (!/^\/(join|invite)\/group\/[A-Za-z0-9_-]{43}$/u.test(path) ||
      request.nextUrl.search)
  ) {
    return new NextResponse("Invitation unavailable.", {
      status: 404,
      headers: {
        "Cache-Control": "private, no-store",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      },
    });
  }
  if (
    [
      "/.well-known/assetlinks.json",
      "/.well-known/apple-app-site-association",
    ].includes(request.nextUrl.pathname)
  ) {
    // Verification must reach its response owner without Auth refresh/cookies.
    return NextResponse.next();
  }
  return updateSupabaseSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
