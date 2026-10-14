import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { isUuid } from "./moderation-models";

export type DiscussionEvidence = Readonly<{
  message_id: string;
  room_id: string;
  group_id: string;
  title: string;
  body: string;
  sender_id: string;
  created_at: string;
}>;

export function parseDiscussionEvidence(value: unknown): DiscussionEvidence {
  const fail = () => {
    throw new Error("The discussion report evidence is malformed.");
  };
  if (!value || typeof value !== "object" || Array.isArray(value))
    return fail();
  const row = value as Record<string, unknown>;
  const keys = [
    "message_id",
    "room_id",
    "group_id",
    "title",
    "body",
    "sender_id",
    "created_at",
  ];
  if (
    Object.keys(row).length !== keys.length ||
    keys.some((key) => !(key in row))
  )
    return fail();
  for (const key of ["message_id", "room_id", "group_id", "sender_id"])
    if (!isUuid(row[key])) return fail();
  for (const [key, max] of [
    ["title", 120],
    ["body", 4000],
  ] as const) {
    const text = row[key];
    if (
      typeof text !== "string" ||
      text.trim() !== text ||
      !text ||
      [...text].length > max
    )
      return fail();
  }
  if (
    typeof row.created_at !== "string" ||
    !Number.isFinite(Date.parse(row.created_at))
  )
    return fail();
  return row as DiscussionEvidence;
}

export function DiscussionEvidenceView({
  evidence,
}: {
  evidence: DiscussionEvidence;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Reported Group discussion message</CardTitle>
        <CardDescription>
          Exact evidence captured when this report was submitted.
        </CardDescription>
      </CardHeader>
      <CardContent className="grid gap-3 break-words">
        <h3 className="font-semibold">{evidence.title}</h3>
        <p className="whitespace-pre-wrap">{evidence.body}</p>
        <dl className="grid gap-1 break-all text-sm">
          <dt>Message</dt>
          <dd>{evidence.message_id}</dd>
          <dt>Discussion</dt>
          <dd>{evidence.room_id}</dd>
          <dt>Group</dt>
          <dd>{evidence.group_id}</dd>
          <dt>Sender provenance</dt>
          <dd>{evidence.sender_id}</dd>
          <dt>Sent at</dt>
          <dd>{evidence.created_at}</dd>
        </dl>
      </CardContent>
    </Card>
  );
}
