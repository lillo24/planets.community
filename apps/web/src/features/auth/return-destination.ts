export const defaultReturnDestination = "/";

const internalOrigin = "https://planets.invalid";

export function sanitizeReturnDestination(
  candidate: string | undefined,
): string {
  if (
    !candidate ||
    !candidate.startsWith("/") ||
    candidate.startsWith("//") ||
    candidate.includes("\\")
  ) {
    return defaultReturnDestination;
  }

  try {
    const destination = new URL(candidate, internalOrigin);
    let decodedPath = destination.pathname;
    for (let index = 0; index < 4; index++) {
      decodedPath = decodeURIComponent(decodedPath);
      if (
        decodedPath.includes("\\") ||
        decodedPath.startsWith("//") ||
        isAuthPath(decodedPath)
      )
        return defaultReturnDestination;
    }

    if (
      destination.origin !== internalOrigin ||
      decodedPath.includes("\\") ||
      decodedPath.startsWith("//") ||
      isAuthPath(destination.pathname) ||
      isAuthPath(decodedPath)
    ) {
      return defaultReturnDestination;
    }

    return `${destination.pathname}${destination.search}${destination.hash}`;
  } catch {
    return defaultReturnDestination;
  }
}

// Only participant onboarding changes the existing Home cancellation default.
export function participantCancelDestination(
  candidate: string,
  depth = 0,
): string {
  if (depth > 3) return "/";
  const destination = sanitizeReturnDestination(candidate);
  const parsed = new URL(destination, internalOrigin);
  const returns = parsed.searchParams.getAll("returnTo");
  if (parsed.pathname === "/profile" && returns.length === 1)
    return participantCancelDestination(returns[0], depth + 1);
  if (/^\/join\/project\/[A-Za-z0-9_-]{43}$/u.test(destination))
    return destination;
  const joined = /^\/joined\/(proposals|tavoli)\/([0-9a-f-]{36})$/iu.exec(
    destination,
  );
  return joined ? `/${joined[1]}/${joined[2]}` : "/";
}

function isAuthPath(pathname: string): boolean {
  return pathname === "/auth" || pathname.startsWith("/auth/");
}
