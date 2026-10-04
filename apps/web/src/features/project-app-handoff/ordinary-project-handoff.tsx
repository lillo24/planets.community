"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import type { ProjectContext } from "../project-participant-invites/participant-models";
import type { HandoffConfig } from "./handoff-config";
import { projectPath } from "./project-links";
import { ProjectAppHandoff } from "./project-app-handoff";

export function OrdinaryProjectHandoff({
  project,
  config,
  intent,
  joinable,
}: Readonly<{
  project: ProjectContext;
  config: HandoffConfig;
  intent: boolean;
  joinable: boolean;
}>) {
  const router = useRouter();
  const [dismissed, setDismissed] = useState(false);
  const active = intent && !dismissed;
  return (
    <Card aria-labelledby="ordinary-join-title" data-join-intent={active}>
      <CardHeader>
        <CardTitle id="ordinary-join-title">
          {active ? "Want to join?" : "Take part with PLANETS"}
        </CardTitle>
        <CardDescription>
          {joinable
            ? "Inspect the Project here, then continue in the app when you are ready."
            : "This activity is not currently accepting participation. You can still view it in the app."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ProjectAppHandoff
          project={project}
          config={config}
          ordinaryIntent={joinable}
        />
      </CardContent>
      {active ? (
        <CardFooter>
          <Button
            variant="ghost"
            onClick={() => {
              setDismissed(true);
              router.replace(projectPath(project), { scroll: false });
            }}
          >
            Dismiss joining intent
          </Button>
        </CardFooter>
      ) : null}
    </Card>
  );
}
