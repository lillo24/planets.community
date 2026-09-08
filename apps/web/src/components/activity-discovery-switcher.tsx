import Link from "next/link";

import { cn } from "@/lib/utils";

type ActivityDiscoveryDestination = "proposals" | "tavoli";

const destinations: ReadonlyArray<{
  id: ActivityDiscoveryDestination;
  href: string;
  label: string;
}> = [
  { id: "proposals", href: "/proposals", label: "One-time Proposals" },
  { id: "tavoli", href: "/tavoli", label: "Tavoli" },
];

export function ActivityDiscoverySwitcher({
  active,
}: {
  active: ActivityDiscoveryDestination;
}) {
  return (
    <nav aria-label="Activity discovery">
      <ul className="flex w-fit gap-1 rounded-lg bg-muted p-1">
        {destinations.map((destination) => {
          const isActive = destination.id === active;
          return (
            <li key={destination.id}>
              <Link
                aria-current={isActive ? "page" : undefined}
                className={cn(
                  "inline-flex min-h-8 items-center rounded-md px-3 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-background text-foreground shadow-sm"
                    : "text-muted-foreground hover:text-foreground",
                )}
                href={destination.href}
              >
                {destination.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
