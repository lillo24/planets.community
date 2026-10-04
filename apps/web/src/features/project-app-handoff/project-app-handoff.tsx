import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import type { ProjectContext } from "../project-participant-invites/participant-models";
import type { HandoffConfig } from "./handoff-config";
import { projectAppUrl, projectPath } from "./project-links";

export function ProjectAppHandoff({
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
    <div className="grid gap-4">
      {confirmed ? (
        <p>
          Sign into the same PLANETS account in the app to find this Project and
          its chat. Browser sign-in is not transferred.
        </p>
      ) : (
        <p>
          Requests to join are handled in PLANETS, with the usual profile, photo
          and contribution steps and organizer approval.
        </p>
      )}
      <div className="flex flex-wrap gap-3">
        <a
          className={buttonVariants()}
          href={projectAppUrl(project, ordinaryIntent)}
          referrerPolicy="no-referrer"
        >
          Open PLANETS
        </a>
        {config.android ? (
          <a
            className={buttonVariants({ variant: "outline" })}
            href={config.android}
            rel="noreferrer"
            referrerPolicy="no-referrer"
          >
            Download for Android
          </a>
        ) : null}
        {config.ios ? (
          <a
            className={buttonVariants({ variant: "outline" })}
            href={config.ios}
            rel="noreferrer"
            referrerPolicy="no-referrer"
          >
            Download for iPhone
          </a>
        ) : null}
      </div>
      <p className="text-sm text-muted-foreground">
        If this link stays in your browser, you can keep viewing the Project
        here
        {config.android || config.ios
          ? " or use a download option above."
          : ". App downloads are not available here yet."}
      </p>
      <Link href={projectPath(project)} prefetch={false}>
        View Project in this browser
      </Link>
    </div>
  );
}
