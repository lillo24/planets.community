import type { Metadata } from "next";
import { GroupInviteFlow } from "@/features/group-invitations/group-invite-flow";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Group organizer invitation | PLANETS",
  robots: { index: false, follow: false, noarchive: true },
  referrer: "no-referrer",
};
export default async function GroupAuthorityPage({
  params,
}: PageProps<"/invite/group/[token]">) {
  const { token } = await params;
  return (
    <main className="mx-auto grid min-h-screen w-full max-w-xl content-center p-6 md:p-10">
      <section className="rounded-3xl border bg-card p-6 shadow-sm md:p-8">
        <GroupInviteFlow token={token} authority />
      </section>
    </main>
  );
}
