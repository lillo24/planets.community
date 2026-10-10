import { LocationAttribution } from "@/features/locations/location-attribution";
import Link from "next/link";
import { CalendarDaysIcon, CircleHelpIcon, MapPinIcon } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import type { ProposalStatus, PublicProposalSummary } from "./proposal-models";

const statusLabels: Record<ProposalStatus, string> = {
  upcoming: "Upcoming",
  happening: "Happening",
  just_finished: "Just Finished",
  completed: "Completed",
};

export function ProposalStatusBadge({
  status,
  idea = false,
}: {
  status: ProposalStatus | null;
  idea?: boolean;
}) {
  return (
    <Badge variant={status === "just_finished" ? "success" : "secondary"}>
      {idea ? "In definition" : status ? statusLabels[status] : "Defined"}
    </Badge>
  );
}

export function ProposalCard({
  proposal,
}: {
  proposal: PublicProposalSummary;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <Link href={`/proposals/${proposal.proposal_id}`}>
            {proposal.title}
          </Link>
        </CardTitle>
        <CardDescription>{proposal.summary}</CardDescription>
        <CardAction>
          <ProposalStatusBadge
            status={proposal.derived_status}
            idea={proposal.definition_phase === "idea"}
          />
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="flex gap-2 text-muted-foreground">
          <CalendarDaysIcon aria-hidden="true" className="size-4 shrink-0" />
          {formatSchedule(proposal)}
        </p>
        <p className="flex gap-2 text-muted-foreground">
          {proposal.public_location_label ? (
            <MapPinIcon aria-hidden="true" className="size-4 shrink-0" />
          ) : (
            <CircleHelpIcon aria-hidden="true" className="size-4 shrink-0" />
          )}
          {proposal.public_location_label ?? "Place to decide together"}
        </p>
        <LocationAttribution />
        <div className="flex flex-wrap gap-2">
          {proposal.skills.map((skill) => (
            <Badge key={`${skill.id}:${skill.importance}`} variant="outline">
              {skill.importance === "required" ? "Required" : "Useful"}:{" "}
              {skill.label}
            </Badge>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

export function formatSchedule(proposal: PublicProposalSummary): string {
  if (!proposal.starts_at || !proposal.ends_at || !proposal.event_timezone)
    return "Date to decide together";
  const formatter = new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: proposal.event_timezone,
  });
  return `${proposal.definition_phase === "idea" ? "Tentative: " : ""}${formatter.format(new Date(proposal.starts_at))} – ${formatter.format(new Date(proposal.ends_at))}`;
}
