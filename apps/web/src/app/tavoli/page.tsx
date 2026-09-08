import Link from "next/link";
import { SearchXIcon } from "lucide-react";

import { ActivityDiscoverySwitcher } from "@/components/activity-discovery-switcher";
import { EmptyState } from "@/components/states/empty-state";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationNext,
} from "@/components/ui/pagination";
import { RecurringActivityCard } from "@/features/recurring-activities/recurring-activity-components";
import {
  createPublicRecurringActivityListRequest,
  encodeRecurringActivityCursor,
  type PublicRecurringActivityListRequest,
  type PublicRecurringActivitySummary,
} from "@/features/recurring-activities/recurring-activity-models";
import {
  listPublicRecurringActivities,
  publicRecurringActivityPageSize,
} from "@/features/recurring-activities/recurring-activity-server";

export const dynamic = "force-dynamic";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function TavoliPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const request = createPublicRecurringActivityListRequest({
    locality: single(params.locality),
    cursor: single(params.cursor),
  });
  const result = await loadPageData(request);

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 p-6 md:p-10">
      <header className="flex flex-col gap-3">
        <Link className="text-sm font-semibold tracking-[0.2em]" href="/">
          PLANETS
        </Link>
        <h1 className="text-4xl font-semibold">Tavoli</h1>
        <p className="max-w-2xl text-lg text-muted-foreground">
          Find a local group that meets regularly to learn, discuss, create, or
          help together.
        </p>
        <ActivityDiscoverySwitcher active="tavoli" />
      </header>
      {result.status === "error" ? (
        <Alert variant="destructive">
          <AlertTitle>Tavoli are temporarily unavailable</AlertTitle>
          <AlertDescription>
            We could not load public Tavoli. Please try again.
          </AlertDescription>
        </Alert>
      ) : (
        <TavoliResults request={request} activities={result.activities} />
      )}
    </main>
  );
}

function TavoliResults({
  request,
  activities,
}: {
  request: PublicRecurringActivityListRequest;
  activities: PublicRecurringActivitySummary[];
}) {
  const nextCursor =
    activities.length === publicRecurringActivityPageSize
      ? encodeRecurringActivityCursor({
          version: 1,
          referenceTime: request.referenceTime,
          nextStartsAt: activities[activities.length - 1].next_starts_at,
          recurringActivityId:
            activities[activities.length - 1].recurring_activity_id,
          locality: request.locality ?? null,
        })
      : undefined;

  return (
    <>
      <form
        className="grid gap-3 rounded-xl bg-muted/40 p-4 sm:grid-cols-[1fr_auto]"
        action="/tavoli"
      >
        <label className="grid gap-1 text-sm font-medium">
          Locality
          <Input
            name="locality"
            defaultValue={request.locality}
            maxLength={120}
            placeholder="For example, Bologna"
          />
        </label>
        <Button className="self-end" type="submit">
          Filter
        </Button>
      </form>
      {activities.length === 0 ? (
        <EmptyState
          title="No Tavoli found"
          description="Try another locality or check again later."
          icon={<SearchXIcon />}
        />
      ) : (
        <section
          aria-label="Tavoli results"
          className="grid gap-5 md:grid-cols-2"
        >
          {activities.map((activity) => (
            <RecurringActivityCard
              key={activity.recurring_activity_id}
              activity={activity}
            />
          ))}
        </section>
      )}
      {nextCursor ? (
        <Pagination>
          <PaginationContent>
            <PaginationItem>
              <PaginationNext
                text="More Tavoli"
                href={tavoliUrl({
                  locality: request.locality,
                  cursor: nextCursor,
                })}
              />
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      ) : null}
    </>
  );
}

async function loadPageData(
  request: PublicRecurringActivityListRequest,
): Promise<
  | { status: "ready"; activities: PublicRecurringActivitySummary[] }
  | { status: "error" }
> {
  try {
    return {
      status: "ready",
      activities: await listPublicRecurringActivities(request),
    };
  } catch {
    return { status: "error" };
  }
}

export function tavoliUrl({
  locality,
  cursor,
}: {
  locality?: string;
  cursor?: string;
}): string {
  const query = new URLSearchParams();
  if (locality) query.set("locality", locality);
  if (cursor) query.set("cursor", cursor);
  const suffix = query.toString();
  return suffix ? `/tavoli?${suffix}` : "/tavoli";
}

function single(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}
