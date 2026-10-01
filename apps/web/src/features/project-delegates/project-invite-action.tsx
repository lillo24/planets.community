"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import type { CurrentAuthState } from "@/features/auth/auth-models";
import {
  createWebProjectDelegateGateway,
  type WebProjectDelegateGateway,
} from "./project-delegate-gateway";
import {
  mapProjectDelegateAcceptFailure,
  type ProjectDelegateAcceptFailure,
  type ProjectDelegateInvitePreview,
} from "./project-delegate-models";

type InviteNavigation = Readonly<{ replace(destination: string): void }>;

export function ProjectInviteAction({
  auth,
  preview,
  token,
  gateway,
  navigation,
}: Readonly<{
  auth: CurrentAuthState;
  preview: Extract<ProjectDelegateInvitePreview, { isAvailable: true }>;
  token: string;
  gateway?: WebProjectDelegateGateway;
  navigation?: InviteNavigation;
}>) {
  const router = useRouter();
  const inviteNavigation = navigation ?? router;
  const [delegateGateway] = useState(
    () => gateway ?? createWebProjectDelegateGateway(),
  );
  const lock = useRef(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<ProjectDelegateAcceptFailure | null>(
    null,
  );
  const returnTo = `/invite/project/${token}`;

  if (auth.status === "signedOut") {
    return (
      <Button
        render={
          <Link href={`/auth?returnTo=${encodeURIComponent(returnTo)}`} />
        }
        nativeButton={false}
      >
        Sign in to accept
      </Button>
    );
  }
  if (auth.status === "profileSetupRequired") {
    const destination =
      auth.reason === "incomplete"
        ? `/profile?returnTo=${encodeURIComponent(returnTo)}`
        : `/auth?returnTo=${encodeURIComponent(returnTo)}`;
    return (
      <Button render={<Link href={destination} />} nativeButton={false}>
        Complete profile to accept
      </Button>
    );
  }

  async function accept() {
    if (lock.current || auth.status !== "ready") return;
    lock.current = true;
    setBusy(true);
    setFailure(null);
    try {
      await delegateGateway.acceptInvitation(auth.profileId, token);
      inviteNavigation.replace(
        preview.projectKind === "one_time"
          ? `/proposals/${preview.projectId}`
          : `/tavoli/${preview.projectId}`,
      );
    } catch (error) {
      setFailure(mapProjectDelegateAcceptFailure(error));
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }

  return (
    <div className="grid gap-3">
      {failure ? (
        <Alert variant="destructive" aria-live="polite">
          <AlertTitle>Invitation not accepted</AlertTitle>
          <AlertDescription>{failureMessage(failure)}</AlertDescription>
        </Alert>
      ) : null}
      <Button onClick={accept} disabled={busy}>
        {busy ? <Spinner data-icon="inline-start" /> : null}
        Accept invitation
      </Button>
    </div>
  );
}

function failureMessage(failure: ProjectDelegateAcceptFailure): string {
  switch (failure) {
    case "owner":
      return "You already own this Project.";
    case "alreadyDelegate":
      return "You already co-organize this Project.";
    case "unavailable":
      return "This invitation could not be accepted. Ask the Project owner for a new link.";
  }
}
