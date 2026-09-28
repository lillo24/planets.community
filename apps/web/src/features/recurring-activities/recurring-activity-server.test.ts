import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const rpc = vi.fn();
vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: vi.fn(async () => ({ rpc })),
}));

import {
  getPublicRecurringActivity,
  listPublicRecurringActivities,
  PublicRecurringActivityReadError,
} from "./recurring-activity-server";

const activityId = "00000000-0000-4000-8000-000000000001";

describe("public recurring activity server boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("calls only the public list RPC with the explicit snapshot and cursor", async () => {
    rpc.mockResolvedValueOnce({ data: [summaryRow()], error: null });

    await expect(
      listPublicRecurringActivities({
        referenceTime: "2030-01-01T00:00:00.000Z",
        locality: "Trento",
        cursor: {
          nextStartsAt: "2030-01-02T18:00:00.000Z",
          recurringActivityId: activityId,
        },
      }),
    ).resolves.toHaveLength(1);
    expect(rpc).toHaveBeenCalledWith("list_public_recurring_activities", {
      p_reference_time: "2030-01-01T00:00:00.000Z",
      p_limit: 12,
      p_cursor_next_starts_at: "2030-01-02T18:00:00.000Z",
      p_cursor_id: activityId,
      p_locality: "Trento",
    });
  });

  it("calls only the public detail RPC with a bounded occurrence count", async () => {
    rpc.mockResolvedValueOnce({ data: [detailRow()], error: null });

    await expect(
      getPublicRecurringActivity(activityId, "2030-01-01T00:00:00.000Z"),
    ).resolves.toMatchObject({ recurring_activity_id: activityId });
    expect(rpc).toHaveBeenCalledWith("get_public_recurring_activity", {
      p_recurring_activity_id: activityId,
      p_occurrence_limit: 5,
      p_reference_time: "2030-01-01T00:00:00.000Z",
    });
  });

  it("replaces backend failures with an app-owned safe error", async () => {
    rpc.mockResolvedValueOnce({
      data: null,
      error: { message: "private backend detail" },
    });

    let failure: unknown;
    try {
      await listPublicRecurringActivities({
        referenceTime: "2030-01-01T00:00:00.000Z",
      });
    } catch (error) {
      failure = error;
    }
    expect(failure).toBeInstanceOf(PublicRecurringActivityReadError);
    expect(String(failure)).not.toContain("private backend detail");
  });
});

function summaryRow() {
  return {
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
}

function detailRow() {
  return {
    ...summaryRow(),
    creator_profile_id: "00000000-0000-4000-8000-000000000099",
    creator_display_name: "Casey",
    lifecycle_state: "published",
    description: "A recurring local discussion.",
    recurrence_type: "weekly",
    weekday: 3,
    day_of_month: null,
    local_start_time: "19:00:00",
    duration_minutes: 90,
    schedule_effective_from: "2030-01-01",
    next_occurrences: [
      {
        local_starts_at: "2030-01-02T19:00:00",
        starts_at: "2030-01-02T18:00:00Z",
        ends_at: "2030-01-02T19:30:00Z",
        event_timezone: "Europe/Rome",
      },
    ],
    exact_meeting_text: null,
    exact_location_restricted: true,
  };
}
