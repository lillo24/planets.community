"use client";
import { ClientLink as Link } from "@/lib/navigation/client-navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { CheckIcon, SparklesIcon } from "lucide-react";
import { Button, buttonVariants } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import type { HandoffConfig } from "../project-app-handoff/handoff-config";
import { ProjectAppHandoffView } from "../project-app-handoff/project-app-handoff-view";
import {
  confirmationPath,
  projectPath,
} from "../project-app-handoff/project-links";
import { browserParticipantController } from "./participant-browser";
import type { ParticipantController } from "./participant-controller";
import type { ProjectContext } from "./participant-models";
import { FailureAlert } from "./participant-invite-flow-view";

export function ParticipantConfirmationView({
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
        <section className="grid justify-items-center gap-5 rounded-3xl border bg-gradient-to-br from-violet-50 via-card to-rose-50 px-6 py-10 text-center shadow-sm sm:px-10 sm:py-14 dark:from-violet-950/40 dark:to-rose-950/40">
          <div
            aria-hidden="true"
            className="relative flex size-20 items-center justify-center rounded-full bg-violet-100 text-violet-600 dark:bg-violet-950 dark:text-violet-300"
          >
            <CheckIcon className="size-10" strokeWidth={2.5} />
            <SparklesIcon className="absolute -top-2 -right-3 size-7 text-rose-400" />
          </div>
          <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
            {state.participation?.creator ? "Your project 🌸" : "You're in! 🌸"}
          </h1>
          <p className="text-lg text-muted-foreground">
            {state.participation?.creator
              ? "This is your project."
              : "You joined the project."}
          </p>
          <ProjectAppHandoffView project={project} config={config} confirmed />
        </section>
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
        <p>You aren&apos;t currently participating in this project.</p>
      )}
      {state.readFailure ? (
        <Button
          variant="outline"
          disabled={state.loading || state.busy}
          onClick={() => void controller.retryReads()}
        >
          Try again
        </Button>
      ) : null}
      {!current ? (
        <Link href={projectPath(project)} prefetch={false}>
          View public Project
        </Link>
      ) : null}
    </div>
  );
}
