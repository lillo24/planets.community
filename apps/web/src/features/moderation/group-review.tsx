import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { GroupReview } from "./group-moderation-models";
import { GroupSuppressionForm } from "./group-suppression-form";

export function GroupReviewView({
  group,
  caseId,
}: {
  group: GroupReview;
  caseId: string;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Registered group review</CardTitle>
      </CardHeader>
      <CardContent className="grid gap-4">
        <p>
          {group.contentChanged
            ? "Content changed since this report. This is current content, not a stored historical snapshot."
            : "Current group content matches the report-time version."}
        </p>
        <p>
          Report version: {group.reportVersion} · Current version:{" "}
          {group.version}
        </p>
        <h3 className="text-xl font-semibold">
          {group.name || "Unnamed group draft"}
        </h3>
        <p className="whitespace-pre-wrap">{group.description}</p>
        <p>
          {group.kind === "informal"
            ? "Informal group"
            : "Association / organization"}{" "}
          · Self-declared
        </p>
        <p>
          Territory: {group.locality ?? "Not supplied"} · Volunteering focus:{" "}
          {group.volunteering ? "Yes" : "No"}
        </p>
        <p>
          Publication: {group.publication} · Staff suppression:{" "}
          {group.suppressed ? "Hidden" : "Clear"} · Public eligibility:{" "}
          {group.publiclyAvailable ? "Eligible" : "Unavailable"}
        </p>
        <dl className="grid gap-2 break-all text-sm">
          <dt>Accountable manager</dt>
          <dd>{group.managerId ?? "Absent"}</dd>
          <dt>Original actor provenance</dt>
          <dd>{group.originalActorId}</dd>
          <dt>Group UUID</dt>
          <dd>{group.id}</dd>
        </dl>
        {group.latestAction ? (
          <section className="grid gap-2 rounded-lg border p-4">
            <h3 className="font-semibold">Latest private directory action</h3>
            <p>
              {group.latestAction.suppressed ? "Hide" : "Restore"} · Version{" "}
              {group.latestAction.version} · {group.latestAction.createdAt}
            </p>
            <p className="break-all">
              Actor {group.latestAction.actorId} · Action{" "}
              {group.latestAction.id}
            </p>
            <p className="whitespace-pre-wrap">{group.latestAction.reason}</p>
          </section>
        ) : null}
        <GroupSuppressionForm
          key={`${group.id}:${group.version}:${group.suppressed}`}
          caseId={caseId}
          groupId={group.id}
          version={group.version}
          suppressed={group.suppressed}
        />
      </CardContent>
    </Card>
  );
}
