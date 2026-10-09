"use client";
import { ClientLink as Link } from "@/lib/navigation/client-navigation";
import { useClientNavigation } from "@/lib/navigation/client-navigation";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button, buttonVariants } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import type { HandoffConfig } from "../project-app-handoff/handoff-config";
import {
  confirmationPath,
  participantReturnPath,
  projectPath,
} from "../project-app-handoff/project-links";
import { browserParticipantController } from "./participant-browser";
import type { ParticipantController } from "./participant-controller";
import type {
  ParticipantFailure,
  ParticipantPreview,
} from "./participant-models";
import { participantFailureMessage } from "./participant-messages";

export function ParticipantInviteFlowView({
  token,
  initialRead,
  controller,
}: Readonly<{
  token: string;
  initialRead: Readonly<{
    preview?: ParticipantPreview;
    failure?: ParticipantFailure;
  }>;
  config: HandoffConfig;
  controller?: ParticipantController;
}>) {
  const [active, setActive] = useState<ParticipantController | null>(null);
  useEffect(() => {
    let live = true;
    const current = controller ?? browserParticipantController();
    void current.openInvite(token, initialRead.preview).then(() => {
      if (live) setActive(current);
    });
    return () => {
      live = false;
      current.deactivate(token);
    };
  }, [controller, token, initialRead]);
  if (!active || !active.isInvite(token))
    return (
      <div className="grid gap-4">
        <PreviewBody
          preview={initialRead.preview}
          failure={initialRead.failure}
        />
        <p role="status">
          <Spinner className="inline-block" /> Checking your account…
        </p>
      </div>
    );
  return <InviteControls token={token} controller={active} />;
}
function InviteControls({
  token,
  controller,
}: Readonly<{ token: string; controller: ParticipantController }>) {
  const state = useSyncExternalStore(
    controller.subscribe,
    controller.snapshot,
    controller.snapshot,
  );
  const router = useClientNavigation();
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  const destination = participantReturnPath(token);
  const blocked = state.loading || state.busy;
  async function join(reenter = false) {
    await controller.join(reenter);
    const result = controller.snapshot();
    if (
      mounted.current &&
      controller.isInvite(token) &&
      result.receipt &&
      result.project &&
      (result.participation?.current || result.participation?.creator)
    )
      router.replace(confirmationPath(result.project));
  }
  const current = state.participation?.current || state.participation?.creator;
  const ended = !!state.receipt && !current && !!state.participation;
  return (
    <div className="grid gap-4">
      <PreviewBody preview={state.preview} failure={state.previewFailure} />
      {state.failure ? <FailureAlert failure={state.failure} /> : null}
      {state.readFailure ? (
        <div className="grid gap-3">
          <Alert variant="destructive">
            <AlertTitle>Participation status could not be checked</AlertTitle>
            <AlertDescription>
              {state.receipt
                ? "Your join result is recorded, but current membership could not be verified. Retry this read without joining again."
                : "We could not verify your account or current participation. Try the read again."}
            </AlertDescription>
          </Alert>
          <Button
            variant="outline"
            disabled={blocked}
            onClick={() => void controller.retryReads()}
          >
            Retry status check
          </Button>
        </div>
      ) : null}
      {blocked ? (
        <p role="status">
          <Spinner className="inline-block" />{" "}
          {state.busy ? "Checking your join…" : "Checking participation…"}
        </p>
      ) : null}
      {!blocked && state.auth?.phase === "signedOut" ? (
        <Link
          className={buttonVariants()}
          href={`/auth?returnTo=${encodeURIComponent(destination)}`}
          prefetch={false}
        >
          Sign in or create an account
        </Link>
      ) : null}
      {!blocked &&
      state.auth &&
      ["missingProfile", "incompleteProfile"].includes(state.auth.phase) ? (
        <Link
          className={buttonVariants()}
          href={`${state.auth.phase === "missingProfile" ? "/auth" : "/profile"}?returnTo=${encodeURIComponent(destination)}`}
          prefetch={false}
        >
          Complete basic profile
        </Link>
      ) : null}
      {current && state.project && !blocked ? (
        <>
          <p>
            {state.participation?.creator
              ? "You already own this Project."
              : "You currently participate in this Project."}
          </p>
          <Link
            className={buttonVariants()}
            href={confirmationPath(state.project)}
            prefetch={false}
          >
            Continue to PLANETS
          </Link>
        </>
      ) : null}
      {ended ? (
        <p>
          Your earlier join has ended. Checking its receipt does not restore
          that membership.
        </p>
      ) : null}
      {!blocked &&
      state.auth?.phase === "ready" &&
      state.hasAttempt &&
      !state.receipt ? (
        <Button onClick={() => void join()}>Check previous join</Button>
      ) : null}
      {!blocked &&
      state.auth?.phase === "ready" &&
      !state.hasAttempt &&
      state.preview?.available &&
      state.participation &&
      !current ? (
        <Button onClick={() => void join()}>Join Project</Button>
      ) : null}
      {!blocked &&
      ended &&
      state.preview?.available &&
      state.auth?.phase === "ready" &&
      state.receipt?.outcome !== "creator" ? (
        <Button onClick={() => void join(true)}>Join Project again</Button>
      ) : null}
      <p className="text-sm text-muted-foreground">
        Joining through this link needs a basic profile, but no photo or
        individual organizer approval. Any prior pending request closes; its
        contribution offers are not added automatically.
      </p>
      <Button
        variant="outline"
        disabled={blocked}
        onClick={() => void controller.refresh()}
      >
        Refresh invitation
      </Button>
      <Link href="/" prefetch={false}>
        Leave invitation
      </Link>
    </div>
  );
}
function PreviewBody({
  preview,
  failure,
}: Readonly<{ preview?: ParticipantPreview; failure?: ParticipantFailure }>) {
  if (failure) return <FailureAlert failure={failure} />;
  if (!preview) return null;
  if (!preview.available)
    return (
      <Alert>
        <AlertTitle>Invitation unavailable</AlertTitle>
        <AlertDescription>
          This invitation cannot be used now. A previous pending join can still
          be checked after signing in.
        </AlertDescription>
      </Alert>
    );
  return (
    <div className="grid gap-3">
      <p className="text-2xl font-semibold">{preview.title}</p>
      <p>{preview.project.kind === "one_time" ? "Proposal" : "Tavolo"}</p>
      <Link href={projectPath(preview.project)} prefetch={false}>
        View Project
      </Link>
    </div>
  );
}
export function FailureAlert({
  failure,
}: Readonly<{ failure: ParticipantFailure }>) {
  return (
    <Alert variant="destructive" aria-live="polite">
      <AlertTitle>Invitation needs attention</AlertTitle>
      <AlertDescription>{participantFailureMessage(failure)}</AlertDescription>
    </Alert>
  );
}
