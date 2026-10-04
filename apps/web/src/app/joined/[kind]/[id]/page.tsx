import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { readHandoffConfig } from "@/features/project-app-handoff/handoff-config";
import { projectPath } from "@/features/project-app-handoff/project-links";
import { ParticipantConfirmation } from "@/features/project-participant-invites/participant-confirmation";
import {
  projectIdPattern,
  type ProjectContext,
} from "@/features/project-participant-invites/participant-models";
import { readParticipantConfirmation } from "@/features/project-participant-invites/participant-server";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Project participation | PLANETS",
  robots: { index: false, follow: false, noarchive: true },
  referrer: "no-referrer",
};
export default async function ParticipantConfirmationPage({
  params,
}: PageProps<"/joined/[kind]/[id]">) {
  const { kind, id } = await params;
  if (!projectIdPattern.test(id) || !["proposals", "tavoli"].includes(kind))
    notFound();
  const project: ProjectContext = {
    id,
    kind: kind === "proposals" ? "one_time" : "recurring",
  };
  const read = await readParticipantConfirmation(project);
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl items-center p-6 md:p-10">
      <Card className="w-full" aria-labelledby="participant-confirmation-title">
        <CardHeader>
          <CardTitle id="participant-confirmation-title">
            Project participation
          </CardTitle>
          <CardDescription>
            Check your current participation, then continue in PLANETS.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ParticipantConfirmation
            project={project}
            config={readHandoffConfig()}
          />
          <noscript>
            <p>
              {read.failure
                ? "Participation could not be verified. Reload to retry."
                : read.auth.phase === "signedOut"
                  ? "Sign in to check your participation."
                  : read.participation?.creator
                    ? "You own this Project."
                    : read.participation?.current
                      ? "You currently participate in this Project."
                      : "You do not currently participate in this Project."}
            </p>
            <Link href={projectPath(project)}>View public Project</Link>
            <p>
              Enable JavaScript to recheck your account and use the app/download
              actions.
            </p>
          </noscript>
        </CardContent>
      </Card>
    </main>
  );
}
