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
    expect(fluidColors).toContain("background-repeat: repeat-x;");
    expect(fluidColors).toContain("background-size: 24rem 100%;");
    expect(fluidColors).not.toContain("ease-in-out");
    expect(fluidColors).not.toContain("saturate(");
    expect(fluidVeil).not.toContain("animation:");
    expect(fluidColors).not.toContain("announcement-reflection-sweep");
    expect(fluidVeil).not.toContain("announcement-reflection-sweep");
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

  it("moves the fluid tile right by one repeat width with minor vertical drift", () => {
    const keyframesStart = styles.indexOf(
      "@keyframes announcement-fluid-color-flow",
    );
    const fluidKeyframes = styles.slice(
      keyframesStart,
      styles.indexOf("@media", keyframesStart),
    );

    expect(fluidKeyframes).toContain("background-position: 0 0;");
    expect(fluidKeyframes).toContain("background-position: 24rem 0;");
    expect(fluidKeyframes).toContain("background-position: 6rem -0.15rem;");
    expect(fluidKeyframes).toContain("background-position: 18rem 0.15rem;");
    expect(fluidKeyframes).not.toContain("12.5% {");
    expect(fluidKeyframes).not.toContain("87.5% {");
  });

  it("centers each satellite on its orbit stroke", () => {
    const satellite = ruleBody(".orbit::after");

    expect(satellite).toContain("top: 50%;");
    expect(satellite).toContain("right: 0;");
    expect(satellite).toContain("transform: translate(50%, -50%);");
  });

  it("keeps three evenly spaced orbit geometries with faster independent motion", () => {
    expect(ruleBody(".orbit--inner")).toContain("width: 84%;");
    expect(ruleBody(".orbit--inner")).toContain(
      "animation: orbit-inner 18s linear infinite;",
    );
    expect(ruleBody(".orbit--outer")).toContain("width: 112%;");
    expect(ruleBody(".orbit--outer")).toContain(
      "animation: orbit-outer 24s linear infinite;",
    );
    expect(ruleBody(".orbit--far")).toContain("width: 140%;");
    expect(ruleBody(".orbit--far")).toContain(
      "animation: orbit-far 32s linear infinite;",
    );
  });

  it("adds waitlist breathing room only within the phone layout", () => {
    const baseWaitlist = ruleBody(".waitlist");
    const desktopStart = styles.indexOf("@media (min-width: 58rem)");
    const desktop = styles.slice(
      desktopStart,
      styles.indexOf("@media (max-width: 43rem)", desktopStart),
    );
    const mobileStart = styles.indexOf("@media (max-width: 43rem)");
    const mobile = styles.slice(
      mobileStart,
      styles.indexOf("@media (prefers-reduced-motion: reduce)", mobileStart),
    );

    expect(baseWaitlist).toContain("margin-top: 0;");
    expect(desktop).toContain(".waitlist {\n    margin-top: 2.25rem;");
    expect(mobile).toContain(".waitlist {\n    margin-top: 1.75rem;");
  });

  it("stops orbit rotation when reduced motion is requested", () => {
    const reducedMotion = styles.slice(
      styles.indexOf("@media (prefers-reduced-motion: reduce)"),
    );

    expect(reducedMotion).toContain(".orbit {\n    animation: none;");
  });
});
