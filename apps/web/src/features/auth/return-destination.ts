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
    const decodedPath = decodeURIComponent(destination.pathname);

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

function isAuthPath(pathname: string): boolean {
  return pathname === "/auth" || pathname.startsWith("/auth/");
}
