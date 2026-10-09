import assert from "node:assert/strict";

export function assertStagingArtifact(scripts) {
  assert(
    scripts.includes("https://cllpvruvrrvxczjitlqd.supabase.co") &&
      !scripts.includes("http://127.0.0.1:59121"),
    "Build staging client before deployment.",
  );
  // supabase-js contains the literal 'sb_secret_' as a key-type discriminator.
  // Reject actual credential-shaped values, not that public SDK source string.
  assert(
    !/sb_secret_[A-Za-z0-9_-]{20,}/u.test(scripts) &&
      !scripts.includes("sourceMappingURL="),
    "Invalid public artifact.",
  );
}
