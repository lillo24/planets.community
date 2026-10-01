import { existsSync } from "node:fs";
import { resolve } from "node:path";

import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  decodeRecurringActivityCursor,
  type PublicRecurringActivityDetail,
  type PublicRecurringActivitySummary,
} from "@/features/recurring-activities/recurring-activity-models";

const listPublicRecurringActivities = vi.fn();
const getPublicRecurringActivity = vi.fn();
const readCurrentAuth = vi.fn();
const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});

vi.mock("next/navigation", () => ({ notFound }));
vi.mock("@/features/recurring-activities/recurring-activity-server", () => ({
  publicRecurringActivityPageSize: 12,
  publicRecurringActivityOccurrenceLimit: 5,
  listPublicRecurringActivities,
  getPublicRecurringActivity,
}));
vi.mock("@/features/auth/current-auth", () => ({ readCurrentAuth }));

const activityId = "00000000-0000-4000-8000-000000000001";
const referenceTime = "2030-01-01T00:00:00.000Z";

describe("public Tavoli routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    vi.setSystemTime(new Date(referenceTime));
  });

  afterEach(() => {
    cleanup();
    vi.useRealTimers();
  });

  it("loads the signed-out list, normalizes locality, and preserves its snapshot cursor", async () => {
    listPublicRecurringActivities.mockResolvedValue(
      Array.from({ length: 12 }, (_, index) => ({
        ...summary,
        recurring_activity_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
      })),
    );
    const { default: Page } = await import("@/app/tavoli/page");
    render(
      await Page({
        searchParams: Promise.resolve({ locality: " Trento " }),
      }),
    );

    expect(listPublicRecurringActivities).toHaveBeenCalledWith({
      referenceTime,
      locality: "Trento",
    });
    expect(screen.getByRole("heading", { name: "Tavoli" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Tavoli" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    const href = screen
      .getByRole("button", { name: /Go to next page/i })
      .getAttribute("href");
    expect(href).toContain("locality=Trento");
    const cursorValue = new URL(
      href!,
      "http://planets.invalid",
    ).searchParams.get("cursor");
    expect(decodeRecurringActivityCursor(cursorValue ?? undefined)).toEqual({
      version: 1,
      referenceTime,
      nextStartsAt: summary.next_starts_at,
      recurringActivityId: "00000000-0000-4000-8000-000000000012",
      locality: "Trento",
    });
  });

  it("renders empty and safe list failure states", async () => {
    const { default: Page } = await import("@/app/tavoli/page");
    listPublicRecurringActivities.mockResolvedValueOnce([]);
    const empty = render(
      await Page({ searchParams: Promise.resolve(Object.create(null)) }),
    );
    expect(screen.getByText("No Tavoli found")).toBeInTheDocument();

    empty.unmount();
    listPublicRecurringActivities.mockRejectedValueOnce(
      new Error("raw private database error"),
    );
    render(await Page({ searchParams: Promise.resolve({}) }));
    expect(
      screen.getByText("Tavoli are temporarily unavailable"),
    ).toBeInTheDocument();
    expect(screen.queryByText(/raw private/i)).not.toBeInTheDocument();
  });

  it("renders active detail with schedule, occurrences, and restricted copy", async () => {
    getPublicRecurringActivity.mockResolvedValue(detail);
    const { default: Page } = await import("@/app/tavoli/[id]/page");
    render(await Page({ params: Promise.resolve({ id: activityId }) }));

    expect(getPublicRecurringActivity).toHaveBeenCalledWith(
      activityId,
      referenceTime,
    );
    expect(screen.getByText("Every Wednesday at 19:00")).toBeInTheDocument();
    expect(screen.getByText("Duration: 90 minutes")).toBeInTheDocument();
    expect(screen.getByText("Time zone: Europe/Rome")).toBeInTheDocument();
    expect(screen.getByText("Upcoming meetings")).toBeInTheDocument();
    expect(screen.getByTestId("restricted-location")).toHaveTextContent(
      "Exact location available after joining.",
    );
  });

  it("renders public exact detail and omits upcoming meetings for paused and ended history", async () => {
    const { default: Page } = await import("@/app/tavoli/[id]/page");
    getPublicRecurringActivity.mockResolvedValueOnce({
      ...detail,
      lifecycle_state: "paused",
      next_occurrences: [],
      exact_location: { kind: "public", text: "Beside the fountain" },
    });
    const paused = render(
      await Page({ params: Promise.resolve({ id: activityId }) }),
    );
    expect(screen.getByText("Paused")).toBeInTheDocument();
    expect(screen.getByTestId("public-exact-location")).toHaveTextContent(
      "Beside the fountain",
    );
    expect(screen.queryByText("Upcoming meetings")).not.toBeInTheDocument();

    paused.unmount();
    getPublicRecurringActivity.mockResolvedValueOnce({
      ...detail,
      lifecycle_state: "ended",
      next_occurrences: [],
    });
    render(await Page({ params: Promise.resolve({ id: activityId }) }));
    expect(screen.getByText("Ended")).toBeInTheDocument();
    expect(screen.queryByText("Upcoming meetings")).not.toBeInTheDocument();
  });

  it("preserves not-found behavior and sanitizes operational detail failures", async () => {
    const { default: Page } = await import("@/app/tavoli/[id]/page");
    await expect(
      Page({ params: Promise.resolve({ id: "not-a-uuid" }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(getPublicRecurringActivity).not.toHaveBeenCalled();

    getPublicRecurringActivity.mockResolvedValueOnce(null);
    await expect(
      Page({ params: Promise.resolve({ id: activityId }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");

    getPublicRecurringActivity.mockRejectedValueOnce(
      new Error("raw protected backend detail"),
    );
    render(await Page({ params: Promise.resolve({ id: activityId }) }));
    expect(
      screen.getByText("Tavolo temporarily unavailable"),
    ).toBeInTheDocument();
    expect(screen.queryByText(/raw protected/i)).not.toBeInTheDocument();
  });

  it("links the public home to both discovery types and introduces no authoring routes", async () => {
    readCurrentAuth.mockResolvedValue({ status: "signedOut" });
    const { default: HomePage } = await import("@/app/(public)/page");
    render(await HomePage());

    expect(
      screen.getByRole("link", { name: "Browse one-time proposals" }),
    ).toHaveAttribute("href", "/proposals");
    expect(screen.getByRole("link", { name: "Browse Tavoli" })).toHaveAttribute(
      "href",
      "/tavoli",
    );
    expect(
      existsSync(resolve(process.cwd(), "src/app/tavoli/create/page.tsx")),
    ).toBe(false);
    expect(
      existsSync(resolve(process.cwd(), "src/app/tavoli/mine/page.tsx")),
    ).toBe(false);
  });
});

const summary: PublicRecurringActivitySummary = {
  recurring_activity_id: activityId,
  cover_object_path: null,
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

const detail: PublicRecurringActivityDetail = {
  recurring_activity_id: activityId,
  cover_object_path: null,
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
      starts_at: summary.next_starts_at,
      ends_at: summary.next_ends_at,
      event_timezone: summary.event_timezone,
    },
  ],
  exact_location: { kind: "restricted" },
};
