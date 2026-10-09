// @vitest-environment node
import { expect, it } from "vitest";
import { assertStagingArtifact } from "./artifact.mjs";

const staging = 'const url="https://cllpvruvrrvxczjitlqd.supabase.co";';
it("permits the public SDK key discriminator while rejecting actual credential-shaped values", () => {
  expect(() =>
    assertStagingArtifact(staging + "key.startsWith('sb_secret_')"),
  ).not.toThrow();
  const syntheticSecret = "sb_secret_" + "x".repeat(32);
  expect(() => assertStagingArtifact(staging + syntheticSecret)).toThrow(
    "Invalid public artifact.",
  );
});
it("refuses local/synthetic build targets and source maps before upload", () => {
  expect(() => assertStagingArtifact('url="http://127.0.0.1:59121"')).toThrow(
    "Build staging",
  );
  expect(() =>
    assertStagingArtifact(staging + "//# sourceMappingURL=app.js.map"),
  ).toThrow("Invalid public artifact.");
});
