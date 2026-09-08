import { describe, expect, it, vi } from "vitest";

import {
  createPublicRecurringActivityListRequest,
  decodeRecurringActivityCursor,
  encodeRecurringActivityCursor,
  parsePublicRecurringActivityDetail,
  parsePublicRecurringActivitySummary,
} from "./recurring-activity-models";

const activityId = "00000000-0000-4000-8000-000000000001";

describe("public recurring activity payloads", () => {
  it("parses a compact public summary with no exact-location field", () => {
    const parsed = parsePublicRecurringActivitySummary(summaryRow());

    expect(parsed).toMatchObject({
      recurring_activity_id: activityId,
      title: "Philosophy table",
      public_location_label: "Trento · Povo",
      event_timezone: "Europe/Rome",
    });
    expect(parsed).not.toHaveProperty("exact_meeting_text");
  });

  it("rejects an exact-location field on a list payload", () => {
    expect(() =>
      parsePublicRecurringActivitySummary({
        ...summaryRow(),
        exact_meeting_text: "should never reach a card",
      }),
    ).toThrow("Unexpected recurring activity list field");
  });

  it("parses valid weekly and monthly public details", () => {
    const weekly = parsePublicRecurringActivityDetail(detailRow());
    const monthly = parsePublicRecurringActivityDetail(
      detailRow({
        recurrence_type: "monthly",
        weekday: null,
        day_of_month: 12,
        local_start_time: "18:30:00",
        exact_meeting_text: "Beside the fountain",
        exact_location_restricted: false,
      }),
    );

    expect(weekly.schedule).toMatchObject({
      recurrence_type: "weekly",
      weekday: 3,
      day_of_month: null,
    });
    expect(monthly.schedule).toMatchObject({
      recurrence_type: "monthly",
      weekday: null,
      day_of_month: 12,
    });
    expect(monthly.exact_location).toEqual({
      kind: "public",
      text: "Beside the fountain",
    });
  });

  it("rejects impossible weekly and monthly schedule shapes", () => {
    expect(() =>
      parsePublicRecurringActivityDetail(detailRow({ weekday: 0 })),
    ).toThrow("Invalid recurring activity number");
    expect(() =>
      parsePublicRecurringActivityDetail(detailRow({ weekday: 8 })),
    ).toThrow("Invalid recurring activity number");
    expect(() =>
      parsePublicRecurringActivityDetail(detailRow({ day_of_month: 12 })),
    ).toThrow("Invalid weekly recurring schedule");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({
          recurrence_type: "monthly",
          weekday: null,
          day_of_month: 29,
        }),
      ),
    ).toThrow("Invalid recurring activity number");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({
          recurrence_type: "monthly",
          weekday: 3,
          day_of_month: 12,
        }),
      ),
    ).toThrow("Invalid monthly recurring schedule");
  });

  it("validates lifecycle and inactive occurrence consistency", () => {
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({ lifecycle_state: "draft" }),
      ),
    ).toThrow("Invalid recurring activity lifecycle");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({ lifecycle_state: "paused" }),
      ),
    ).toThrow("Inactive recurring activity has occurrences");
    expect(
      parsePublicRecurringActivityDetail(
        detailRow({ lifecycle_state: "ended", next_occurrences: [] }),
      ).lifecycle_state,
    ).toBe("ended");
  });

  it("validates occurrence arrays, timestamps, duration, and time zones", () => {
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({ next_occurrences: "not-an-array" }),
      ),
    ).toThrow("Expected recurring activity array");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({
          next_occurrences: [occurrenceRow({ starts_at: "not-a-timestamp" })],
        }),
      ),
    ).toThrow("Expected recurring activity timestamp");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({ event_timezone: "Not/A_Real_Zone" }),
      ),
    ).toThrow("Invalid recurring activity time zone");
    expect(() =>
      parsePublicRecurringActivityDetail(detailRow({ duration_minutes: 0 })),
    ).toThrow("Invalid recurring activity number");
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({ schedule_effective_from: "2030-02-30" }),
      ),
    ).toThrow("Expected recurring activity date");
    expect(() =>
      parsePublicRecurringActivitySummary(
        summaryRow({ next_starts_at: "2030-02-30T18:00:00Z" }),
      ),
    ).toThrow("Expected recurring activity timestamp");
  });

  it("fails closed when restricted detail unexpectedly includes exact text", () => {
    const protectedValue = "hidden private room";
    let failure: unknown;
    try {
      parsePublicRecurringActivityDetail(
        detailRow({ exact_meeting_text: protectedValue }),
      );
    } catch (error) {
      failure = error;
    }

    expect(failure).toBeInstanceOf(TypeError);
    expect(String(failure)).not.toContain(protectedValue);
  });

  it("requires exact text when the public-location flag is selected", () => {
    expect(() =>
      parsePublicRecurringActivityDetail(
        detailRow({
          exact_meeting_text: null,
          exact_location_restricted: false,
        }),
      ),
    ).toThrow("Expected recurring activity text");
  });
});

describe("recurring activity snapshot cursor", () => {
  const cursor = {
    version: 1 as const,
    referenceTime: "2030-01-01T00:00:00.000Z",
    nextStartsAt: "2030-01-02T18:00:00.000Z",
    recurringActivityId: activityId,
    locality: "Trento",
  };

  it("round-trips the snapshot, position, ID, and locality binding", () => {
    expect(
      decodeRecurringActivityCursor(encodeRecurringActivityCursor(cursor)),
    ).toEqual(cursor);
  });

  it("rejects malformed, oversized, invalid timestamp, and invalid UUID cursors", () => {
    expect(decodeRecurringActivityCursor("not-a-cursor")).toBeUndefined();
    expect(decodeRecurringActivityCursor("x".repeat(1025))).toBeUndefined();
    expect(
      decodeRecurringActivityCursor(
        rawCursor({ ...cursor, referenceTime: "not-a-time" }),
      ),
    ).toBeUndefined();
    expect(
      decodeRecurringActivityCursor(
        rawCursor({ ...cursor, recurringActivityId: "not-a-uuid" }),
      ),
    ).toBeUndefined();
  });

  it("reuses the page-one reference time exactly on page two", () => {
    const clock = vi.fn(() => new Date("2040-01-01T00:00:00Z"));
    const request = createPublicRecurringActivityListRequest(
      {
        locality: " Trento ",
        cursor: encodeRecurringActivityCursor(cursor),
      },
      clock,
    );

    expect(request).toEqual({
      referenceTime: cursor.referenceTime,
      locality: "Trento",
      cursor: {
        nextStartsAt: cursor.nextStartsAt,
        recurringActivityId: cursor.recurringActivityId,
      },
    });
    expect(clock).not.toHaveBeenCalled();
  });

  it("ignores a cursor for a different filter and starts a fresh snapshot", () => {
    const clock = vi.fn(() => new Date("2040-01-01T00:00:00Z"));
    const request = createPublicRecurringActivityListRequest(
      {
        locality: "Bologna",
        cursor: encodeRecurringActivityCursor(cursor),
      },
      clock,
    );

    expect(request).toEqual({
      referenceTime: "2040-01-01T00:00:00.000Z",
      locality: "Bologna",
    });
    expect(clock).toHaveBeenCalledOnce();
  });

  it("creates a fresh deterministic snapshot when a filter is submitted", () => {
    const clock = vi.fn(() => new Date("2041-02-03T04:05:06Z"));

    expect(
      createPublicRecurringActivityListRequest(
        { locality: ` ${"x".repeat(130)} ` },
        clock,
      ),
    ).toEqual({
      referenceTime: "2041-02-03T04:05:06.000Z",
      locality: "x".repeat(120),
    });
    expect(clock).toHaveBeenCalledOnce();
  });
});

function summaryRow(overrides: Record<string, unknown> = {}) {
  return {
    recurring_activity_id: activityId,
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
    ...overrides,
  };
}

function detailRow(overrides: Record<string, unknown> = {}) {
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
    next_occurrences: [occurrenceRow()],
    exact_meeting_text: null,
    exact_location_restricted: true,
    ...overrides,
  };
}

function occurrenceRow(overrides: Record<string, unknown> = {}) {
  return {
    local_starts_at: "2030-01-02T19:00:00",
    starts_at: "2030-01-02T18:00:00Z",
    ends_at: "2030-01-02T19:30:00Z",
    event_timezone: "Europe/Rome",
    ...overrides,
  };
}

function rawCursor(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}
