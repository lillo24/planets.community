import { describe, expect, it } from "vitest";

import {
  decodeProposalCursor,
  encodeProposalCursor,
  parsePublicProposalDetail,
} from "./proposal-models";

describe("public proposal models", () => {
  it("keeps only the sanitized detail contract", () => {
    const parsed = parsePublicProposalDetail({
      proposal_id: "proposal-1",
      creator_profile_id: "user-1",
      creator_display_name: null,
      title: "Community mural",
      summary: "Paint together",
      description: "Public description",
      starts_at: "2026-09-03T10:00:00Z",
      ends_at: "2026-09-03T12:00:00Z",
      event_timezone: "Europe/Rome",
      country_code: "IT",
      locality: "Bologna",
      administrative_area: null,
      public_location_label: "Central Bologna",
      derived_status: "happening",
      skills: [],
      exact_meeting_text: null,
      exact_location_restricted: true,
      private_meeting_value: "must never survive parsing",
    });

    expect(parsed.exact_location_restricted).toBe(true);
    expect(parsed.exact_meeting_text).toBeNull();
    expect(parsed).not.toHaveProperty("private_meeting_value");
  });

  it("round-trips bounded cursors and rejects malformed values", () => {
    const cursor = {
      startsAt: "2026-09-03T10:00:00Z",
      id: "00000000-0000-4000-8000-000000000001",
    };
    expect(decodeProposalCursor(encodeProposalCursor(cursor))).toEqual(cursor);
    expect(decodeProposalCursor("not-a-cursor")).toBeUndefined();
    expect(decodeProposalCursor("x".repeat(513))).toBeUndefined();
  });
});
