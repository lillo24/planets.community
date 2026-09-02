import * as Sentry from "@sentry/nextjs";

import { readSentryEnv } from "@/lib/config/public-env";
import { createSentryServerOptions } from "@/lib/monitoring/sentry-options";

const config = readSentryEnv();

if (config.sentryDsn) {
  Sentry.init(createSentryServerOptions(config));
}
