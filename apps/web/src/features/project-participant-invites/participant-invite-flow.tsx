"use client";
import type { ComponentProps } from "react";
import { NextNavigation } from "@/lib/navigation/next-navigation";
import { ParticipantInviteFlowView } from "./participant-invite-flow-view";
export { FailureAlert } from "./participant-invite-flow-view";

export function ParticipantInviteFlow(
  props: ComponentProps<typeof ParticipantInviteFlowView>,
) {
  return (
    <NextNavigation>
      <ParticipantInviteFlowView {...props} />
    </NextNavigation>
  );
}
