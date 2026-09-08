import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ActivityDiscoverySwitcher } from "@/components/activity-discovery-switcher";
import {
  formatOccurrence,
  formatRecurrence,
  RecurringActivityCard,
  RecurringActivityLifecycleBadge,
} from "./recurring-activity-components";
import type {
  PublicRecurringActivityDetail,
  PublicRecurringActivitySummary,
} from "./recurring-activity-models";

describe("public Tavoli presentation", () => {
  it("renders a linked card with topic, rough location, and event-zone meeting", () => {
    render(<RecurringActivityCard activity={summary} />);

    expect(
      screen.getByRole("link", { name: "Philosophy table" }),
    ).toHaveAttribute("href", `/tavoli/${summary.recurring_activity_id}`);
    expect(screen.getByText("Philosophy")).toBeInTheDocument();
    expect(screen.getByText("Trento · Povo")).toBeInTheDocument();
    expect(screen.getByText(/2 Jan 2030, 19:00/)).toBeInTheDocument();
    expect(screen.queryByText(/private room/i)).not.toBeInTheDocument();
  });

  it("formats the same instant in explicit event zones, including UTC", () => {
    expect(formatOccurrence(summary)).toContain("19:00");
    expect(
      formatOccurrence({
        local_starts_at: "2030-01-02T18:00:00",
        starts_at: "2030-01-02T18:00:00Z",
        ends_at: "2030-01-02T19:30:00Z",
        event_timezone: "UTC",
      }),
    ).toContain("18:00");
  });

  it("formats weekly and monthly recurrence from the schedule definition", () => {
    expect(formatRecurrence(detail.schedule)).toBe("Every Wednesday at 19:00");
    expect(
      formatRecurrence({
        ...detail.schedule,
        recurrence_type: "monthly",
        weekday: null,
        day_of_month: 12,
      }),
    ).toBe("Every month on day 12 at 19:00");
  });

  it("renders Active, Paused, and Ended lifecycle badges", () => {
    const view = render(
      <RecurringActivityLifecycleBadge lifecycle="published" />,
    );
    expect(screen.getByText("Active")).toHaveClass("bg-success");
    view.rerender(<RecurringActivityLifecycleBadge lifecycle="paused" />);
    expect(screen.getByText("Paused")).toBeInTheDocument();
    view.rerender(<RecurringActivityLifecycleBadge lifecycle="ended" />);
    expect(screen.getByText("Ended")).toBeInTheDocument();
  });

  it("marks the active activity discovery destination accessibly", () => {
    render(<ActivityDiscoverySwitcher active="tavoli" />);

    expect(
      screen.getByRole("navigation", { name: "Activity discovery" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Tavoli" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(
      screen.getByRole("link", { name: "One-time Proposals" }),
    ).not.toHaveAttribute("aria-current");
  });
});

export const summary: PublicRecurringActivitySummary = {
  recurring_activity_id: "00000000-0000-4000-8000-000000000001",
  title: "Philosophy table",
  summary: "Discuss one philosophical question every week.",
  topic: "Philosophy",
  country_code: "IT",
  locality: "Trento",
  administrative_area: "Povo",
  public_location_label: "Trento · Povo",
  next_starts_at: "2030-01-02T18:00:00Z",
  next_ends_at: "2030-01-02T19:30:00Z",
  event_timezone: "Europe/Rome",
};

export const detail: PublicRecurringActivityDetail = {
  recurring_activity_id: summary.recurring_activity_id,
  creator_display_name: "Casey",
  lifecycle_state: "published",
  title: summary.title,
  summary: summary.summary,
  description: "A recurring local discussion.",
  topic: summary.topic,
  country_code: summary.country_code,
  locality: summary.locality,
  administrative_area: summary.administrative_area,
  public_location_label: summary.public_location_label,
  schedule: {
    recurrence_type: "weekly",
    weekday: 3,
    day_of_month: null,
    local_start_time: "19:00:00",
    duration_minutes: 90,
    event_timezone: "Europe/Rome",
    schedule_effective_from: "2030-01-01",
  },
  next_occurrences: [
    {
      local_starts_at: "2030-01-02T19:00:00",
      starts_at: "2030-01-02T18:00:00Z",
      ends_at: "2030-01-02T19:30:00Z",
      event_timezone: "Europe/Rome",
    },
  ],
  exact_location: { kind: "restricted" },
};
