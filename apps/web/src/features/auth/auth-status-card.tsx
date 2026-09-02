import Link from "next/link";

import type { CurrentAuthState } from "@/features/auth/auth-models";
import { AuthSessionActions } from "@/features/auth/auth-session-actions";
import { Button } from "@/components/ui/button";
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

  return (
    <Card className="w-full max-w-md" aria-labelledby="auth-status-title">
      <CardHeader>
        <CardTitle id="auth-status-title">
          {profileSetupRequired ? "Session setup needed" : "Signed in"}
        </CardTitle>
        <CardDescription>
          {profileSetupRequired
            ? "Your session is active, but the application setup still needs to finish."
            : "Your PLANETS session is ready."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {profileSetupRequired
          ? "Retry the minimal account setup or sign out."
          : "Public discovery remains available while you are signed in."}
      </CardContent>
      <CardFooter className="items-stretch">
        <AuthSessionActions
          profileSetupRequired={profileSetupRequired}
          returnTo={returnTo}
        />
      </CardFooter>
    </Card>
  );
}
