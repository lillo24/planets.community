import type { Metadata } from "next";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { readCurrentAuth } from "@/features/auth/current-auth";
import { ProjectInviteAction } from "@/features/project-delegates/project-invite-action";
import type { ProjectDelegateInvitePreview } from "@/features/project-delegates/project-delegate-models";
import { previewProjectDelegateInvitation } from "@/features/project-delegates/project-delegate-server";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Project authority invitation | PLANETS",
  robots: { index: false, follow: false, noarchive: true },
};

export default async function ProjectDelegateInvitePage({
  params,
}: PageProps<"/invite/project/[token]">) {
  const { token } = await params;
  const [preview, auth] = await Promise.all([
    safePreview(token),
    readCurrentAuth(),
  ]);

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl items-center p-6 md:p-10">
      {!preview.isAvailable ? (
        <Card className="w-full" aria-labelledby="invite-title">
          <CardHeader>
            <CardTitle id="invite-title">Invitation unavailable</CardTitle>
            <CardDescription>
              This invitation can&apos;t be used. Ask the Project Creator or a
              Co-creator for a new link.
            </CardDescription>
          </CardHeader>
          <CardFooter>
            <Button render={<Link href="/" />} nativeButton={false}>
              Back to PLANETS
            </Button>
          </CardFooter>
        </Card>
      ) : (
        <Card className="w-full" aria-labelledby="invite-title">
          <CardHeader>
            <CardTitle id="invite-title">
              {preview.requestedAuthorityRole === "co_creator"
                ? "Co-creator invitation"
                : "Co-organizer invitation"}
            </CardTitle>
            <CardDescription>
              {preview.issuerDisplayName
                ? `${preview.issuerDisplayName} invited you to become a ${
                    preview.requestedAuthorityRole === "co_creator"
                      ? "Co-creator"
                      : "Co-organizer"
                  }:`
                : `You've been invited to become a ${
                    preview.requestedAuthorityRole === "co_creator"
                      ? "Co-creator"
                      : "Co-organizer"
                  }:`}
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3">
            <p className="text-2xl font-semibold">{preview.projectTitle}</p>
            <p className="text-sm text-muted-foreground">
              This invitation expires {formatExpiry(preview.expiresAt)}.
            </p>
          </CardContent>
          <CardFooter>
            <ProjectInviteAction auth={auth} preview={preview} token={token} />
          </CardFooter>
        </Card>
      )}
    </main>
  );
}

async function safePreview(
  token: string,
): Promise<ProjectDelegateInvitePreview> {
  try {
    return await previewProjectDelegateInvitation(token);
  } catch {
    return { isAvailable: false };
  }
}

function formatExpiry(value: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}
