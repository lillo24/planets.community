import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import {
  addModerationNoteAction,
  transitionModerationCaseAction,
} from "./moderation-actions";
import type {
  ModerationCaseDetail,
  ModerationCaseSummary,
  ModerationState,
} from "./moderation-models";

const stateLabels: Record<ModerationState, string> = {
  received: "Received",
  under_review: "Under review",
  completed: "Review completed",
};

export function ModerationStateBadge({ state }: { state: ModerationState }) {
  return <Badge variant="secondary">{stateLabels[state]}</Badge>;
}

export function ModerationCaseCard({ item }: { item: ModerationCaseSummary }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <Link href={`/admin/cases/${item.caseId}`}>{item.targetSummary}</Link>
        </CardTitle>
        <CardDescription>{item.category.replaceAll("_", " ")}</CardDescription>
        <CardAction>
          <ModerationStateBadge state={item.state} />
        </CardAction>
      </CardHeader>
      <CardContent className="grid gap-2">
        <p>
          Subject: <strong>{item.subjectDisplayName}</strong>
        </p>
        <p className="text-muted-foreground">
          {item.targetKind.replaceAll("_", " ")}
          {item.contextSummary ? ` · ${item.contextSummary}` : ""}
        </p>
        <p className="font-mono text-xs text-muted-foreground">
          Case {item.caseId}
        </p>
        <time dateTime={item.createdAt}>{formatDate(item.createdAt)}</time>
      </CardContent>
    </Card>
  );
}

export function ModerationCaseDetailView({
  detail,
}: {
  detail: ModerationCaseDetail;
}) {
  const targetState =
    detail.state === "under_review" ? "completed" : "under_review";
  const transitionLabel =
    detail.state === "received"
      ? "Start review"
      : detail.state === "under_review"
        ? "Complete review"
        : "Return to review";
  return (
    <div className="grid gap-6">
      <Card>
        <CardHeader>
          <CardTitle>{detail.targetSummary}</CardTitle>
          <CardDescription>
            {detail.category.replaceAll("_", " ")} ·{" "}
            {detail.targetKind.replaceAll("_", " ")}
          </CardDescription>
          <CardAction>
            <ModerationStateBadge state={detail.state} />
          </CardAction>
        </CardHeader>
        <CardContent className="grid gap-4">
          <dl className="grid gap-2 sm:grid-cols-2">
            <div>
              <dt className="text-sm text-muted-foreground">Reporter</dt>
              <dd>{detail.reporterDisplayName}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted-foreground">
                Reported subject
              </dt>
              <dd>{detail.subjectDisplayName}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted-foreground">Context</dt>
              <dd>{detail.contextSummary ?? "No additional context"}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted-foreground">Received</dt>
              <dd>{formatDate(detail.createdAt)}</dd>
            </div>
          </dl>
          {detail.projectContextId ? (
            <p className="rounded-lg bg-muted p-3 text-sm">
              PLANETS can verify Project ownership and membership history. It
              does not currently know who physically attended an activity.
            </p>
          ) : null}
          <section
            aria-labelledby="report-explanation-heading"
            className="grid gap-2"
          >
            <h2 id="report-explanation-heading" className="font-semibold">
              Original report
            </h2>
            <p className="whitespace-pre-wrap rounded-lg border p-4">
              {detail.explanation}
            </p>
          </section>
          <form action={transitionModerationCaseAction}>
            <input type="hidden" name="caseId" value={detail.caseId} />
            <input
              type="hidden"
              name="expectedStateVersion"
              value={detail.stateVersion}
            />
            <input type="hidden" name="targetState" value={targetState} />
            <Button type="submit">{transitionLabel}</Button>
          </form>
        </CardContent>
      </Card>

      {detail.corroboration ? (
        <Card>
          <CardHeader>
            <CardTitle>
              <h2>Group corroboration</h2>
            </CardTitle>
            <CardDescription>
              Private participant evidence for staff review. These responses are
              not a vote, verdict, score, or automatic consequence.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">
            <dl className="grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
              <EvidenceCount
                label="Invited"
                value={detail.corroboration.invitedCount}
              />
              <EvidenceCount
                label="Responded"
                value={detail.corroboration.respondedCount}
              />
              <EvidenceCount
                label="Pending"
                value={detail.corroboration.pendingCount}
              />
              <EvidenceCount
                label="Agree"
                value={detail.corroboration.agreeCount}
              />
              <EvidenceCount
                label="Disagree"
                value={detail.corroboration.disagreeCount}
              />
              <EvidenceCount
                label="Unsure"
                value={detail.corroboration.unsureCount}
              />
            </dl>
            <p className="rounded-lg bg-muted p-3 text-sm">
              Eligibility is based on the Project creator and accepted
              membership history at report creation. Membership is only a
              coordination proxy: it does not prove physical attendance or that
              a person witnessed the reported conduct.
            </p>
            {detail.corroboration.responses.length === 0 ? (
              <p className="text-muted-foreground">No responses yet.</p>
            ) : (
              <ol className="grid gap-3">
                {detail.corroboration.responses.map((response) => (
                  <li
                    key={response.responseId}
                    className="rounded-lg border p-3"
                  >
                    <p>
                      <strong>{response.responderDisplayName}</strong> ·{" "}
                      {response.choice}
                    </p>
                    {response.explanation ? (
                      <p className="mt-2 whitespace-pre-wrap">
                        {response.explanation}
                      </p>
                    ) : (
                      <p className="mt-2 text-muted-foreground">
                        No private explanation.
                      </p>
                    )}
                    <time
                      className="mt-2 block text-sm text-muted-foreground"
                      dateTime={response.createdAt}
                    >
                      {formatDate(response.createdAt)}
                    </time>
                  </li>
                ))}
              </ol>
            )}
          </CardContent>
        </Card>
      ) : null}

      {detail.counterstatement ? (
        <Card>
          <CardHeader>
            <CardTitle>
              <h2>Counterparty statement</h2>
            </CardTitle>
            <CardDescription>
              Private Scambio-Dona evidence from the reported counterparty for
              manual staff review.
            </CardDescription>
            <CardAction>
              <Badge variant="secondary">
                {detail.counterstatement.submittedAt ? "Submitted" : "Pending"}
              </Badge>
            </CardAction>
          </CardHeader>
          <CardContent className="grid gap-4">
            <dl className="grid gap-2 sm:grid-cols-2">
              <div>
                <dt className="text-sm text-muted-foreground">
                  Assigned recipient
                </dt>
                <dd>{detail.counterstatement.recipientDisplayName}</dd>
              </div>
              <div>
                <dt className="text-sm text-muted-foreground">Requested</dt>
                <dd>{formatDate(detail.counterstatement.requestedAt)}</dd>
              </div>
            </dl>
            {detail.counterstatement.statement ? (
              <div className="grid gap-2">
                <p className="whitespace-pre-wrap rounded-lg border p-4">
                  {detail.counterstatement.statement}
                </p>
                <time
                  className="text-sm text-muted-foreground"
                  dateTime={detail.counterstatement.submittedAt ?? undefined}
                >
                  Submitted {formatDate(detail.counterstatement.submittedAt!)}
                </time>
              </div>
            ) : (
              <p className="text-muted-foreground">
                No statement submitted yet.
              </p>
            )}
            <p className="rounded-lg bg-muted p-3 text-sm">
              A counterstatement is private evidence, not a verdict or an
              automatic consequence. It does not change the case state, request,
              listing, agreement, or resource availability.
            </p>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader>
          <CardTitle>Private staff notes</CardTitle>
          <CardDescription>
            Notes are visible only to current moderation staff.
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4">
          {detail.notes.length === 0 ? (
            <p className="text-muted-foreground">No internal notes yet.</p>
          ) : (
            <ol className="grid gap-3">
              {detail.notes.map((note) => (
                <li
                  key={note.noteId}
                  id={`moderation-note-${note.noteId}`}
                  className="rounded-lg border p-3"
                >
                  <p className="whitespace-pre-wrap">{note.body}</p>
                  <p className="mt-2 text-sm text-muted-foreground">
                    {note.authorDisplayName} · {formatDate(note.createdAt)}
                  </p>
                </li>
              ))}
            </ol>
          )}
          <form action={addModerationNoteAction} className="grid gap-2">
            <input type="hidden" name="caseId" value={detail.caseId} />
            <label htmlFor="moderation-note" className="font-medium">
              Add internal note
            </label>
            <Textarea
              id="moderation-note"
              name="body"
              maxLength={4000}
              required
            />
            <Button className="justify-self-start" type="submit">
              Add note
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Case chronology</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="grid gap-2">
            {detail.events.map((event) => (
              <li key={event.eventId} className="border-l-2 pl-3">
                <p>{eventLabel(event.eventKind)}</p>
                <p className="text-sm text-muted-foreground">
                  {event.actorDisplayName} · {formatDate(event.createdAt)}
                </p>
              </li>
            ))}
          </ol>
        </CardContent>
      </Card>
    </div>
  );
}

function EvidenceCount({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border p-3">
      <dt className="text-sm text-muted-foreground">{label}</dt>
      <dd className="text-2xl font-semibold">{value}</dd>
    </div>
  );
}

function eventLabel(
  kind: ModerationCaseDetail["events"][number]["eventKind"],
): string {
  if (kind === "report_received") return "Report received";
  if (kind === "note_added") return "Private note added";
  return "Review state changed";
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}
