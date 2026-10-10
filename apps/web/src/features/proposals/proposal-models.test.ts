import { describe, expect, it } from "vitest";

import {
  decodeProposalCursor,
  encodeProposalCursor,
  parsePublicProposalDetail,
  parsePublicProposalSummary,
} from "./proposal-models";

const proposalId = "00000000-0000-4000-8000-000000000001";
const coverObjectPath = `00000000-0000-4000-8000-000000000099/projects/${proposalId}/00000000-0000-4000-8000-000000000002.webp`;

describe("public proposal models", () => {
  it("keeps only the sanitized detail contract", () => {
    const parsed = parsePublicProposalDetail({
      definition_phase: "defined",
      published_at: "2026-09-01T10:00:00Z",
      reference_time: "2026-09-01T11:00:00Z",
      proposal_id: proposalId,
      cover_object_path: coverObjectPath,
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
      selected_exact_place: {
        label: "SECRET selected address",
        latitude: 44,
        longitude: 10,
      },
      exact_location: "SECRET geometry",
      selection_receipt: "SECRET receipt",
    });

    expect(parsed.exact_location_restricted).toBe(true);
    expect(parsed.exact_meeting_text).toBeNull();
    expect(parsed.cover_object_path).toBe(coverObjectPath);
    expect(parsed).not.toHaveProperty("private_meeting_value");
    expect(JSON.stringify(parsed)).not.toContain("SECRET");
  });

  it("accepts no cover and rejects a non-null path for another Proposal", () => {
    const row = {
      definition_phase: "defined",
      published_at: "2026-09-01T10:00:00Z",
      reference_time: "2026-09-01T11:00:00Z",
      proposal_id: proposalId,
      cover_object_path: null,
      title: "Community mural",
      summary: "Paint together",
      starts_at: "2026-09-03T10:00:00Z",
      ends_at: "2026-09-03T12:00:00Z",
      event_timezone: "Europe/Rome",
      country_code: "IT",
      locality: "Bologna",
      administrative_area: null,
      public_location_label: "Central Bologna",
      derived_status: "happening",
      skills: [],
    };
    expect(parsePublicProposalSummary(row).cover_object_path).toBeNull();
    expect(() =>
      parsePublicProposalSummary({
        ...row,
        cover_object_path:
          "00000000-0000-4000-8000-000000000099/projects/00000000-0000-4000-8000-000000000098/00000000-0000-4000-8000-000000000002.webp",
      }),
    ).toThrow("Invalid cover object path");
  });

  it("round-trips bounded cursors and rejects malformed values", () => {
    const cursor = {
      publishedAt: "2026-09-03T10:00:00Z",
      referenceTime: "2026-09-03T11:00:00Z",
      id: "00000000-0000-4000-8000-000000000001",
    };
    expect(decodeProposalCursor(encodeProposalCursor(cursor))).toEqual(cursor);
    expect(decodeProposalCursor("not-a-cursor")).toBeUndefined();
    expect(decodeProposalCursor("x".repeat(513))).toBeUndefined();
    expect(
      decodeProposalCursor(
        Buffer.from(
          JSON.stringify({ startsAt: "2026-09-03T10:00:00Z", id: cursor.id }),
        ).toString("base64url"),
      ),
    ).toBeUndefined();
  });
});
