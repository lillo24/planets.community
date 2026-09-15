import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const styles = readFileSync(
  new URL("./launch-polish.css", import.meta.url),
  "utf8",
);

describe("launch visual polish", () => {
  it("shows the email label and gives the launch CTA a restrained green treatment", () => {
    expect(styles).toContain(".waitlist__email-label {");
    expect(styles).toContain("border: 1px solid rgb(216 92 145 / 18%);");
    expect(styles).toContain("background: rgb(92 174 100 / 12%);");
    expect(styles).toContain("color: #2f6842;");
  });

  it("adds more separation before Turnstile", () => {
    expect(styles).toContain(
      ".waitlist__turnstile {\n  margin-top: 1.25rem;\n}",
    );
  });

  it("matches fluid text and border to Base while speeding up the color flow", () => {
    expect(styles).toContain(
      ".hero__announcement--fluid {\n  border-color: rgb(216 92 145 / 18%);\n  color: #704356;\n}",
    );
    expect(styles).toContain(
      ".hero__announcement--fluid::before {\n  animation-duration: 4.5s;\n}",
    );
  });
});
