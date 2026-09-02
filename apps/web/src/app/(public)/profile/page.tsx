import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@/components/ui/button";
import { ProfileForm } from "@/features/profile/profile-form";
import { readProfilePageData } from "@/features/profile/profile-server";

export default async function ProfilePage() {
  const result = await readProfilePageData();
  if (result.status !== "ready") {
    redirect("/auth?returnTo=/profile");
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 p-6 md:p-10">
      <div>
        <Button variant="ghost" render={<Link href="/" />} nativeButton={false}>
          Back to home
        </Button>
      </div>
      <ProfileForm initialData={result.data} />
    </main>
  );
}
