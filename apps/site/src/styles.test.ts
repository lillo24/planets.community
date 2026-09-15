import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const styles = readFileSync(new URL("./styles.css", import.meta.url), "utf8");

describe("fluid announcement animation", () => {
  it("uses the faster drift and sheen timings", () => {
    expect(styles).toContain(
      "animation: announcement-fluid-drift 8s ease-in-out infinite alternate;",
    );
    expect(styles).toContain(
      "animation: announcement-fluid-sheen 6s ease-in-out infinite;",
    );
  });
});
