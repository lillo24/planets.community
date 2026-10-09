"use client";
import type { ComponentProps } from "react";
import { NextNavigation } from "@/lib/navigation/next-navigation";
import { AuthFlowView } from "./auth-flow-view";
export type { AuthNavigation } from "./auth-flow-view";

export function AuthFlow(props: ComponentProps<typeof AuthFlowView>) {
  return (
    <NextNavigation>
      <AuthFlowView {...props} />
    </NextNavigation>
  );
}
