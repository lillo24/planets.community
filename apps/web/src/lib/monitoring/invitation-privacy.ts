// Drop entire secret-bearing payloads instead of preserving a partially redacted URL.
export function containsInvitationSecret(
  value: unknown,
  seen = new WeakSet<object>(),
): boolean {
  if (typeof value === "string") {
    let text = value;
    for (let index = 0; index <= 4; index++) {
      if (
        text.includes("/join/project/") ||
        text.includes("/invite/project/") ||
        /\b(?:p_token|invite_token)\b["']?\s*[:=]/u.test(text) ||
        /(^|[^A-Za-z0-9_-])[A-Za-z0-9_-]{43}($|[^A-Za-z0-9_-])/u.test(text)
      )
        return true;
      try {
        const decoded = decodeURIComponent(text);
        if (decoded === text) break;
        text = decoded;
      } catch {
        break;
      }
    }
    return false;
  }
  if (!value || typeof value !== "object" || seen.has(value)) return false;
  seen.add(value);
  if (
    value instanceof Error &&
    (containsInvitationSecret(value.message, seen) ||
      containsInvitationSecret(value.stack, seen))
  )
    return true;
  return Object.entries(value).some(
    ([key, item]) =>
      ["p_token", "invite_token"].includes(key) ||
      containsInvitationSecret(key, seen) ||
      containsInvitationSecret(item, seen),
  );
}
