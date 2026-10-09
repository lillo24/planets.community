"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import type { ReactNode } from "react";
import {
  ClientNavigationProvider,
  type ClientLinkProps,
} from "./client-navigation";

function NextClientLink(props: ClientLinkProps) {
  return <Link {...props} />;
}
export function NextNavigation({
  children,
}: Readonly<{ children: ReactNode }>) {
  const router = useRouter();
  return (
    <ClientNavigationProvider
      adapter={{
        replace: router.replace,
        refresh: router.refresh,
        Link: NextClientLink,
      }}
    >
      {children}
    </ClientNavigationProvider>
  );
}
