import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const styles = readFileSync(new URL("./styles.css", import.meta.url), "utf8");

function ruleBody(selector: string) {
  const escapedSelector = selector.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
  return (
    styles.match(
      new RegExp(`${escapedSelector}\\s*\\{([\\s\\S]*?)\\n\\}`, "u"),
    )?.[1] ?? ""
  );
}

describe("announcement visual experiment", () => {
  it("floats the comparison toggle outside normal layout flow", () => {
    expect(ruleBody(".hero__announcement-experiment")).toContain(
      "position: relative;",
    );
    expect(ruleBody(".hero__announcement-toggle")).toContain(
      "position: absolute;",
    );
  });

  it("keeps reflection and fluid motion as separate animation systems", () => {
    const base = ruleBody(".hero__announcement");
    const reflection = ruleBody(".hero__announcement--reflection::after");
    const fluidColors = ruleBody(".hero__announcement--fluid::before");
    const fluidVeil = ruleBody(".hero__announcement--fluid::after");

    expect(base).not.toContain("animation:");
    expect(reflection).toContain(
      "animation: announcement-reflection-sweep 4.8s ease-in-out infinite;",
    );
    expect(fluidColors).toContain(
      "animation: announcement-fluid-color-flow 6s linear infinite;",
    );
    expect(fluidColors).not.toContain("ease-in-out");
    expect(fluidVeil).not.toContain("animation:");
    expect(styles).toContain("@keyframes announcement-fluid-color-flow");
    expect(styles).not.toContain("announcement-fluid-sheen");
  });

  it("disables both motion systems when reduced motion is requested", () => {
    const reducedMotion = styles.slice(
      styles.indexOf("@media (prefers-reduced-motion: reduce)"),
    );

    expect(reducedMotion).toContain(
      ".hero__announcement--reflection::after,\n  .hero__announcement--fluid::before {\n    animation: none;",
    );
  });

  it("keeps the fluid path closed with waypoints on both sides of the seam", () => {
    const keyframesStart = styles.indexOf(
      "@keyframes announcement-fluid-color-flow",
    );
    const fluidKeyframes = styles.slice(
      keyframesStart,
      styles.indexOf("@media", keyframesStart),
    );

    expect(fluidKeyframes).toContain("0%,\n  100% {");
    expect(fluidKeyframes).toContain("12.5% {");
    expect(fluidKeyframes).toContain("87.5% {");
  });

  it("keeps three evenly spaced orbit geometries with independent motion", () => {
    expect(ruleBody(".orbit--inner")).toContain("width: 84%;");
    expect(ruleBody(".orbit--inner")).toContain(
      "animation: orbit-inner 20s linear infinite;",
    );
    expect(ruleBody(".orbit--outer")).toContain("width: 112%;");
    expect(ruleBody(".orbit--outer")).toContain(
      "animation: orbit-outer 28s linear infinite;",
    );
    expect(ruleBody(".orbit--far")).toContain("width: 140%;");
    expect(ruleBody(".orbit--far")).toContain(
      "animation: orbit-far 36s linear infinite;",
    );
  });

  it("stops orbit rotation when reduced motion is requested", () => {
    const reducedMotion = styles.slice(
      styles.indexOf("@media (prefers-reduced-motion: reduce)"),
    );

    expect(reducedMotion).toContain(".orbit {\n    animation: none;");
  });
});
