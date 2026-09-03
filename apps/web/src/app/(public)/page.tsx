import Link from "next/link";

import { AuthStatusCard } from "@/features/auth/auth-status-card";
import { readCurrentAuth } from "@/features/auth/current-auth";

export default async function PublicHomePage() {
  const authState = await readCurrentAuth();

  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      <section
        aria-labelledby="public-home-title"
        className="flex w-full max-w-2xl flex-col gap-6"
      >
        <p className="text-sm font-semibold tracking-[0.2em]">PLANETS</p>
        <h1 id="public-home-title" className="text-4xl font-semibold">
          Build something local, together.
        </h1>
        <p className="max-w-xl text-lg text-muted-foreground">
          PLANETS is a community for creating, discovering, and joining local
          collaborative activities.
        </p>
        <Link
          className="inline-flex h-9 w-fit items-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/80"
          href="/proposals"
        >
          Browse one-time proposals
        </Link>
        <AuthStatusCard state={authState} />
      </section>
    </main>
  );
}
