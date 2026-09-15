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
    const reflection = ruleBody(".hero__announcement--reflection::after");
    const fluidColors = ruleBody(".hero__announcement--fluid::before");
    const fluidVeil = ruleBody(".hero__announcement--fluid::after");

    expect(reflection).toContain(
      "animation: announcement-reflection-sweep 4.8s ease-in-out infinite;",
    );
    expect(fluidColors).toContain(
      "animation: announcement-fluid-color-flow 6s ease-in-out infinite;",
    );
    expect(fluidVeil).not.toContain("animation:");
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
});
