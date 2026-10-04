import {
  projectId,
  projectKind,
  type ProjectContext,
} from "../project-participant-invites/participant-models";

// Matches PI02. Host overrides and verified OS delivery are outside PI03.
export const planetsPublicOrigin = "https://planets.community";
export function projectPath(project: ProjectContext): string {
  return `/${projectKind(project.kind) === "one_time" ? "proposals" : "tavoli"}/${projectId(project.id)}`;
}
export function projectAppUrl(
  project: ProjectContext,
  ordinaryIntent = false,
): string {
  return `${planetsPublicOrigin}${projectPath(project)}${ordinaryIntent ? "?intent=join" : ""}`;
}
export function confirmationPath(project: ProjectContext): string {
  return `/joined${projectPath(project)}`;
}
export function hasOrdinaryIntent(
  value: string | string[] | undefined,
): boolean {
  return value === "join";
}
export function participantReturnPath(token: string): string {
  return `/join/project/${encodeURIComponent(token)}`;
}
