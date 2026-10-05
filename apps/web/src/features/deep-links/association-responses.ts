import "server-only";

type AssociationEnvironment = Readonly<Record<string, string | undefined>>;

const jsonHeaders = Object.freeze({
  "Content-Type": "application/json; charset=utf-8",
  "X-Content-Type-Options": "nosniff",
});

export function androidAssetLinksResponse(
  environment: AssociationEnvironment = process.env,
): Response {
  const packageId = environment.PLANETS_ANDROID_APP_LINK_PACKAGE_ID?.trim();
  const fingerprints = parseFingerprints(
    environment.PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS,
  );
  if (!isProductionPackageId(packageId) || fingerprints.length === 0) {
    return disabledResponse();
  }

  return configuredResponse([
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: packageId,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ]);
}

export function appleAppSiteAssociationResponse(
  environment: AssociationEnvironment = process.env,
): Response {
  const teamId = environment.PLANETS_IOS_TEAM_ID?.trim();
  const bundleId = environment.PLANETS_IOS_BUNDLE_ID?.trim();
  if (!isTeamId(teamId) || !isProductionBundleId(bundleId)) {
    return disabledResponse();
  }

  return configuredResponse({
    applinks: {
      apps: [],
      details: [
        {
          appID: `${teamId}.${bundleId}`,
          // Ordered legacy paths remain supported by the minimum iOS 15 target.
          // Exclude descendants before fixed-length globs (not UUID validation).
          // Queries are ignored by AASA matching and preserved for Flutter.
          paths: [
            ...[
              "/invite/project",
              "/join/project",
              "/proposals",
              "/tavoli",
            ].map((prefix) => `NOT ${prefix}/*/*`),
            `/invite/project/${"?".repeat(43)}`,
            `/join/project/${"?".repeat(43)}`,
            `/proposals/${"????????-????-????-????-????????????"}`,
            `/tavoli/${"????????-????-????-????-????????????"}`,
          ],
        },
      ],
    },
  });
}

function configuredResponse(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: {
      ...jsonHeaders,
      "Cache-Control": "public, max-age=300, s-maxage=300",
    },
  });
}

function disabledResponse(): Response {
  return new Response(JSON.stringify({ error: "association_not_configured" }), {
    status: 404,
    headers: { ...jsonHeaders, "Cache-Control": "no-store" },
  });
}

function parseFingerprints(value: string | undefined): string[] {
  if (!value) return [];
  const fingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/u;
  return [
    ...new Set(value.split(",").map((item) => item.trim().toUpperCase())),
  ].filter((item) => fingerprintPattern.test(item));
}

function isProductionPackageId(value: string | undefined): value is string {
  return (
    value !== undefined &&
    !value.toLowerCase().includes(".bootstrap.") &&
    /^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/u.test(value)
  );
}

function isProductionBundleId(value: string | undefined): value is string {
  return isProductionPackageId(value);
}

function isTeamId(value: string | undefined): value is string {
  return value !== undefined && /^[A-Z0-9]{10}$/u.test(value);
}
