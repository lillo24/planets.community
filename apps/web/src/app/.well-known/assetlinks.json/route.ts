import { androidAssetLinksResponse } from "@/features/deep-links/association-responses";

export const dynamic = "force-dynamic";

export function GET(): Response {
  return androidAssetLinksResponse();
}

export function HEAD(): Response {
  const response = androidAssetLinksResponse();
  return new Response(null, {
    status: response.status,
    headers: response.headers,
  });
}
