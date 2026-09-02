import * as Sentry from "@sentry/nextjs";
import type { Instrumentation } from "next";

import { readSentryEnv } from "@/lib/config/public-env";

export async function register(): Promise<void> {
  if (!readSentryEnv().sentryDsn) {
    return;
  }

  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("../sentry.server.config");
  }

  if (process.env.NEXT_RUNTIME === "edge") {
    await import("../sentry.edge.config");
  }
}

export const onRequestError: Instrumentation.onRequestError = (
  error,
  request,
  context,
) => {
  if (readSentryEnv().sentryDsn) {
    Sentry.captureRequestError(error, request, context);
  }
};
