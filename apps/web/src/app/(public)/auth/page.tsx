import { redirect } from "next/navigation";

import { AuthFlow } from "@/features/auth/auth-flow";
import { AuthStatusCard } from "@/features/auth/auth-status-card";
import { readCurrentAuth } from "@/features/auth/current-auth";
import { sanitizeReturnDestination } from "@/features/auth/return-destination";

export default async function AuthPage({ searchParams }: PageProps<"/auth">) {
  const [query, authState] = await Promise.all([
    searchParams,
    readCurrentAuth(),
  ]);
  const returnTo = sanitizeReturnDestination(
    typeof query.returnTo === "string" ? query.returnTo : undefined,
  );

  if (authState.status === "ready") {
    redirect(returnTo);
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      {authState.status === "profileSetupRequired" ? (
        <AuthStatusCard state={authState} returnTo={returnTo} />
      ) : (
        <AuthFlow returnTo={returnTo} />
      )}
    </main>
  );
}
