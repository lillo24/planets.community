import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const styles = readFileSync(
  new URL("./launch-polish.css", import.meta.url),
  "utf8",
);

describe("launch visual polish", () => {
  it("keeps the restrained green CTA while adding a background-only idle pulse", () => {
    expect(styles).toContain("border: 1px solid rgb(216 92 145 / 18%);");
    expect(styles).toContain("background: rgb(92 174 100 / 12%);");
    expect(styles).toContain("color: #2f6842;");
    expect(styles).toContain(".waitlist button::before {");
    expect(styles).toContain("@keyframes waitlist-cta-background-pulse");
    expect(styles).toContain(
      '.waitlist[data-verification="idle"] button:not(:disabled)::before',
    );
  });

  it("adds CTA separation plus click shrink and success pop motion", () => {
    expect(styles).toContain(".waitlist__controls {\n  gap: 0.85rem;\n}");
    expect(styles).toContain(
      ".waitlist button:active:not(:disabled) {\n  transform: scale(0.94);",
    );
    expect(styles).toContain("@keyframes waitlist-cta-success-pop");
  });

  it("reveals Turnstile from the side with an ease-out finish", () => {
    expect(styles).toContain(".waitlist__turnstile-reveal {");
    expect(styles).toContain("transform: translateX(1.5rem);");
    expect(styles).toContain("transform: translateX(0);");
    expect(styles).toContain("cubic-bezier(0.16, 1, 0.3, 1)");
  });

  it("matches fluid text and border to Base while keeping its faster flow", () => {
    expect(styles).toContain(
      ".hero__announcement--fluid {\n  border-color: rgb(216 92 145 / 18%);\n  color: #704356;\n}",
    );
    expect(styles).toContain(
      ".hero__announcement--fluid::before {\n  animation-duration: 4.5s;\n}",
    );
  });
});
