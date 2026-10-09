// @vitest-environment node
import { describe, expect, it } from "vitest";
import {
  distribution,
  probeCases,
  rscDestination,
  summarizeProfile,
  localOrigin,
  hostedOrigin,
} from "./worker-cpu-lib.mjs";

describe("staging CPU measurements", () => {
  it("counts non-idle sample deltas, including GC, rather than the wall window", () => {
    const profile = {
      startTime: 0,
      endTime: 1_000_000,
      nodes: [
        { id: 1, callFrame: { functionName: "render", url: "index.js" } },
        { id: 2, callFrame: { functionName: "(idle)", url: "" } },
        { id: 3, callFrame: { functionName: "(garbage collector)", url: "" } },
        { id: 4, callFrame: { functionName: "(program)", url: "" } },
      ],
      samples: [1, 2, 3, 4],
      timeDeltas: [2000, 80000, 1000, 3000],
    };
    expect(summarizeProfile(profile)).toMatchObject({
      activeMs: 6,
      idleMs: 80,
      gcMs: 1,
      unattributedMs: 3,
      longGaps: 1,
    });
    expect(() => summarizeProfile({ ...profile, samples: [999] })).toThrow();
    expect(() =>
      summarizeProfile({ ...profile, samples: [999], timeDeltas: [1000] }),
    ).toThrow();
  });

  it("reports sparse and empty samples without invented percentiles", () => {
    expect(distribution([])).toEqual({
      n: 0,
      errors: 0,
      p50: null,
      p95: null,
      max: null,
    });
    expect(
      distribution([
        { activeMs: 1, error: false },
        { activeMs: 30, error: true },
      ]),
    ).toEqual({ n: 2, errors: 1, p50: 1, p95: 30, max: 30 });
  });

  it("allows only the generated same-origin RSC transport redirect", () => {
    for (const origin of [localOrigin, hostedOrigin]) {
      expect(rscDestination(origin, "/proposals?_rsc=synthetic")).toBe(
        "/proposals?_rsc=synthetic",
      );
      for (const destination of [
        "https://evil.invalid/proposals?_rsc=x",
        "/join/project/a-real-capability",
        "/proposals?_rsc=x&token=x",
        "/proposals?_rsc=x&_rsc=y",
        "/proposals?_rsc=x#secret",
      ])
        expect(() => rscDestination(origin, destination)).toThrow();
    }
    expect(() =>
      rscDestination("https://planets.community", "/proposals?_rsc=x"),
    ).toThrow();
  });

  it("rejects arbitrary asset URLs and keeps invitation probes non-secret", () => {
    const cases = probeCases("/_next/static/index-synthetic.js");
    expect(cases.find((c) => c.name === "malformed-invite")?.path).toBe(
      "/join/project/invalid-public-probe",
    );
    for (const asset of [
      "https://planets.community/_next/static/x.js",
      "/join/project/token",
      "/_next/static/x.js?token=x",
      "/_next/static/../../join/project/token",
    ])
      expect(() => probeCases(asset)).toThrow();
  });
});
