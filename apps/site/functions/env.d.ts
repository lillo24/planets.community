interface WaitlistEnv {
  WAITLIST_DB: D1Database;
  TURNSTILE_SECRET_KEY: string;
  TURNSTILE_EXPECTED_ACTION: string;
  TURNSTILE_EXPECTED_HOSTNAME: string;
  TURNSTILE_TESTING_MODE: "true" | "false";
}
