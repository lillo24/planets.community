"use client";
import { GroupProjectFeed } from "@/features/group-projects/group-project-feed";
import { useEffect, useState } from "react";
import { UsersRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  createGroupInvitationGateway,
  type GroupInvitationGateway,
} from "./group-gateway";
import {
  groupFailureMessage,
  groupFailure,
  type GroupCurrent,
  type PublicGroupContent,
} from "./group-models";
import type { HandoffConfig } from "@/features/project-app-handoff/handoff-config";
export function GroupLanding({
  id,
  confirmation = false,
  config = {},
  gateway,
}: Readonly<{
  id: string;
  confirmation?: boolean;
  config?: HandoffConfig;
  gateway?: GroupInvitationGateway;
}>) {
  const [active] = useState(() => gateway ?? createGroupInvitationGateway()),
    [revision, setRevision] = useState(0);
  const [read, setRead] = useState<
    Readonly<{
      loading: boolean;
      content?: PublicGroupContent | null;
      current?: GroupCurrent;
      failure?: string;
    }>
  >({ loading: true });
  useEffect(() => {
    let live = true;
    let epoch = 0;
    async function load() {
      const generation = ++epoch;
      setRead({ loading: true });
      try {
        const [auth, content] = await Promise.all([
          active.auth(),
          active.publicGroup(id),
        ]);
        if (!live || generation !== epoch) return;
        const current = auth.account
          ? await active.current(auth.account, id)
          : undefined;
        if (live && generation === epoch)
          setRead({ loading: false, content, current });
      } catch (e) {
        if (live && generation === epoch)
          setRead({
            loading: false,
            failure: groupFailureMessage(groupFailure(e)),
          });
      }
    }
    const stop = active.observeIdentity(() => {
      epoch++;
      setRead({ loading: true });
      queueMicrotask(() => {
        if (live) void load();
      });
    });
    void load();
    return () => {
      live = false;
      epoch++;
      stop();
    };
  }, [active, id, revision]);
  return (
    <div className="grid gap-5">
      <div
        className="mx-auto flex size-16 items-center justify-center rounded-2xl bg-violet-100 text-3xl"
        aria-hidden="true"
      >
        <UsersRound className="size-8" />
      </div>
      {read.loading ? (
        <p role="status">Checking group…</p>
      ) : read.failure ? (
        <>
          <p role="alert">{read.failure}</p>
          <Button onClick={() => setRevision((n) => n + 1)}>Retry</Button>
        </>
      ) : (
        <>
          <h1 className="break-words text-2xl font-semibold">
            {read.content?.name ?? "Group page unavailable"}
          </h1>
          {read.content ? (
            <>
              <p className="text-sm text-muted-foreground">
                {read.content.kind === "informal"
                  ? "Community group"
                  : "Organization"}
                {read.content.locality ? ` · ${read.content.locality}` : ""}
              </p>
              <p className="whitespace-pre-wrap leading-relaxed">
                {read.content.description}
              </p>
              <GroupProjectFeed key={id} groupId={id} />
            </>
          ) : null}
          {confirmation ? (
            <p role="status">
              {read.current?.role
                ? `Your ${read.current.role === "creator" ? "Creator" : read.current.role === "co_creator" ? "Co-creator" : "Co-organizer"} role is active.`
                : read.current?.membership
                  ? "You are part of this group."
                  : read.current
                    ? "You do not currently participate or hold an organizer role."
                    : "Sign in to check your current participation or organizer role."}
            </p>
          ) : null}
          <p>Continue in PLANETS to view this group.</p>
          <a
            className="rounded-full bg-violet-600 px-6 py-3 text-center font-medium text-white"
            href={`https://planets.community/groups/${id}`}
            referrerPolicy="no-referrer"
          >
            Open in PLANETS
          </a>
          {config.android ? (
            <a
              className="text-center underline"
              href={config.android}
              referrerPolicy="no-referrer"
            >
              Get PLANETS for Android
            </a>
          ) : null}
          {config.ios ? (
            <a
              className="text-center underline"
              href={config.ios}
              referrerPolicy="no-referrer"
            >
              Get PLANETS for iOS
            </a>
          ) : null}
        </>
      )}
    </div>
  );
}
