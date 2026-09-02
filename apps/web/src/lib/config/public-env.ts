export const appEnvironments = ["local", "staging", "production"] as const;

export type AppEnvironment = (typeof appEnvironments)[number];

export type PublicEnvInput = {
  NEXT_PUBLIC_APP_ENV?: string;
  NEXT_PUBLIC_SUPABASE_URL?: string;
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string;
  NEXT_PUBLIC_SENTRY_DSN?: string;
};

export type PublicEnv = Readonly<{
  appEnv: AppEnvironment;
  supabaseUrl: string;
  supabasePublishableKey: string;
  sentryDsn?: string;
}>;

export type PublicEnvDiagnostics = Readonly<{
  appEnv: AppEnvironment;
  supabaseOrigin: string;
  sentryEnabled: boolean;
}>;

export type SentryEnvInput = Pick<
  PublicEnvInput,
  "NEXT_PUBLIC_APP_ENV" | "NEXT_PUBLIC_SENTRY_DSN"
>;

export type SentryEnv = Readonly<{
  appEnv?: AppEnvironment;
  sentryDsn?: string;
}>;

export class PublicEnvError extends Error {
  constructor(message: string) {
    super(`Invalid public web configuration: ${message}`);
    this.name = "PublicEnvError";
  }
}

export function parsePublicEnv(input: PublicEnvInput): PublicEnv {
  const appEnv = parseAppEnvironment(input.NEXT_PUBLIC_APP_ENV);
  const supabaseUrl = parseServiceUrl(
    input.NEXT_PUBLIC_SUPABASE_URL,
    "NEXT_PUBLIC_SUPABASE_URL",
  );

  if (appEnv !== "local" && new URL(supabaseUrl).protocol !== "https:") {
    throw new PublicEnvError(
      "NEXT_PUBLIC_SUPABASE_URL must use HTTPS outside local development.",
    );
  }

  const sentryDsn = parseOptionalUrl(
    input.NEXT_PUBLIC_SENTRY_DSN,
    "NEXT_PUBLIC_SENTRY_DSN",
  );

  return Object.freeze({
    appEnv,
    supabaseUrl,
    supabasePublishableKey: readRequired(
      input.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    ),
    ...(sentryDsn ? { sentryDsn } : {}),
  });
}

export function readPublicEnv(): PublicEnv {
  // NEXT_PUBLIC values must be accessed statically so Next.js can inline them
  // in browser bundles. Do not replace these reads with dynamic key access.
  return parsePublicEnv({
    NEXT_PUBLIC_APP_ENV: process.env.NEXT_PUBLIC_APP_ENV,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    NEXT_PUBLIC_SENTRY_DSN: process.env.NEXT_PUBLIC_SENTRY_DSN,
  });
}

export function parseSentryEnv(input: SentryEnvInput): SentryEnv {
  const sentryDsn = parseOptionalUrl(
    input.NEXT_PUBLIC_SENTRY_DSN,
    "NEXT_PUBLIC_SENTRY_DSN",
  );

  if (!sentryDsn) {
    return Object.freeze({});
  }

  return Object.freeze({
    appEnv: parseAppEnvironment(input.NEXT_PUBLIC_APP_ENV),
    sentryDsn,
  });
}

export function readSentryEnv(): SentryEnv {
  // Monitoring is globally optional. Do not read or require Supabase values
  // here: the informational site must build until a Supabase factory is used.
  return parseSentryEnv({
    NEXT_PUBLIC_APP_ENV: process.env.NEXT_PUBLIC_APP_ENV,
    NEXT_PUBLIC_SENTRY_DSN: process.env.NEXT_PUBLIC_SENTRY_DSN,
  });
}

export function getPublicEnvDiagnostics(
  config: PublicEnv,
): PublicEnvDiagnostics {
  return Object.freeze({
    appEnv: config.appEnv,
    supabaseOrigin: new URL(config.supabaseUrl).origin,
    sentryEnabled: Boolean(config.sentryDsn),
  });
}

function parseAppEnvironment(value: string | undefined): AppEnvironment {
  const candidate = readRequired(value, "NEXT_PUBLIC_APP_ENV");

  if (!appEnvironments.includes(candidate as AppEnvironment)) {
    throw new PublicEnvError(
      "NEXT_PUBLIC_APP_ENV must be local, staging, or production.",
    );
  }

  return candidate as AppEnvironment;
}

function parseServiceUrl(value: string | undefined, key: string): string {
  const url = parseUrl(readRequired(value, key), key);

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new PublicEnvError(`${key} must use HTTP or HTTPS.`);
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new PublicEnvError(
      `${key} must not include credentials, a query, or a fragment.`,
    );
  }

  return url.toString().replace(/\/$/, "");
}

function parseOptionalUrl(
  value: string | undefined,
  key: string,
): string | undefined {
  const candidate = value?.trim();
  if (!candidate) {
    return undefined;
  }

  const url = parseUrl(candidate, key);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new PublicEnvError(`${key} must use HTTP or HTTPS.`);
  }

  return url.toString();
}

function parseUrl(value: string, key: string): URL {
  try {
    return new URL(value);
  } catch {
    throw new PublicEnvError(`${key} must be a valid absolute URL.`);
  }
}

function readRequired(value: string | undefined, key: string): string {
  const candidate = value?.trim();
  if (!candidate) {
    throw new PublicEnvError(`${key} is required.`);
  }
  return candidate;
}
