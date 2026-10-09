"use client";
import { useEffect, useState } from "react";
import { Flower2Icon } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { ProjectContext } from "./participant-models";
import {
  createInvitationProjectGateway,
  type InvitationProject,
  type InvitationProjectGateway,
} from "./participant-project-gateway";

export function ParticipantProjectCard({
  project,
  title,
  gateway,
}: Readonly<{
  project: ProjectContext;
  title: string;
  gateway?: InvitationProjectGateway;
}>) {
  const key = `${project.kind}:${project.id}`;
  const [attempt, setAttempt] = useState(0);
  const [state, setState] = useState<{
    key: string;
    detail?: InvitationProject;
    image?: string;
    failure?: boolean;
  }>({ key });
  useEffect(() => {
    let live = true;
    let image: string | undefined;
    async function load() {
      try {
        const current = gateway ?? createInvitationProjectGateway();
        const detail = await current.read(project);
        if (!live) return;
        if (!detail) {
          setState({ key });
          return;
        }
        setState({ key, detail });
        if (detail.coverObjectPath) {
          try {
            const cover = await current.cover(project, detail.coverObjectPath);
            if (!live) return;
            image = URL.createObjectURL(cover);
            setState({ key, detail, image });
          } catch {
            // A missing/denied cover is optional; keep the real title/description.
          }
        }
      } catch {
        if (live) setState({ key, failure: true });
      }
    }
    void load();
    return () => {
      live = false;
      if (image) URL.revokeObjectURL(image);
    };
  }, [gateway, project, key, attempt]);
  const visible = state.key === key ? state : undefined;
  return (
    <article className="overflow-hidden rounded-3xl border bg-card shadow-sm">
      {visible?.image ? (
        // Blob URLs are permission-checked SDK downloads; no image proxy/Worker.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={visible.image}
          alt={`Cover for ${visible.detail?.title ?? title}`}
          width={1280}
          height={720}
          decoding="async"
          referrerPolicy="no-referrer"
          onError={() =>
            setState((current) => ({ ...current, image: undefined }))
          }
          className="aspect-video w-full object-cover"
        />
      ) : (
        <div
          aria-hidden="true"
          className="flex aspect-video items-center justify-center bg-gradient-to-br from-violet-100 via-rose-50 to-amber-50 text-violet-400 dark:from-violet-950 dark:via-rose-950 dark:to-amber-950"
        >
          <Flower2Icon className="size-16" strokeWidth={1.2} />
        </div>
      )}
      <div className="grid gap-3 p-6 sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
          {project.kind === "one_time" ? "Project" : "Tavolo"}
        </p>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">
          {visible?.detail?.title ?? title}
        </h2>
        {visible?.detail ? (
          <p className="whitespace-pre-wrap leading-relaxed text-muted-foreground">
            {visible.detail.description}
          </p>
        ) : null}
        {visible?.failure ? (
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
            <p>We couldn&apos;t load the description.</p>
            <Button variant="ghost" onClick={() => setAttempt((n) => n + 1)}>
              Try again
            </Button>
          </div>
        ) : null}
      </div>
    </article>
  );
}
