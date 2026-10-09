"use client";
import type { ComponentProps } from "react";
import { NextNavigation } from "@/lib/navigation/next-navigation";
import { ProfileFormView } from "./profile-form-view";

export function ProfileForm(props: ComponentProps<typeof ProfileFormView>) {
  return (
    <NextNavigation>
      <ProfileFormView {...props} />
    </NextNavigation>
  );
}
