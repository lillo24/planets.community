import Link from "next/link";
import { notFound } from "next/navigation";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { ModerationCaseDetailView } from "@/features/moderation/moderation-components";
import { ModerationConsequencesSection } from "@/features/moderation/moderation-consequence-components";
import { isUuid } from "@/features/moderation/moderation-models";
import { readModerationCase } from "@/features/moderation/moderation-server";

export default async function ModerationCasePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const result = await readModerationCase(id).catch(() => null);
  if (result === null) {
    return (
      <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col gap-6 p-6 md:p-10">
        <Link href="/admin">← Moderation queue</Link>
        <Alert variant="destructive">
          <AlertTitle>Case unavailable</AlertTitle>
          <AlertDescription>
            This case could not be loaded. No review action was performed.
          </AlertDescription>
        </Alert>
      </main>
    );
  }
  if (result.status === "denied" || result.detail === null) notFound();
  return (
    <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col gap-6 p-6 md:p-10">
      <Link className="text-sm font-medium" href="/admin">
        ← Moderation queue
      </Link>
      <header className="grid gap-2">
        <h1 className="text-4xl font-semibold">Moderation case</h1>
        <p className="font-mono text-xs text-muted-foreground">{id}</p>
      </header>
      <ModerationCaseDetailView detail={result.detail} />
      <ModerationConsequencesSection
        detail={result.detail}
        episodes={result.consequences}
        staffRole={result.staffRole}
        staffProfileId={result.staffProfileId}
      />
    </main>
  );
}
