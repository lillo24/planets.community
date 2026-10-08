// Only adjusts existing synthetic proposals on the task-owned disposable stack.
import { readFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";
import { readLocalSupabaseStatus } from "../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../scripts/lib/local-authenticated-user.mjs";

const repository = fileURLToPath(new URL("../../", import.meta.url));
const config = await readFile(`${repository}/supabase/config.toml`, "utf8");
if (!/^project_id\s*=\s*"planets-play-assets01"\s*$/m.test(config)) {
  throw new Error("Refusing to change fixtures outside planets-play-assets01.");
}
// Direct Node invocation resolves the same pinned CLI as the npm commands.
process.env.PATH = [join(repository, "node_modules", ".bin"), process.env.PATH]
  .filter(Boolean)
  .join(delimiter);
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repository);
if (apiUrl !== "http://127.0.0.1:54621") {
  throw new Error("Expected the owned capture API on loopback port 54621.");
}
const actor = await signInLocalOtpUser({
  apiUrl,
  publishableKey,
  mailpitUrl: "http://127.0.0.1:54624",
  email: "demo-alice@planets.invalid",
  verifierName: "Play visual assets",
  shouldCreateUser: false,
});
const schedules = [
  [
    "Coloriamo insieme il muro del sottopasso",
    "2026-10-10T12:00:00Z",
    "2026-10-10T16:00:00Z",
  ],
  [
    "Repair Café: aggiustiamo piccoli oggetti insieme",
    "2026-10-11T08:00:00Z",
    "2026-10-11T11:00:00Z",
  ],
];
for (const [title, startsAt, endsAt] of schedules) {
  const listed = await actor.client.rpc("list_public_proposals", {
    p_limit: 10,
    p_query: title,
  });
  if (
    listed.error ||
    listed.data?.length !== 1 ||
    listed.data[0].title !== title
  ) {
    throw new Error(
      `Expected exactly one existing synthetic proposal: ${title}`,
    );
  }
  const id = listed.data[0].proposal_id;
  const owned = await actor.client.rpc("get_own_proposal", {
    p_expected_creator_profile_id: actor.id,
    p_proposal_id: id,
  });
  if (
    owned.error ||
    owned.data?.length !== 1 ||
    owned.data[0].lifecycle_state !== "published"
  ) {
    throw new Error(
      `Expected the synthetic creator's published proposal: ${title}`,
    );
  }
  const row = owned.data[0];
  const capacity = await actor.client.rpc(
    "list_project_capacity_statuses_for_structural_actor",
    {
      p_expected_profile_id: actor.id,
      p_project_ids: [id],
    },
  );
  if (capacity.error || capacity.data?.length !== 1) {
    throw new Error(
      `Could not preserve the proposal's capacity policy: ${title}`,
    );
  }
  const result = await actor.client.rpc("update_own_proposal", {
    p_expected_creator_profile_id: actor.id,
    p_proposal_id: id,
    ...Object.fromEntries(
      [
        "title",
        "summary",
        "description",
        "event_timezone",
        "country_code",
        "locality",
        "administrative_area",
        "public_location_label",
        "exact_meeting_text",
        "exact_location_visibility",
      ].map((field) => [`p_${field}`, row[field]]),
    ),
    p_starts_at: startsAt,
    p_ends_at: endsAt,
    p_skill_ids: row.skills.map((skill) => skill.id),
    p_skill_importances: row.skills.map((skill) => skill.importance),
    p_registration_capacity: capacity.data[0].registration_capacity,
    p_count_organizers_toward_capacity:
      capacity.data[0].count_organizers_toward_capacity,
  });
  if (result.error)
    throw new Error(
      `Creator schedule update failed: ${title} (${result.error.code})`,
    );
  const checked = await actor.client.rpc("get_public_proposal", {
    p_proposal_id: id,
  });
  if (
    checked.error ||
    checked.data?.length !== 1 ||
    Date.parse(checked.data[0].starts_at) !== Date.parse(startsAt) ||
    Date.parse(checked.data[0].ends_at) !== Date.parse(endsAt)
  ) {
    throw new Error(`Public schedule verification failed: ${title}`);
  }
  console.log(`Verified synthetic schedule: ${title}`);
}
