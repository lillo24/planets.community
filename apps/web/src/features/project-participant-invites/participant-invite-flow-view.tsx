"use client";
import { ClientLink as Link } from "@/lib/navigation/client-navigation";
import { useClientNavigation } from "@/lib/navigation/client-navigation";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button, buttonVariants } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import type { HandoffConfig } from "../project-app-handoff/handoff-config";
import {
  confirmationPath,
  participantReturnPath,
} from "../project-app-handoff/project-links";
import { browserParticipantController } from "./participant-browser";
import type { ParticipantController } from "./participant-controller";
import type {
  ParticipantAuth,
  ParticipantFailure,
  ParticipantPreview,
  ProjectContext,
} from "./participant-models";
import { participantFailureMessage } from "./participant-messages";
import { ParticipantProjectCard } from "./participant-project-card";
import type { InvitationProjectGateway } from "./participant-project-gateway";

const joinButtonClass =
  "h-12 w-full rounded-full bg-violet-600 px-8 text-base text-white shadow-sm hover:bg-violet-500 sm:w-auto sm:min-w-48 sm:justify-self-center";

type JoinSetup = Readonly<{
  onJoinPrerequisites?: (
    auth: ParticipantAuth,
    preview: Extract<ParticipantPreview, { available: true }>,
  ) => void;
  joiningAfterSetup?: boolean;
  continueJoin?: (account: string, project: ProjectContext) => boolean;
  cancelJoin?: () => void;
}>;

export function ParticipantInviteFlowView({
  token,
  initialRead,
  controller,
  projectGateway,
  ...joinSetup
}: Readonly<{
  token: string;
  initialRead: Readonly<{
    preview?: ParticipantPreview;
    failure?: ParticipantFailure;
  }>;
  config: HandoffConfig;
  controller?: ParticipantController;
  projectGateway?: InvitationProjectGateway;
}> &
  JoinSetup) {
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
          gateway={projectGateway}
        />
        <p role="status">
          <Spinner className="inline-block" /> Checking your account…
        </p>
      </div>
    );
  return (
    <InviteControls
      token={token}
      controller={active}
      projectGateway={projectGateway}
      {...joinSetup}
    />
  );
}
function InviteControls({
  token,
  controller,
  projectGateway,
  onJoinPrerequisites,
  joiningAfterSetup = false,
  continueJoin,
  cancelJoin,
}: Readonly<{
  token: string;
  controller: ParticipantController;
  projectGateway?: InvitationProjectGateway;
}> &
  JoinSetup) {
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
  const join = useCallback(
    async (reenter = false) => {
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
    },
    [controller, router, token],
  );
  const current = state.participation?.current || state.participation?.creator;
  const ended = !!state.receipt && !current && !!state.participation;
  useEffect(() => {
    if (!joiningAfterSetup || blocked) return;
    if (
      state.readFailure ||
      state.previewFailure ||
      state.failure ||
      !state.preview?.available ||
      ended
    ) {
      cancelJoin?.();
      return;
    }
    if (
      state.auth?.phase !== "ready" ||
      !state.auth.account ||
      !state.project ||
      !state.participation ||
      !continueJoin?.(state.auth.account, state.project)
    )
      return;
    // Resume only a Join explicitly requested before Auth/name setup. Consuming
    // that tab-local request is atomic; mounting or restoring Auth never joins.
    if (current) router.replace(confirmationPath(state.project));
    else void join();
  }, [
    joiningAfterSetup,
    blocked,
    state,
    current,
    ended,
    continueJoin,
    cancelJoin,
    router,
    join,
  ]);
  const needsSetup = state.auth && state.auth.phase !== "ready" && !blocked;
  const setupPath = `${state.auth?.phase === "incompleteProfile" ? "/profile" : "/auth"}?returnTo=${encodeURIComponent(destination)}`;
  return (
    <div className="grid gap-4">
      <PreviewBody
        preview={state.preview}
        failure={state.previewFailure}
        gateway={projectGateway}
      />
      {state.failure ? <FailureAlert failure={state.failure} /> : null}
      {state.readFailure ? (
        <div className="grid gap-3">
          <Alert variant="destructive">
            <AlertTitle>Participation status could not be checked</AlertTitle>
            <AlertDescription>
              {state.receipt
                ? "Your request was sent, but we couldn't confirm your participation. Try checking again."
                : "We couldn't check your account or participation. Please try again."}
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
          {state.busy ? "Joining project…" : "Checking participation…"}
        </p>
      ) : null}
      {needsSetup && onJoinPrerequisites && state.preview?.available ? (
        <Link
          className={buttonVariants({ className: joinButtonClass })}
          href={setupPath}
          prefetch={false}
          onClick={(event) => {
            if (
              event.defaultPrevented ||
              event.button !== 0 ||
              event.metaKey ||
              event.ctrlKey ||
              event.shiftKey ||
              event.altKey ||
              !state.auth ||
              !state.preview?.available
            )
              return;
            onJoinPrerequisites(state.auth, state.preview);
          }}
        >
          Join Project
        </Link>
      ) : null}
      {!blocked &&
      state.auth?.phase === "signedOut" &&
      !(onJoinPrerequisites && state.preview?.available) ? (
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
      ["missingProfile", "incompleteProfile"].includes(state.auth.phase) &&
      !(onJoinPrerequisites && state.preview?.available) ? (
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
      {ended ? <p>Your previous participation has ended.</p> : null}
      {!blocked &&
      !joiningAfterSetup &&
      state.auth?.phase === "ready" &&
      state.hasAttempt &&
      !state.receipt ? (
        <Button onClick={() => void join()}>Check previous join</Button>
      ) : null}
      {!blocked &&
      !joiningAfterSetup &&
      state.auth?.phase === "ready" &&
      !state.hasAttempt &&
      state.preview?.available &&
      state.participation &&
      !current ? (
        <Button className={joinButtonClass} onClick={() => void join()}>
          Join Project
        </Button>
      ) : null}
      {!blocked &&
      ended &&
      state.preview?.available &&
      state.auth?.phase === "ready" &&
      state.receipt?.outcome !== "creator" ? (
        <Button className={joinButtonClass} onClick={() => void join(true)}>
          Join Project again
        </Button>
      ) : null}
      {state.previewFailure && !state.readFailure ? (
        <Button
          variant="outline"
          disabled={blocked}
          onClick={() => void controller.refresh()}
        >
          Try again
        </Button>
      ) : null}
    </div>
  );
}
function PreviewBody({
  preview,
  failure,
  gateway,
}: Readonly<{
  preview?: ParticipantPreview;
  failure?: ParticipantFailure;
  gateway?: InvitationProjectGateway;
}>) {
  return (
    <div className="grid gap-5">
      <h1 className="text-center text-3xl font-semibold tracking-tight sm:text-4xl">
        Join Project
      </h1>
      {failure ? (
        <FailureAlert failure={failure} />
      ) : !preview ? null : !preview.available ? (
        <Alert>
          <AlertTitle>Invitation unavailable</AlertTitle>
          <AlertDescription>
            This invitation cannot be used now. A previous pending join can
            still be checked after signing in.
          </AlertDescription>
        </Alert>
      ) : (
        <ParticipantProjectCard
          project={preview.project}
          title={preview.title}
          gateway={gateway}
        />
      )}
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
