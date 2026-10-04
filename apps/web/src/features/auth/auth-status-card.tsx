import Link from "next/link";

import type { CurrentAuthState } from "@/features/auth/auth-models";
import { AuthSessionActions } from "@/features/auth/auth-session-actions";
import { Button, buttonVariants } from "@/components/ui/button";
import { participantCancelDestination } from "./return-destination";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

type AuthStatusCardProps = Readonly<{
  state: CurrentAuthState;
  returnTo?: string;
}>;

export function AuthStatusCard({ state, returnTo = "/" }: AuthStatusCardProps) {
  if (state.status === "signedOut") {
    return (
      <Card className="w-full max-w-md" aria-labelledby="auth-status-title">
        <CardHeader>
          <CardTitle id="auth-status-title">Join when you are ready</CardTitle>
          <CardDescription>
            Public browsing stays available without an account.
          </CardDescription>
        </CardHeader>
        <CardContent>
          Sign in only when you want to take part in a community activity.
        </CardContent>
        <CardFooter>
          <Button render={<Link href="/auth" />} nativeButton={false}>
            Sign in
          </Button>
        </CardFooter>
      </Card>
    );
  }

  const profileSetupRequired = state.status === "profileSetupRequired";
  const incompleteProfile =
    profileSetupRequired && state.reason === "incomplete";
  const cancelTo = participantCancelDestination(returnTo);
  // A signed-out profile visit wraps its destination in /profile?returnTo=… .
  // Participant setup must return directly to explicit Join after one save.
  const profileReturnTo = cancelTo.startsWith("/join/project/")
    ? cancelTo
    : returnTo;

  return (
    <Card className="w-full max-w-md" aria-labelledby="auth-status-title">
      <CardHeader>
        <CardTitle id="auth-status-title">
          {incompleteProfile
            ? "Complete your profile"
            : profileSetupRequired
              ? "Session setup needed"
              : "Signed in"}
        </CardTitle>
        <CardDescription>
          {incompleteProfile
            ? "Add a display name to finish your basic profile."
            : profileSetupRequired
              ? "Your session is active, but the application setup still needs to finish."
              : "Your PLANETS session is ready."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {incompleteProfile
          ? "Public browsing remains available while profile setup is incomplete."
          : profileSetupRequired
            ? "Retry the minimal account setup or sign out."
            : "Public discovery remains available while you are signed in."}
      </CardContent>
      <CardFooter className="items-stretch">
        <div className="flex w-full flex-col gap-3">
          {incompleteProfile ? (
            <Button
              render={
                <Link
                  href={
                    profileReturnTo === "/"
                      ? "/profile"
                      : `/profile?returnTo=${encodeURIComponent(profileReturnTo)}`
                  }
                />
              }
              nativeButton={false}
            >
              Complete profile
            </Button>
          ) : null}
          <AuthSessionActions
            profileSetupRequired={profileSetupRequired && !incompleteProfile}
            returnTo={returnTo}
          />
          {profileSetupRequired && cancelTo !== "/" ? (
            <Link
              className={buttonVariants({ variant: "outline" })}
              href={cancelTo}
              prefetch={false}
            >
              Back to invitation
            </Link>
          ) : null}
        </div>
      </CardFooter>
    </Card>
  );
}
