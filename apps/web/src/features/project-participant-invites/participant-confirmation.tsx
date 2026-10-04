"use client";
import Link from "next/link";
import { useEffect, useState, useSyncExternalStore } from "react";
import { Button, buttonVariants } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import type { HandoffConfig } from "../project-app-handoff/handoff-config";
import { ProjectAppHandoff } from "../project-app-handoff/project-app-handoff";
import {
  confirmationPath,
  projectPath,
} from "../project-app-handoff/project-links";
import { browserParticipantController } from "./participant-browser";
import type { ParticipantController } from "./participant-controller";
import type { ProjectContext } from "./participant-models";
import { FailureAlert } from "./participant-invite-flow";

export function ParticipantConfirmation({
  project,
  config,
  controller,
}: Readonly<{
  project: ProjectContext;
  config: HandoffConfig;
  controller?: ParticipantController;
}>) {
  const [active, setActive] = useState<ParticipantController | null>(null);
  useEffect(() => {
    let live = true;
    const current = controller ?? browserParticipantController();
    void current.openConfirmation(project).then(() => {
      if (live) setActive(current);
    });
    return () => {
      live = false;
      current.deactivate(project);
    };
  }, [controller, project]);
  return active ? (
    <ConfirmationControls
      project={project}
      config={config}
      controller={active}
    />
  ) : (
    <p role="status">
      <Spinner className="inline-block" /> Checking current participation…
    </p>
  );
}
function ConfirmationControls({
  project,
  config,
  controller,
}: Readonly<{
  project: ProjectContext;
  config: HandoffConfig;
  controller: ParticipantController;
}>) {
  const state = useSyncExternalStore(
    controller.subscribe,
    controller.snapshot,
    controller.snapshot,
  );
  const belongs =
    state.project?.id === project.id && state.project.kind === project.kind;
  const current =
    belongs && (state.participation?.current || state.participation?.creator);
  return (
    <div className="grid gap-4">
      {state.loading || !belongs ? (
        <p role="status">
          <Spinner className="inline-block" /> Checking current participation…
        </p>
      ) : state.readFailure ? (
        <FailureAlert failure={state.readFailure} />
      ) : current ? (
        <>
          <p>
            {state.participation?.creator
              ? "You own this Project."
              : "You currently participate in this Project."}
          </p>
          <ProjectAppHandoff project={project} config={config} confirmed />
        </>
      ) : state.auth?.phase === "signedOut" ? (
        <>
          <p>Sign in to check your participation in this Project.</p>
          <Link
            className={buttonVariants()}
            prefetch={false}
            href={`/auth?returnTo=${encodeURIComponent(confirmationPath(project))}`}
          >
            Sign in
          </Link>
        </>
      ) : (
        <p>
          You do not currently participate in this Project. An earlier join may
          have ended; this page does not join you again.
        </p>
      )}
      <Button
        variant="outline"
        disabled={state.loading || state.busy}
        onClick={() => void controller.retryReads()}
      >
        Refresh participation
      </Button>
      {!current ? (
        <Link href={projectPath(project)} prefetch={false}>
          View public Project
        </Link>
      ) : null}
    </div>
  );
}
