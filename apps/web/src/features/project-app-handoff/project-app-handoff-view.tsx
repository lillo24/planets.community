import { buttonVariants } from "@/components/ui/button";
import type { ProjectContext } from "../project-participant-invites/participant-models";
import type { HandoffConfig } from "./handoff-config";
import { projectAppUrl } from "./project-links";
import { StoreBadge } from "./store-badge";

export function ProjectAppHandoffView({
  project,
  config,
  ordinaryIntent = false,
  confirmed = false,
}: Readonly<{
  project: ProjectContext;
  config: HandoffConfig;
  ordinaryIntent?: boolean;
  confirmed?: boolean;
}>) {
  return (
    <div className="grid w-full justify-items-center gap-6">
      {confirmed ? (
        <p className="max-w-md leading-relaxed text-muted-foreground">
          Open the app with the same PLANETS account to find your project and
          its group chat.
        </p>
      ) : (
        <p>
          Requests to join are handled in PLANETS, with the usual profile, photo
          and contribution steps and organizer approval.
        </p>
      )}
      <a
        className={buttonVariants({
          className:
            "h-12 rounded-full bg-violet-600 px-8 text-base text-white hover:bg-violet-500",
        })}
        href={projectAppUrl(project, ordinaryIntent)}
        referrerPolicy="no-referrer"
      >
        Open PLANETS
      </a>
      <div className="flex flex-wrap justify-center gap-3">
        <StoreBadge platform="android" href={config.android} />
        <StoreBadge platform="ios" href={config.ios} />
      </div>
    </div>
  );
}
