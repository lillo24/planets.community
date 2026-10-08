import { LocationAttribution } from "@/features/locations/location-attribution";
import Link from "next/link";
import { notFound } from "next/navigation";
import { CalendarDaysIcon, MapPinIcon } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  formatOccurrence,
  RecurringActivityLifecycleBadge,
  RecurringActivitySchedule,
} from "@/features/recurring-activities/recurring-activity-components";
import {
  isRecurringActivityUuid,
  type PublicRecurringActivityDetail,
} from "@/features/recurring-activities/recurring-activity-models";
import { getPublicRecurringActivity } from "@/features/recurring-activities/recurring-activity-server";
import { OrdinaryProjectHandoff } from "@/features/project-app-handoff/ordinary-project-handoff";
import { readHandoffConfig } from "@/features/project-app-handoff/handoff-config";
import { hasOrdinaryIntent } from "@/features/project-app-handoff/project-links";

export const dynamic = "force-dynamic";

type Params = Promise<{ id: string }>;

export default async function TavoloDetailPage({
  params,
  searchParams,
}: {
  params: Params;
  searchParams?: Promise<{ intent?: string | string[] }>;
}) {
  const [{ id }, query] = await Promise.all([
    params,
    searchParams ?? Promise.resolve<{ intent?: string | string[] }>({}),
  ]);
  if (!isRecurringActivityUuid(id)) notFound();

  const referenceTime = new Date().toISOString();
  const result = await loadDetail(id, referenceTime);
  if (result.status === "error") {
    return (
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-8 p-6 md:p-10">
        <Link href="/tavoli">← All Tavoli</Link>
        <Alert variant="destructive">
          <AlertTitle>Tavolo temporarily unavailable</AlertTitle>
          <AlertDescription>
            We could not load this public Tavolo. Please try again.
          </AlertDescription>
        </Alert>
      </main>
    );
  }
  const activity = result.activity;
  if (!activity) notFound();

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-8 p-6 md:p-10">
      <Link
        className="text-sm text-muted-foreground hover:text-foreground"
        href="/tavoli"
      >
        ← All Tavoli
      </Link>
      <article className="flex flex-col gap-8">
        <header className="flex flex-col gap-3">
          <div className="flex items-start justify-between gap-4">
            <h1 className="text-4xl font-semibold">{activity.title}</h1>
            <RecurringActivityLifecycleBadge
              lifecycle={activity.lifecycle_state}
            />
          </div>
          <p className="text-xl text-muted-foreground">{activity.summary}</p>
          {activity.topic ? (
            <p>
              <span className="font-medium">Topic:</span> {activity.topic}
            </p>
          ) : null}
        </header>
        <Card>
          <CardHeader>
            <CardTitle>Schedule and location</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-5">
            <RecurringActivitySchedule activity={activity} />
            <p className="text-sm text-muted-foreground">
              Current schedule effective from{" "}
              {formatEffectiveDate(activity.schedule.schedule_effective_from)}
            </p>
            <p className="flex gap-2">
              <MapPinIcon aria-hidden="true" className="size-5 shrink-0" />
              {activity.public_location_label}
            </p>
            <LocationAttribution />
            {activity.exact_location.kind === "restricted" ? (
              <p data-testid="restricted-location">
                Exact location available after joining.
              </p>
            ) : (
              <p data-testid="public-exact-location">
                {activity.exact_location.text}
              </p>
            )}
          </CardContent>
        </Card>
        {activity.lifecycle_state === "published" ? (
          <section className="grid gap-3">
            <h2 className="text-2xl font-semibold">Upcoming meetings</h2>
            <ul className="grid gap-3">
              {activity.next_occurrences.map((occurrence) => (
                <li
                  className="flex gap-2 rounded-lg border p-3"
                  key={occurrence.starts_at}
                >
                  <CalendarDaysIcon
                    aria-hidden="true"
                    className="size-5 shrink-0"
                  />
                  {formatOccurrence(occurrence)}
                </li>
              ))}
            </ul>
          </section>
        ) : (
          <p className="rounded-lg bg-muted/50 p-4 text-muted-foreground">
            {activity.lifecycle_state === "paused"
              ? "This Tavolo is paused, so no upcoming meetings are currently listed."
              : "This Tavolo has ended and no longer lists upcoming meetings."}
          </p>
        )}
        <section className="grid gap-3">
          <h2 className="text-2xl font-semibold">About this Tavolo</h2>
          <p className="whitespace-pre-wrap text-base leading-7">
            {activity.description}
          </p>
        </section>
        {activity.creator_display_name ? (
          <p className="text-sm text-muted-foreground">
            Organized by {activity.creator_display_name}
          </p>
        ) : null}
      </article>
      <OrdinaryProjectHandoff
        project={{ id, kind: "recurring" }}
        config={readHandoffConfig()}
        intent={hasOrdinaryIntent(query.intent)}
        joinable={activity.lifecycle_state === "published"}
      />
    </main>
  );
}

async function loadDetail(
  id: string,
  referenceTime: string,
): Promise<
  | { status: "ready"; activity: PublicRecurringActivityDetail | null }
  | { status: "error" }
> {
  try {
    return {
      status: "ready",
      activity: await getPublicRecurringActivity(id, referenceTime),
    };
  } catch {
    return { status: "error" };
  }
}

function formatEffectiveDate(value: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(new Date(`${value}T00:00:00Z`));
}
