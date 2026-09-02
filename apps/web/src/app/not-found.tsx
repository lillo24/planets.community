import { CircleSlash2Icon } from "lucide-react";
import Link from "next/link";

import { EmptyState } from "@/components/states/empty-state";
import { buttonVariants } from "@/components/ui/button";

export default function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      <EmptyState
        title="Page unavailable"
        description="This page does not exist or is not available yet."
        icon={<CircleSlash2Icon />}
      >
        <Link href="/" className={buttonVariants({ variant: "outline" })}>
          Return home
        </Link>
      </EmptyState>
    </main>
  );
}
