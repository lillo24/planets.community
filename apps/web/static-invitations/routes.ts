import { sanitizeReturnDestination } from "../src/features/auth/return-destination";
import {
  participantTokenPattern,
  projectIdPattern,
  type ProjectContext,
} from "../src/features/project-participant-invites/participant-models";

export type TrialRoute =
  | { kind: "home" | "auth" | "profile" }
  | { kind: "invite"; token: string }
  | { kind: "confirmation"; project: ProjectContext };
export function trialRoute(path: string): TrialRoute | null {
  if (path === "/") return { kind: "home" };
  if (path === "/auth" || path === "/profile")
    return { kind: path.slice(1) as "auth" | "profile" };
  const invite = /^\/join\/project\/([^/]+)$/u.exec(path);
  if (invite && participantTokenPattern.test(invite[1]))
    return { kind: "invite", token: invite[1] };
  const joined = /^\/joined\/(proposals|tavoli)\/([^/]+)$/u.exec(path);
  if (joined && projectIdPattern.test(joined[2]))
    return {
      kind: "confirmation",
      project: {
        id: joined[2],
        kind: joined[1] === "proposals" ? "one_time" : "recurring",
      },
    };
  return null;
}
// Narrow the existing safe-return contract to the trial's owners; retain nested
// profile continuation but reject duplicate/unknown query parameters and hashes.
export function trialReturn(candidate: string | undefined, depth = 0): string {
  if (depth > 3) return "/";
  const safe = sanitizeReturnDestination(candidate);
  const url = new URL(safe, "https://planets.invalid");
  const route = trialRoute(url.pathname);
  if (!route || url.hash) return "/";
  if (route.kind === "profile") {
    const entries = [...url.searchParams];
    if (!entries.length) return "/profile";
    if (entries.length !== 1 || entries[0][0] !== "returnTo") return "/";
    const nested = trialReturn(entries[0][1], depth + 1);
    return nested === "/"
      ? "/"
      : `/profile?returnTo=${encodeURIComponent(nested)}`;
  }
  return url.search ? "/" : url.pathname;
}
