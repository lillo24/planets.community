// UIAUDIT01 private moderation evidence on the same owned fictional world.
// No staff role, case resolution, canonical row rewrite or hosted operation.
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  people = await personaSessions(context);
  const { data, error } = await people.iris.client.rpc(
    "list_own_moderation_reports_v4",
    {
      p_expected_reporter_profile_id: people.iris.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_report_id: null,
    },
  );
  const diagnostic = {
    error: error ? { code: error.code, message: error.message } : null,
    rows: data?.map((r) => ({
      targetKind: r.target_kind,
      targetSummary: r.target_summary,
      targetSummaryType: typeof r.target_summary,
    })),
  };
  await writeFile(
    path.join(directory, "report-read-diagnostic.json"),
    JSON.stringify(diagnostic, null, 2),
  );
  if (error) {
    throw new Error(
      `Iris own-report RPC failed: ${error.code}: ${error.message}`,
    );
  }
  console.log(JSON.stringify(diagnostic));
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
