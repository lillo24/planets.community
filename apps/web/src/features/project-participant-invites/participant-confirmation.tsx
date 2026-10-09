"use client";
import type { ComponentProps } from "react";
import { NextNavigation } from "@/lib/navigation/next-navigation";
import { ParticipantConfirmationView } from "./participant-confirmation-view";

export function ParticipantConfirmation(
  props: ComponentProps<typeof ParticipantConfirmationView>,
) {
  return (
    <NextNavigation>
      <ParticipantConfirmationView {...props} />
    </NextNavigation>
  );
}
