import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import type {
  ModerationCaseDetail,
  ModerationStaffRole,
} from "./moderation-models";
import {
  consequenceChoices,
  consequenceLabels,
  type ConsequenceEpisode,
} from "./moderation-consequence-models";
import { ModerationConsequenceControls } from "./moderation-consequence-controls";

export function ModerationConsequencesSection({
  detail,
  episodes,
  staffRole,
  staffProfileId,
}: {
  detail: ModerationCaseDetail;
  episodes: ConsequenceEpisode[];
  staffRole: ModerationStaffRole;
  staffProfileId: string;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <h2>Consequences from this case</h2>
        </CardTitle>
        <CardDescription>
          This history contains only episodes originating from this case, not
          the subject’s global consequence history. Each consequence is
          independent. Evidence never selects or applies an action
          automatically.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        {episodes.length === 0 ? (
          <p>No consequence episodes from this case.</p>
        ) : (
          <ol className="flex flex-col gap-4">
            {episodes.map((episode) => (
              <li
                key={episode.consequenceId}
                className="flex flex-col gap-3 rounded-lg border p-4"
              >
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="font-semibold">
                    {consequenceLabels[episode.type]}
                  </h3>
                  <Badge variant="secondary">
                    {episode.revokedAt === null ? "Active" : "Revoked"}
                  </Badge>
                </div>
                <p>
                  Applied{" "}
                  <time dateTime={episode.appliedAt}>
                    {formatDate(episode.appliedAt)}
                  </time>
                  {episode.revokedAt ? (
                    <>
                      {" "}
                      · Revoked{" "}
                      <time dateTime={episode.revokedAt}>
                        {formatDate(episode.revokedAt)}
                      </time>
                    </>
                  ) : null}
                </p>
                <ol className="flex flex-col gap-3">
                  {episode.actions.map((action) => {
                    const note = detail.notes.find(
                      (item) => item.noteId === action.noteId,
                    );
                    return (
                      <li key={action.actionId} className="flex flex-col gap-1">
                        <p className="font-medium">
                          {action.kind === "applied"
                            ? "Apply reason shown to the user"
                            : "Revocation reason shown to the user"}
                        </p>
                        <p className="whitespace-pre-wrap break-words">
                          {action.userReason}
                        </p>
                        <p className="text-sm text-muted-foreground">
                          {note?.authorProfileId === action.actorProfileId
                            ? `${note.authorDisplayName} · `
                            : ""}
                          <time dateTime={action.createdAt}>
                            {formatDate(action.createdAt)}
                          </time>
                        </p>
                        {note ? (
                          <a
                            href={`#moderation-note-${note.noteId}`}
                            className="text-sm underline"
                          >
                            Linked private moderation note
                          </a>
                        ) : (
                          <p className="text-sm">
                            Private note reference unavailable; reload the case.
                          </p>
                        )}
                      </li>
                    );
                  })}
                </ol>
              </li>
            ))}
          </ol>
        )}
        {detail.state === "received" ? (
          <p>
            Start review before applying a consequence. Use the explicit review
            action above.
          </p>
        ) : null}
        {staffRole === "admin" && detail.subjectProfileId === staffProfileId ? (
          <p>Another admin is required to suspend this account.</p>
        ) : null}
        <ModerationConsequenceControls
          caseId={detail.caseId}
          choices={consequenceChoices(
            detail,
            episodes,
            staffRole,
            staffProfileId,
          )}
        />
      </CardContent>
    </Card>
  );
}
function formatDate(value: string) {
  return (
    new Intl.DateTimeFormat("en", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: "UTC",
    }).format(new Date(value)) + " UTC"
  );
}
