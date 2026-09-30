import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@/components/ui/button";
import { ProfileForm } from "@/features/profile/profile-form";
import { readProfilePageData } from "@/features/profile/profile-server";
import { sanitizeReturnDestination } from "@/features/auth/return-destination";

export default async function ProfilePage({
  searchParams,
}: PageProps<"/profile">) {
  const [query, result] = await Promise.all([
    searchParams,
    readProfilePageData(),
  ]);
  const requestedReturnTo =
    typeof query.returnTo === "string" ? query.returnTo : undefined;
  const returnTo = requestedReturnTo
    ? sanitizeReturnDestination(requestedReturnTo)
    : "/profile";
  if (result.status !== "ready") {
    const profileDestination = requestedReturnTo
      ? `/profile?returnTo=${encodeURIComponent(returnTo)}`
      : "/profile";
    redirect(
      requestedReturnTo
        ? `/auth?returnTo=${encodeURIComponent(profileDestination)}`
        : "/auth?returnTo=/profile",
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 p-6 md:p-10">
      <div>
        <Button variant="ghost" render={<Link href="/" />} nativeButton={false}>
          Back to home
        </Button>
      </div>
      <ProfileForm initialData={result.data} returnTo={returnTo} />
    </main>
  );
}
