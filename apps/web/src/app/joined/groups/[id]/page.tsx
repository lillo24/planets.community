import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { groupIdPattern } from "@/features/group-invitations/group-models";
import { GroupLanding } from "@/features/group-invitations/group-landing";
import { readHandoffConfig } from "@/features/project-app-handoff/handoff-config";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Your group | PLANETS",
  robots: { index: false, follow: false, noarchive: true },
  referrer: "no-referrer",
};
export default async function GroupConfirmationPage({
  params,
}: PageProps<"/joined/groups/[id]">) {
  const { id } = await params;
  if (!groupIdPattern.test(id)) notFound();
  return (
    <main className="mx-auto grid min-h-screen w-full max-w-xl content-center p-6 md:p-10">
      <section className="rounded-3xl border bg-card p-6 shadow-sm md:p-8">
        <GroupLanding id={id} confirmation config={readHandoffConfig()} />
      </section>
    </main>
  );
}
