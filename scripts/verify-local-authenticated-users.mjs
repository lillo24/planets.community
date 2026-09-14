import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);

const users = await Promise.all(
  ["a", "b", "c"].map((suffix) =>
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `authenticated-session-${suffix}@planets.invalid`,
      verifierName: "authenticated-session",
    }),
  ),
);

await Promise.all(
  users.map(async (user) => {
    const { data, error } = await user.client
      .from("profiles")
      .insert({ id: user.id })
      .select("id")
      .single();
    if (error || data?.id !== user.id) {
      throw safeDatabaseFailure(
        "create and read an identity-bound profile anchor",
        error ?? {},
      );
    }
  }),
);

console.log(
  "Verified immediate identity-bound PostgREST access for concurrent local OTP users.",
);

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
