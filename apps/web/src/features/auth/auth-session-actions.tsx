"use client";

import { CircleAlertIcon } from "lucide-react";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";

import {
  authFailureMessage,
  mapAuthFailure,
  type AuthFailureKind,
} from "@/features/auth/auth-models";
import {
  createWebAuthGateway,
  type WebAuthGateway,
} from "@/features/auth/auth-gateway";
import type { AuthNavigation } from "@/features/auth/auth-flow";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";

type AuthSessionActionsProps = Readonly<{
  profileSetupRequired: boolean;
  returnTo: string;
  gateway?: WebAuthGateway;
  navigation?: AuthNavigation;
}>;

type BusyAction = "profile" | "signOut";

export function AuthSessionActions({
  profileSetupRequired,
  returnTo,
  gateway,
  navigation,
}: AuthSessionActionsProps) {
  const router = useRouter();
  const [authGateway] = useState(() => gateway ?? createWebAuthGateway());
  const authNavigation = navigation ?? router;
  const lock = useRef(false);
  const [busy, setBusy] = useState<BusyAction | null>(null);
  const [failure, setFailure] = useState<AuthFailureKind | null>(null);

  async function retryProfileSetup() {
    if (lock.current) {
      return;
    }
    lock.current = true;
    setBusy("profile");
    setFailure(null);
    try {
      await authGateway.ensureCurrentProfileAnchor();
      authNavigation.replace(returnTo);
      authNavigation.refresh();
    } catch {
      setFailure("profileSetup");
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  async function signOut() {
    if (lock.current) {
      return;
    }
    lock.current = true;
    setBusy("signOut");
    setFailure(null);
    try {
      await authGateway.signOut();
      authNavigation.replace("/");
      authNavigation.refresh();
    } catch (error) {
      setFailure(mapAuthFailure(error));
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  return (
    <div className="flex w-full flex-col gap-3">
      {failure ? (
        <Alert variant="destructive" aria-live="polite">
          <CircleAlertIcon />
          <AlertTitle>Session action failed</AlertTitle>
          <AlertDescription>{authFailureMessage(failure)}</AlertDescription>
        </Alert>
      ) : null}
      <div className="flex flex-wrap gap-2">
        {profileSetupRequired ? (
          <Button
            type="button"
            onClick={retryProfileSetup}
            disabled={busy !== null}
          >
            {busy === "profile" ? <Spinner data-icon="inline-start" /> : null}
            Try setup again
          </Button>
        ) : null}
        <Button
          type="button"
          variant="outline"
          onClick={signOut}
          disabled={busy !== null}
        >
          {busy === "signOut" ? <Spinner data-icon="inline-start" /> : null}
          Sign out
        </Button>
      </div>
    </div>
  );
}
