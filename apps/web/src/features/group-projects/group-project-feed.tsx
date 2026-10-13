"use client";
import { useEffect, useRef, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { parseGroupProjects, type GroupProject } from "./group-project-models";

export type GroupProjectReader = (
  group: string,
  after?: GroupProject,
) => Promise<GroupProject[]>;
const read: GroupProjectReader = async (group, after) => {
  const { data, error } = await createSupabaseBrowserClient().rpc(
    "list_public_group_projects",
    {
      p_group_id: group,
      p_limit: 20,
      p_cursor_id: after?.id,
      p_cursor_published_at: after?.publishedAt,
    },
  );
  if (error) throw error;
  return parseGroupProjects(data);
};
export function GroupProjectFeed({
  groupId,
  reader = read,
}: Readonly<{ groupId: string; reader?: GroupProjectReader }>) {
  const [state, setState] = useState<{
    items: GroupProject[];
    busy: boolean;
    more: boolean;
    failed: boolean;
  }>({ items: [], busy: true, more: true, failed: false });
  const epoch = useRef(0);
  useEffect(() => {
    const current = ++epoch.current;
    setState({ items: [], busy: true, more: true, failed: false });
    reader(groupId)
      .then((items) => {
        if (epoch.current === current)
          setState({
            items,
            busy: false,
            more: items.length === 20,
            failed: false,
          });
      })
      .catch(() => {
        if (epoch.current === current)
          setState({ items: [], busy: false, more: true, failed: true });
      });
    return () => {
      // This ref is a request generation, never a DOM node. Invalidate every
      // in-flight page on unmount, including a later Load more generation.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      epoch.current++;
    };
  }, [groupId, reader]);
  async function more() {
    if (state.busy) return;
    const current = ++epoch.current;
    setState((s) => ({ ...s, busy: true, failed: false }));
    try {
      const page = await reader(groupId, state.items.at(-1));
      if (epoch.current === current)
        setState((s) => ({
          items: [...s.items, ...page],
          busy: false,
          more: page.length === 20,
          failed: false,
        }));
    } catch (e) {
      if (epoch.current === current)
        setState((s) => ({
          ...s,
          items:
            typeof e === "object" &&
            e !== null &&
            "code" in e &&
            e.code === "42501"
              ? []
              : s.items,
          busy: false,
          failed: true,
        }));
    }
  }
  return (
    <section className="grid gap-4" aria-label="Projects and Tavoli">
      <h2 className="text-xl font-semibold">Projects and Tavoli</h2>
      {state.items.map((item) => (
        <Card key={item.id}>
          <CardHeader>
            <CardTitle className="min-w-0 break-words">
              <a
                href={
                  item.kind === "recurring"
                    ? `/tavoli/${item.id}`
                    : `/proposals/${item.id}`
                }
              >
                {item.title}
              </a>
            </CardTitle>
            <CardDescription className="break-words">
              {item.summary}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {item.kind === "recurring"
                ? "Tavolo"
                : item.idea
                  ? "In definition"
                  : "Project"}
            </p>
          </CardContent>
        </Card>
      ))}
      {state.busy ? <p role="status">Loading Projects…</p> : null}
      {state.failed ? (
        <Alert variant="destructive">
          <AlertTitle>Projects unavailable</AlertTitle>
          <AlertDescription>
            Could not load this page. Please try again.
          </AlertDescription>
        </Alert>
      ) : null}
      {!state.busy && !state.failed && state.items.length === 0 ? (
        <p>No public Projects or Tavoli yet.</p>
      ) : null}
      {!state.busy && (state.more || state.failed) ? (
        <Button variant="outline" onClick={() => void more()}>
          {state.failed ? "Retry" : "Load more"}
        </Button>
      ) : null}
    </section>
  );
}
