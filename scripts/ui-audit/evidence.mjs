// UIAUDIT01 private moderation evidence on the same owned fictional world.
// No staff role, case resolution, canonical row rewrite or hosted operation.
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc, operationId } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  people = await personaSessions(context);
  const rows = Object.fromEntries(
    (await sql`select fixture_key,receipt from mock_control.fixtures`).map(
      (r) => [r.fixture_key, r.receipt],
    ),
  );
  const additions = JSON.parse(
    await readFile(path.join(directory, "scenarios.json"), "utf8"),
  );
  const { giulia, marco, sara } = people;
  const request = rows["participation:marco"];
  const [current] =
    await sql`select status from public.project_join_requests where id=${request}::uuid`;
  if (current.status === "pending")
    await rpc(giulia, "accept_project_join_request", {
      p_expected_creator_profile_id: giulia.id,
      p_request_id: request,
    });
  assert.equal(
    (
      await sql`select status from public.project_join_requests where id=${request}::uuid`
    )[0].status,
    "accepted",
  );
  const [groupCase] = await rpc(sara, "submit_moderation_report", {
    p_expected_reporter_profile_id: sara.id,
    p_client_submission_id: operationId("uiaudit01:corroboration"),
    p_category: "other",
    p_explanation:
      "Segnalazione immaginaria per verificare la richiesta privata di contesto nella revisione UI.",
    p_target_kind: "profile",
    p_target_id: marco.id,
    p_context_kind: "project",
    p_context_id: rows["proposal:garden"],
  });
  const [resourceCase] = await rpc(marco, "submit_moderation_report", {
    p_expected_reporter_profile_id: marco.id,
    p_client_submission_id: operationId("uiaudit01:counterstatement"),
    p_category: "other",
    p_explanation:
      "Segnalazione immaginaria di uno scambio per la revisione UI. Nessuna persona reale coinvolta.",
    p_target_kind: "resource_request",
    p_target_id: additions.resourceRequest,
    p_context_kind: null,
    p_context_id: null,
  });
  const witness = await rpc(giulia, "list_own_moderation_evidence_requests", {
    p_expected_recipient_profile_id: giulia.id,
    p_pending_only: true,
    p_limit: 25,
  });
  const subject = await rpc(giulia, "list_own_moderation_evidence_requests", {
    p_expected_recipient_profile_id: giulia.id,
    p_pending_only: false,
    p_limit: 25,
  });
  assert.ok(
    witness.some((r) => r.request_kind === "group_corroboration"),
    "Canonical corroboration snapshot must exist",
  );
  assert.ok(
    subject.some((r) => r.request_kind === "resource_counterstatement"),
    "Canonical resource counterstatement must exist",
  );
  await writeFile(
    path.join(directory, "evidence.json"),
    JSON.stringify(
      {
        groupCase: groupCase.case_id,
        resourceCase: resourceCase.case_id,
        requests: subject,
      },
      null,
      2,
    ),
  );
  console.log(
    "Owned fictional report/evidence fixtures ready; no staff privileges granted.",
  );
} finally {
  if (people)
    for (const person of Object.values(people))
      await person.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
