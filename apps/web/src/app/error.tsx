"use client";

import { useEffect } from "react";

import { RecoverableErrorState } from "@/components/states/recoverable-error-state";
import { captureClientException } from "@/lib/monitoring/capture-client-exception";

type ErrorPageProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function ErrorPage({ error, reset }: ErrorPageProps) {
  useEffect(() => {
    captureClientException(error);
  }, [error]);

  return (
    <main className="flex min-h-screen items-center justify-center p-8">
      <RecoverableErrorState
        title="PLANETS could not load this page"
        description="Try again. If the problem continues, return later."
        onRetry={reset}
      />
    </main>
  );
}
