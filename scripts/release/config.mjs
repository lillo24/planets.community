import { ReleaseError } from "./errors.mjs";

export function releaseVariant(env) {
  const variant = env.RELEASE_VARIANT ?? "staging";
  if (!["staging", "closed-test-mock"].includes(variant))
    throw new ReleaseError(
      "Unknown release variant; production is not a closed-test target",
    );
  return variant;
}

// Normal backend verification always uses STAGING_CONFIG_JSON. Only the explicit
// closed-test variant adds the dedicated public mock target to the client build.
export function releaseConfig(env) {
  const variant = releaseVariant(env);
  let config;
  try {
    config = JSON.parse(env.STAGING_CONFIG_JSON);
  } catch {
    throw new ReleaseError("Invalid staging config JSON");
  }
  const keys = [
    "MOCK_SUPABASE_URL",
    "MOCK_SUPABASE_PUBLISHABLE_KEY",
    "MOCK_PERSONA_BROKER_URL",
    "MOCK_FIXTURE_GENERATION",
  ];
  if (
    !config ||
    config.APP_ENV !== "staging" ||
    config.SUPABASE_URL !== "https://cllpvruvrrvxczjitlqd.supabase.co" ||
    config.ENABLE_DEMO_TOOLS !== "false" ||
    config.SENTRY_DSN !== "" ||
    (config.ENABLE_CLOSED_TEST_MOCK ?? "false") !== "false" ||
    keys.some((key) => (config[key] ?? "") !== "")
  )
    throw new ReleaseError(
      "Base release config requires staging, demos, Mock and Sentry off",
    );
  if (variant === "staging") return config;
  let mock;
  try {
    mock = JSON.parse(env.MOCK_CONFIG_JSON);
  } catch {
    throw new ReleaseError(
      "Closed testing Mock release needs private MOCK_CONFIG_JSON",
    );
  }
  if (
    !mock ||
    Object.keys(mock).length !== keys.length ||
    Object.keys(mock).some((key) => !keys.includes(key)) ||
    mock.MOCK_SUPABASE_URL !== "https://pnolarmzxmmjtguligfc.supabase.co" ||
    mock.MOCK_PERSONA_BROKER_URL !==
      "https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas" ||
    mock.MOCK_FIXTURE_GENERATION !== "mock-world-2026-10-21-v1" ||
    !/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(
      mock.MOCK_SUPABASE_PUBLISHABLE_KEY ?? "",
    ) ||
    mock.MOCK_SUPABASE_PUBLISHABLE_KEY === config.SUPABASE_PUBLISHABLE_KEY
  )
    throw new ReleaseError(
      "Closed testing Mock target must be complete, fixed and isolated",
    );
  return { ...config, ...mock, ENABLE_CLOSED_TEST_MOCK: "true" };
}
