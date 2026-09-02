import type { SentryEnv } from "@/lib/config/public-env";

export function createSentryServerOptions(config: SentryEnv) {
  return {
    dsn: config.sentryDsn,
    enabled: Boolean(config.sentryDsn),
    environment: config.appEnv,
    sendDefaultPii: false,
    tracesSampleRate: 0,
  } as const;
}

export function createSentryBrowserOptions(config: SentryEnv) {
  return {
    ...createSentryServerOptions(config),
    replaysOnErrorSampleRate: 0,
    replaysSessionSampleRate: 0,
  } as const;
}
