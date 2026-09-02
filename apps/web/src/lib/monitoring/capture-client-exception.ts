import "client-only";

import * as Sentry from "@sentry/nextjs";

import { readSentryEnv } from "@/lib/config/public-env";

export function captureClientException(error: unknown): void {
  if (readSentryEnv().sentryDsn) {
    Sentry.captureException(error);
  }
}
