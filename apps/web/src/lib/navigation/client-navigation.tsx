"use client";

import {
  createContext,
  useContext,
  type ComponentType,
  type ComponentProps,
  type ReactNode,
} from "react";

export type ClientNavigation = Readonly<{
  replace(destination: string): void;
  refresh(): void;
}>;
export type ClientLinkProps = ComponentProps<"a"> & {
  href: string;
  prefetch?: false;
};
type NavigationAdapter = ClientNavigation & {
  Link: ComponentType<ClientLinkProps>;
};
const NavigationContext = createContext<NavigationAdapter | null>(null);

// Each host supplies real navigation; the shared invitation UI imports no Next runtime.
export function ClientNavigationProvider({
  adapter,
  children,
}: Readonly<{ adapter: NavigationAdapter; children: ReactNode }>) {
  return <NavigationContext value={adapter}>{children}</NavigationContext>;
}
export function useClientNavigation() {
  const adapter = useContext(NavigationContext);
  if (!adapter) throw new Error("A client navigation adapter is required.");
  return adapter;
}
export function ClientLink(props: ClientLinkProps) {
  const { Link } = useClientNavigation();
  return <Link {...props} />;
}
