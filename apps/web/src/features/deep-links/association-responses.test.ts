import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  androidAssetLinksResponse,
  appleAppSiteAssociationResponse,
} from "./association-responses";

const fingerprint = Array.from({ length: 32 }, () => "AB").join(":");

describe("native link association responses", () => {
  it("fails closed when final identities are absent or bootstrap values remain", async () => {
    for (const response of [
      androidAssetLinksResponse({}),
      androidAssetLinksResponse({
        PLANETS_ANDROID_APP_LINK_PACKAGE_ID:
          "community.planets.bootstrap.planets_mobile",
        PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: fingerprint,
      }),
      appleAppSiteAssociationResponse({}),
      appleAppSiteAssociationResponse({
        PLANETS_IOS_TEAM_ID: "ABCDE12345",
        PLANETS_IOS_BUNDLE_ID: "community.planets.bootstrap.planetsMobile",
      }),
    ]) {
      expect(response.status).toBe(404);
      expect(response.headers.get("cache-control")).toBe("no-store");
      await expect(response.json()).resolves.toEqual({
        error: "association_not_configured",
      });
    }
  });

  it("emits a scoped Android Digital Asset Links payload", async () => {
    const response = androidAssetLinksResponse({
      PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "community.planets.mobile",
      PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: fingerprint,
    });
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toMatch("application/json");
    await expect(response.json()).resolves.toEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "community.planets.mobile",
          sha256_cert_fingerprints: [fingerprint],
        },
      },
    ]);
  });

  it("emits an invite-only Apple association payload", async () => {
    const response = appleAppSiteAssociationResponse({
      PLANETS_IOS_TEAM_ID: "ABCDE12345",
      PLANETS_IOS_BUNDLE_ID: "community.planets.mobile",
    });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      applinks: {
        apps: [],
        details: [
          {
            appID: "ABCDE12345.community.planets.mobile",
            paths: ["/invite/project/*"],
          },
        ],
      },
    });
  });
});
