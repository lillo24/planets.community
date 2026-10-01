import { appleAppSiteAssociationResponse } from "@/features/deep-links/association-responses";

export const dynamic = "force-dynamic";

export function GET(): Response {
  return appleAppSiteAssociationResponse();
}

export function HEAD(): Response {
  const response = appleAppSiteAssociationResponse();
  return new Response(null, {
    status: response.status,
    headers: response.headers,
  });
}
