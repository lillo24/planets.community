import Link from "next/link";
import { SearchXIcon } from "lucide-react";

import { ActivityDiscoverySwitcher } from "@/components/activity-discovery-switcher";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  NativeSelect,
  NativeSelectOption,
} from "@/components/ui/native-select";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationNext,
} from "@/components/ui/pagination";
import { EmptyState } from "@/components/states/empty-state";
import { ProposalCard } from "@/features/proposals/proposal-components";
import {
  decodeProposalCursor,
  encodeProposalCursor,
} from "@/features/proposals/proposal-models";
import {
  listPublicProposals,
  listSkillOptions,
  publicProposalPageSize,
} from "@/features/proposals/proposal-server";
import type {
  PublicProposalSummary,
  SkillOption,
} from "@/features/proposals/proposal-models";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function ProposalsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const locality = single(params.locality)?.trim().slice(0, 120) || undefined;
  const skillId = uuid(single(params.skill)) ? single(params.skill) : undefined;
  const query = single(params.query)?.trim().slice(0, 120) || undefined;
  const phase = single(params.phase);
  const definitionPhase =
    phase === "idea" || phase === "defined" ? phase : undefined;
  const cursor = decodeProposalCursor(single(params.cursor));

  const result = await loadPageData({
    locality,
    skillId,
    query,
    definitionPhase,
    cursor,
  });
  if (result.status === "error") {
    return (
      <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 p-6 md:p-10">
        <h1 className="text-4xl font-semibold">One-time proposals</h1>
        <Alert variant="destructive">
          <AlertTitle>Proposals are temporarily unavailable</AlertTitle>
          <AlertDescription>
            We could not load public proposals. Please try again.
          </AlertDescription>
        </Alert>
      </main>
    );
  }
  const { proposals, skills } = result;
  const nextCursor =
    proposals.length === publicProposalPageSize
      ? encodeProposalCursor({
          publishedAt: proposals[proposals.length - 1].published_at!,
          referenceTime: proposals[proposals.length - 1].reference_time!,
          id: proposals[proposals.length - 1].proposal_id,
        })
      : undefined;

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 p-6 md:p-10">
      <header className="flex flex-col gap-3">
        <Link className="text-sm font-semibold tracking-[0.2em]" href="/">
          PLANETS
        </Link>
        <h1 className="text-4xl font-semibold">One-time proposals</h1>
        <p className="max-w-2xl text-lg text-muted-foreground">
          Find a local activity where people are building, growing, creating, or
          helping together.
        </p>
        <ActivityDiscoverySwitcher active="proposals" />
        <p className="text-sm text-muted-foreground">
          Newest published first, including Ideas to plan together.
        </p>
      </header>
      <form
        className="grid gap-3 rounded-xl bg-muted/40 p-4 sm:grid-cols-2"
        action="/proposals"
      >
        <label className="grid gap-1 text-sm font-medium">
          Search
          <Input
            name="query"
            defaultValue={query}
            maxLength={120}
            placeholder="Search projects"
          />
        </label>
        <label className="grid gap-1 text-sm font-medium">
          Planning phase
          <NativeSelect
            name="phase"
            defaultValue={definitionPhase ?? ""}
            className="w-full"
          >
            <NativeSelectOption value="">All</NativeSelectOption>
            <NativeSelectOption value="idea">In definition</NativeSelectOption>
            <NativeSelectOption value="defined">Defined</NativeSelectOption>
          </NativeSelect>
        </label>
        <label className="grid gap-1 text-sm font-medium">
          Locality
          <Input
            name="locality"
            defaultValue={locality}
            maxLength={120}
            placeholder="For example, Bologna"
          />
        </label>
        <label className="grid gap-1 text-sm font-medium">
          Skill
          <NativeSelect
            className="w-full"
            name="skill"
            defaultValue={skillId ?? ""}
          >
            <NativeSelectOption value="">Any skill</NativeSelectOption>
            {skills.map((skill) => (
              <NativeSelectOption key={skill.id} value={skill.id}>
                {skill.label}
              </NativeSelectOption>
            ))}
          </NativeSelect>
        </label>
        <Button className="self-end" type="submit">
          Filter
        </Button>
      </form>
      {proposals.length === 0 ? (
        <EmptyState
          title="No proposals found"
          description="Try another locality or skill, or check again later."
          icon={<SearchXIcon />}
        />
      ) : (
        <section
          aria-label="Proposal results"
          className="grid gap-5 md:grid-cols-2"
        >
          {proposals.map((proposal) => (
            <ProposalCard key={proposal.proposal_id} proposal={proposal} />
          ))}
        </section>
      )}
      {nextCursor ? (
        <Pagination>
          <PaginationContent>
            <PaginationItem>
              <PaginationNext
                text="More proposals"
                href={proposalUrl({
                  locality,
                  skillId,
                  query,
                  definitionPhase,
                  cursor: nextCursor,
                })}
              />
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      ) : null}
    </main>
  );
}

async function loadPageData(
  filters: Parameters<typeof listPublicProposals>[0],
): Promise<
  | {
      status: "ready";
      proposals: PublicProposalSummary[];
      skills: SkillOption[];
    }
  | { status: "error" }
> {
  try {
    const [proposals, skills] = await Promise.all([
      listPublicProposals(filters),
      listSkillOptions(),
    ]);
    return { status: "ready", proposals, skills };
  } catch {
    return { status: "error" };
  }
}

export function proposalUrl({
  locality,
  skillId,
  query: search,
  definitionPhase,
  cursor,
}: {
  locality?: string;
  skillId?: string;
  query?: string;
  definitionPhase?: "idea" | "defined";
  cursor?: string;
}): string {
  const query = new URLSearchParams();
  if (locality) query.set("locality", locality);
  if (skillId) query.set("skill", skillId);
  if (search) query.set("query", search);
  if (definitionPhase) query.set("phase", definitionPhase);
  if (cursor) query.set("cursor", cursor);
  const suffix = query.toString();
  return suffix ? `/proposals?${suffix}` : "/proposals";
}

function single(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function uuid(value?: string): boolean {
  return Boolean(
    value &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    ),
  );
}
