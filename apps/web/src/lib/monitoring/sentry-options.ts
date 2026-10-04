import type { SentryEnv } from "@/lib/config/public-env";
import type { Breadcrumb, ErrorEvent, EventHint } from "@sentry/nextjs";
import { containsInvitationSecret } from "./invitation-privacy";

export function createSentryServerOptions(config: SentryEnv) {
  return {
    dsn: config.sentryDsn,
    enabled: Boolean(config.sentryDsn),
    environment: config.appEnv,
    sendDefaultPii: false,
    tracesSampleRate: 0,
    beforeSend: (event: ErrorEvent, hint: EventHint) =>
      containsInvitationSecret(event) ||
      containsInvitationSecret(hint.originalException)
        ? null
        : event,
    beforeBreadcrumb: (breadcrumb: Breadcrumb) =>
      containsInvitationSecret(breadcrumb) ? null : breadcrumb,
  } as const;
}

export function createSentryBrowserOptions(config: SentryEnv) {
  return {
    ...createSentryServerOptions(config),
    replaysOnErrorSampleRate: 0,
    replaysSessionSampleRate: 0,
  } as const;
}
