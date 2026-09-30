import Link from "next/link";
import { notFound } from "next/navigation";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/states/empty-state";
import { ModerationCaseCard } from "@/features/moderation/moderation-components";
import {
  decodeModerationCursor,
  isModerationState,
  type ModerationState,
} from "@/features/moderation/moderation-models";
import { readModerationQueue } from "@/features/moderation/moderation-server";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function AdminPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const rawState = single(params.state);
  const state: ModerationState | undefined = isModerationState(rawState)
    ? rawState
    : undefined;
  const result = await readModerationQueue({
    state,
    cursor: decodeModerationCursor(single(params.cursor)),
  }).catch(() => null);
  if (result === null) {
    return (
      <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 p-6 md:p-10">
        <h1 className="text-4xl font-semibold">Moderation queue</h1>
        <Alert variant="destructive">
          <AlertTitle>Queue unavailable</AlertTitle>
          <AlertDescription>
            The moderation queue could not be loaded. Try again without changing
            case data.
          </AlertDescription>
        </Alert>
      </main>
    );
  }
  if (result.status === "denied") notFound();
  const nextHref = result.page.nextCursor
    ? queueUrl({ state, cursor: result.page.nextCursor })
    : undefined;
  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 p-6 md:p-10">
      <header className="grid gap-2">
        <Link className="text-sm font-semibold tracking-[0.2em]" href="/">
          PLANETS
        </Link>
        <h1 className="text-4xl font-semibold">Moderation queue</h1>
        <p className="text-muted-foreground">
          Signed in as {result.staffRole}. Reports are reviewed manually and do
          not automatically restrict people or content.
        </p>
      </header>
      <nav aria-label="Review state" className="flex flex-wrap gap-2">
        {(
          [
            [undefined, "All"],
            ["received", "Received"],
            ["under_review", "Under review"],
            ["completed", "Completed"],
          ] as const
        ).map(([value, label]) => (
          <Button
            key={label}
            variant={state === value ? "default" : "outline"}
            render={<Link href={queueUrl({ state: value })} />}
            nativeButton={false}
          >
            {label}
          </Button>
        ))}
      </nav>
      {result.page.cases.length === 0 ? (
        <EmptyState
          title="No cases in this queue"
          description="Try another review state or check again later."
        />
      ) : (
        <section
          aria-label="Moderation cases"
          className="grid gap-4 md:grid-cols-2"
        >
          {result.page.cases.map((item) => (
            <ModerationCaseCard key={item.caseId} item={item} />
          ))}
        </section>
      )}
      {nextHref ? (
        <Button
          variant="outline"
          className="self-start"
          render={<Link href={nextHref} />}
          nativeButton={false}
        >
          More cases
        </Button>
      ) : null}
    </main>
  );
}

export function queueUrl({
  state,
  cursor,
}: Readonly<{ state?: ModerationState; cursor?: string }>): string {
  const params = new URLSearchParams();
  if (state) params.set("state", state);
  if (cursor) params.set("cursor", cursor);
  const query = params.toString();
  return query ? `/admin?${query}` : "/admin";
}

function single(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}
