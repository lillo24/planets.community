import { UsersRound } from "lucide-react";
import type { ProjectGroupAttribution } from "./group-project-models";

export function ProjectGroupBadge({
  group,
}: Readonly<{ group?: ProjectGroupAttribution }>) {
  if (!group) return null;
  if (group.state === "unavailable")
    return (
      <p className="text-sm text-muted-foreground">
        Published for a group that is currently unavailable
      </p>
    );
  // Also rendered by the static invitation host: keep this shared badge free
  // of the Next runtime. Ordinary public links work in either browser host.
  return (
    <a
      className="flex min-w-0 items-start gap-2 text-sm text-primary underline-offset-4 hover:underline"
      href={`/groups/${group.groupId}`}
    >
      <UsersRound aria-hidden="true" className="size-4 shrink-0" />
      <span className="min-w-0 break-words">
        For {group.name} ·{" "}
        {group.kind === "informal" ? "Community group" : "Organization"}
      </span>
    </a>
  );
}
