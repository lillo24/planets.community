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
      androidAssetLinksResponse({
        PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "bad identity",
        PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: fingerprint,
      }),
      androidAssetLinksResponse({
        PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "community.planets.mobile",
        PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: "AB:CD",
      }),
      appleAppSiteAssociationResponse({
        PLANETS_IOS_TEAM_ID: "short",
        PLANETS_IOS_BUNDLE_ID: "community.planets.mobile",
      }),
      appleAppSiteAssociationResponse({
        PLANETS_IOS_TEAM_ID: "ABCDE12345",
        PLANETS_IOS_BUNDLE_ID: "bad identity",
      }),
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

  it("emits bounded Apple paths with effective positive/negative matching", async () => {
    const response = appleAppSiteAssociationResponse({
      PLANETS_IOS_TEAM_ID: "ABCDE12345",
      PLANETS_IOS_BUNDLE_ID: "community.planets.mobile",
    });
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toMatch("application/json");
    expect(response.headers.get("cache-control")).toBe(
      "public, max-age=300, s-maxage=300",
    );
    const body = await response.json();
    expect(body.applinks.apps).toEqual([]);
    expect(body.applinks.details).toHaveLength(1);
    expect(body.applinks.details[0].appID).toBe(
      "ABCDE12345.community.planets.mobile",
    );
    const paths: string[] = body.applinks.details[0].paths;
    function claimed(path: string) {
      // Apple legacy paths are ordered full-path globs; queries are ignored.
      for (const entry of paths) {
        const negative = entry.startsWith("NOT ");
        const pattern = (negative ? entry.slice(4) : entry)
          .split("")
          .map((c) =>
            c === "*"
              ? ".*"
              : c === "?"
                ? "."
                : c.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"),
          )
          .join("");
        if (new RegExp(`^${pattern}$`, "u").test(path.split("?")[0]))
          return !negative;
      }
      return false;
    }
    const id = "fb040000-0000-4000-8000-000000000002";
    for (const path of [
      `/invite/project/${"A".repeat(43)}`,
      `/join/project/${"A".repeat(43)}`,
      `/proposals/${id}`,
      `/tavoli/${id}`,
    ]) {
      expect(claimed(path)).toBe(true);
      expect(claimed(`${path}?intent=join`)).toBe(true);
      expect(claimed(`${path}/edit`)).toBe(false);
      expect(claimed(`${path}/`)).toBe(false);
    }
    for (const path of [
      "/",
      "/auth",
      "/profile",
      "/admin",
      "/api/waitlist",
      "/_next/static/app.js",
      `/joined/tavoli/${id}`,
      "/proposals/mine",
      "/proposals/invalid",
      "/join/project/short",
      `/join/project/${"A".repeat(40)}/xx`,
    ])
      expect(claimed(path)).toBe(false);
    // Same-length invalid characters can match globs; Flutter validates them.
    expect(
      claimed(`/proposals/${"x".repeat(8)}-xxxx-xxxx-xxxx-${"x".repeat(12)}`),
    ).toBe(true);
  });

  it("normalizes/deduplicates fingerprints and ignores malformed entries", async () => {
    const response = androidAssetLinksResponse({
      PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "community.planets.mobile",
      PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: `${fingerprint.toLowerCase()}, broken, ${fingerprint}`,
    });
    expect((await response.json())[0].target.sha256_cert_fingerprints).toEqual([
      fingerprint,
    ]);
    expect(response.headers.get("cache-control")).toBe(
      "public, max-age=300, s-maxage=300",
    );
  });
});
