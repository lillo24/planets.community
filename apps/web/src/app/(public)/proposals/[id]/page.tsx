import { LocationAttribution } from "@/features/locations/location-attribution";
import Link from "next/link";
import { notFound } from "next/navigation";
import { CalendarDaysIcon, MapPinIcon } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  formatSchedule,
  ProposalStatusBadge,
} from "@/features/proposals/proposal-components";
import type { PublicProposalDetail } from "@/features/proposals/proposal-models";
import { getPublicProposal } from "@/features/proposals/proposal-server";
import { OrdinaryProjectHandoff } from "@/features/project-app-handoff/ordinary-project-handoff";
import { readHandoffConfig } from "@/features/project-app-handoff/handoff-config";
import { hasOrdinaryIntent } from "@/features/project-app-handoff/project-links";

type Params = Promise<{ id: string }>;

export default async function ProposalDetailPage({
  params,
  searchParams,
}: {
  params: Params;
  searchParams?: Promise<{ intent?: string | string[] }>;
}) {
  const [{ id }, query] = await Promise.all([
    params,
    searchParams ?? Promise.resolve<{ intent?: string | string[] }>({}),
  ]);
  if (!isUuid(id)) notFound();

  const result = await loadDetail(id);
  if (result.status === "error") {
    return (
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-8 p-6 md:p-10">
        <Link href="/proposals">← All proposals</Link>
        <Alert variant="destructive">
          <AlertTitle>Proposal temporarily unavailable</AlertTitle>
          <AlertDescription>
            We could not load this public proposal. Please try again.
          </AlertDescription>
        </Alert>
      </main>
    );
  }
  const proposal = result.proposal;
  if (!proposal) notFound();

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-8 p-6 md:p-10">
      <Link
        className="text-sm text-muted-foreground hover:text-foreground"
        href="/proposals"
      >
        ← All proposals
      </Link>
      <article className="flex flex-col gap-8">
        <header className="flex flex-col gap-3">
          <div className="flex items-start justify-between gap-4">
            <h1 className="text-4xl font-semibold">{proposal.title}</h1>
            <ProposalStatusBadge status={proposal.derived_status} />
          </div>
          <p className="text-xl text-muted-foreground">{proposal.summary}</p>
        </header>
        <Card>
          <CardHeader>
            <CardTitle>When and where</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4">
            <p className="flex gap-2">
              <CalendarDaysIcon
                aria-hidden="true"
                className="size-5 shrink-0"
              />
              {formatSchedule(proposal)}
            </p>
            <p className="flex gap-2">
              <MapPinIcon aria-hidden="true" className="size-5 shrink-0" />
              {proposal.public_location_label}
            </p>
            <LocationAttribution />
            {proposal.exact_location_restricted ? (
              <p data-testid="restricted-location">
                Exact location available after joining.
              </p>
            ) : (
              <p data-testid="public-exact-location">
                {proposal.exact_meeting_text}
              </p>
            )}
          </CardContent>
        </Card>
        <section className="grid gap-3">
          <h2 className="text-2xl font-semibold">About this proposal</h2>
          <p className="whitespace-pre-wrap text-base leading-7">
            {proposal.description}
          </p>
        </section>
        {proposal.skills.length > 0 ? (
          <section className="grid gap-3">
            <h2 className="text-2xl font-semibold">Skills</h2>
            <div className="flex flex-wrap gap-2">
              {proposal.skills.map((skill) => (
                <Badge
                  key={`${skill.id}:${skill.importance}`}
                  variant="outline"
                >
                  {skill.importance === "required" ? "Required" : "Useful"}:{" "}
                  {skill.label}
                </Badge>
              ))}
            </div>
          </section>
        ) : null}
        {proposal.creator_display_name ? (
          <p className="text-sm text-muted-foreground">
            Organized by {proposal.creator_display_name}
          </p>
        ) : null}
      </article>
      <OrdinaryProjectHandoff
        project={{ id, kind: "one_time" }}
        config={readHandoffConfig()}
        intent={hasOrdinaryIntent(query.intent)}
        joinable={
          proposal.derived_status === "upcoming" ||
          proposal.derived_status === "happening"
        }
      />
    </main>
  );
}

async function loadDetail(
  id: string,
): Promise<
  | { status: "ready"; proposal: PublicProposalDetail | null }
  | { status: "error" }
> {
  try {
    return { status: "ready", proposal: await getPublicProposal(id) };
  } catch {
    return { status: "error" };
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}
