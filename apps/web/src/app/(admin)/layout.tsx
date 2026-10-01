import type { ReactNode } from "react";
import { notFound } from "next/navigation";

import { requireCurrentModerationStaff } from "@/features/moderation/moderation-server";

export default async function AdminLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  const access = await requireCurrentModerationStaff();
  if (!access) notFound();
  return children;
}
