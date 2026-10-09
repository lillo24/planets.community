"use client";
import type { ComponentProps } from "react";
import { NextNavigation } from "@/lib/navigation/next-navigation";
import { ProjectAppHandoffView } from "./project-app-handoff-view";

export function ProjectAppHandoff(
  props: ComponentProps<typeof ProjectAppHandoffView>,
) {
  return (
    <NextNavigation>
      <ProjectAppHandoffView {...props} />
    </NextNavigation>
  );
}
