import { NextResponse, type NextRequest } from "next/server";

import { updateSupabaseSession } from "@/features/auth/update-session";

export async function proxy(request: NextRequest) {
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
