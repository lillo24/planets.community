import * as Sentry from "@sentry/nextjs";

import { readSentryEnv } from "@/lib/config/public-env";
import { createSentryBrowserOptions } from "@/lib/monitoring/sentry-options";

const config = readSentryEnv();

if (config.sentryDsn) {
  Sentry.init(createSentryBrowserOptions(config));
}

export function onRouterTransitionStart(
  url: string,
  navigationType: "push" | "replace" | "traverse",
): void {
  if (config.sentryDsn) {
    Sentry.captureRouterTransitionStart(url, navigationType);
  }
}
