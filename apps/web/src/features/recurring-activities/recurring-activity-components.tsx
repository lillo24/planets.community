import Link from "next/link";
import {
  CalendarDaysIcon,
  ClockIcon,
  MapPinIcon,
  RepeatIcon,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import type {
  PublicRecurringActivityDetail,
  PublicRecurringActivityLifecycle,
  PublicRecurringActivityOccurrence,
  PublicRecurringActivitySummary,
  PublicRecurringSchedule,
} from "./recurring-activity-models";

const lifecycleLabels: Record<PublicRecurringActivityLifecycle, string> = {
  published: "Active",
  paused: "Paused",
  ended: "Ended",
};

const weekdayLabels = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
] as const;

export function RecurringActivityLifecycleBadge({
  lifecycle,
}: {
  lifecycle: PublicRecurringActivityLifecycle;
}) {
  const variant =
    lifecycle === "published"
      ? "success"
      : lifecycle === "paused"
        ? "secondary"
        : "outline";
  return <Badge variant={variant}>{lifecycleLabels[lifecycle]}</Badge>;
}

export function RecurringActivityCard({
  activity,
}: {
  activity: PublicRecurringActivitySummary;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <Link href={`/tavoli/${activity.recurring_activity_id}`}>
            {activity.title}
          </Link>
        </CardTitle>
        <CardDescription>{activity.summary}</CardDescription>
        {activity.topic ? (
          <CardAction>
            <Badge variant="outline">{activity.topic}</Badge>
          </CardAction>
        ) : null}
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="flex gap-2 text-muted-foreground">
          <CalendarDaysIcon aria-hidden="true" className="size-4 shrink-0" />
          <span>
            <span className="font-medium text-foreground">Next meeting:</span>{" "}
            {formatOccurrence(activity)}
          </span>
        </p>
        <p className="flex gap-2 text-muted-foreground">
          <MapPinIcon aria-hidden="true" className="size-4 shrink-0" />
          {activity.public_location_label}
        </p>
      </CardContent>
    </Card>
  );
}

export function RecurringActivitySchedule({
  activity,
}: {
  activity: PublicRecurringActivityDetail;
}) {
  return (
    <div className="grid gap-3">
      <p className="flex gap-2">
        <RepeatIcon aria-hidden="true" className="size-5 shrink-0" />
        {formatRecurrence(activity.schedule)}
      </p>
      <p className="flex gap-2">
        <ClockIcon aria-hidden="true" className="size-5 shrink-0" />
        Duration: {formatDuration(activity.schedule.duration_minutes)}
      </p>
      <p className="text-sm text-muted-foreground">
        Time zone: {activity.schedule.event_timezone}
      </p>
    </div>
  );
}

export function formatOccurrence(
  occurrence:
    | PublicRecurringActivityOccurrence
    | Pick<
        PublicRecurringActivitySummary,
        "next_starts_at" | "next_ends_at" | "event_timezone"
      >,
): string {
  const startsAt =
    "starts_at" in occurrence
      ? occurrence.starts_at
      : occurrence.next_starts_at;
  const endsAt =
    "ends_at" in occurrence ? occurrence.ends_at : occurrence.next_ends_at;
  const formatter = new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: occurrence.event_timezone,
  });
  return `${formatter.format(new Date(startsAt))} – ${formatter.format(new Date(endsAt))} (${occurrence.event_timezone})`;
}

export function formatRecurrence(schedule: PublicRecurringSchedule): string {
  const time = schedule.local_start_time.slice(0, 5);
  return schedule.recurrence_type === "weekly"
    ? `Every ${weekdayLabels[schedule.weekday - 1]} at ${time}`
    : `Every month on day ${schedule.day_of_month} at ${time}`;
}

export function formatDuration(minutes: number): string {
  return `${minutes} ${minutes === 1 ? "minute" : "minutes"}`;
}
