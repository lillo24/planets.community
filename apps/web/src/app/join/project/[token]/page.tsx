import type { Metadata } from "next";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { readHandoffConfig } from "@/features/project-app-handoff/handoff-config";
import { ParticipantInviteFlow } from "@/features/project-participant-invites/participant-invite-flow";
import { readParticipantPreview } from "@/features/project-participant-invites/participant-server";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Participant invitation | PLANETS",
  robots: { index: false, follow: false, noarchive: true },
  referrer: "no-referrer",
};
export default async function ParticipantInvitePage({
  params,
}: PageProps<"/join/project/[token]">) {
  const { token } = await params;
  const initialRead = await readParticipantPreview(token);
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl items-center p-6 md:p-10">
      <Card className="w-full" aria-labelledby="participant-invite-title">
        <CardHeader>
          <CardTitle id="participant-invite-title">
            Participant invitation
          </CardTitle>
          <CardDescription>
            Anyone receiving or forwarding this link can join while the activity
            accepts participants and places remain. It reserves no place and
            grants no organizer role.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ParticipantInviteFlow
            token={token}
            initialRead={initialRead}
            config={readHandoffConfig()}
          />
        </CardContent>
      </Card>
    </main>
  );
}
