import { describe, expect, it } from "vitest";

import {
  decodeModerationCursor,
  encodeModerationCursor,
  parseModerationCase,
  parseModerationCounterstatement,
  parseModerationQueue,
} from "./moderation-models";
import {
  moderationCounterstatementRow,
  moderationDetailRow,
  moderationQueueRow,
} from "./moderation-test-fixtures";

describe("moderation model parsing", () => {
  it("parses a bounded queue row and round-trips its cursor", () => {
    const row = moderationQueueRow();
    const parsed = parseModerationQueue([row]);
    expect(parsed[0]).toMatchObject({
      state: "received",
      targetSummary: "Project chat message",
    });
    const cursor = encodeModerationCursor({
      createdAt: row.created_at,
      caseId: row.case_id,
    });
    expect(decodeModerationCursor(cursor)).toEqual({
      createdAt: row.created_at,
      caseId: row.case_id,
    });
    expect(decodeModerationCursor("not-a-cursor"), undefined);
  });

  it("parses private notes and chronology only from the staff detail shape", () => {
    const detail = parseModerationCase([moderationDetailRow()]);
    expect(detail?.notes[0].body).toBe("Private note");
    expect(detail?.events.map((event) => event.eventKind)).toEqual([
      "report_received",
      "note_added",
    ]);
  });

  it("rejects invented enforcement states", () => {
    expect(() =>
      parseModerationQueue([{ ...moderationQueueRow(), state: "sanctioned" }]),
    ).toThrow("malformed");
  });

  it("parses pending and submitted counterparty evidence", () => {
    expect(
      parseModerationCounterstatement([moderationCounterstatementRow()]),
    ).toMatchObject({ recipientDisplayName: "Taylor", statement: null });
    expect(
      parseModerationCounterstatement([
        moderationCounterstatementRow("My private version of events."),
      ]),
    ).toMatchObject({
      statement: "My private version of events.",
      submittedAt: "2026-09-28T10:05:00Z",
    });
    expect(parseModerationCounterstatement([])).toBeNull();
    expect(() =>
      parseModerationCounterstatement([
        {
          ...moderationCounterstatementRow("My private version of events."),
          submitted_at: null,
        },
      ]),
    ).toThrow("malformed");
  });
});
