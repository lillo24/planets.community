// UIAUDIT01 genuine pending donation terms for the additive Resource request.
// Acceptance is performed in the native UI, not by this fixture helper.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { personaSessions, rpc } from "../mock/world.mjs";
import { openOwnedWorld } from "./owned-world.mjs";

const { directory, sql, context } = await openOwnedWorld(process.argv[2]);
let people;
try {
  await context.guard();
  people = await personaSessions(context);
  const { marco } = people;
  const add = JSON.parse(
    await readFile(path.join(directory, "scenarios.json"), "utf8"),
  );
  const agreement = await rpc(marco, "get_resource_exchange_agreement", {
    p_expected_profile_id: marco.id,
    p_request_id: add.resourceRequest,
  });
  const value = Array.isArray(agreement) ? agreement[0] : agreement;
  const terms = await rpc(marco, "propose_resource_exchange_terms", {
    p_expected_profile_id: marco.id,
    p_agreement_id: value.agreement_id,
    p_expected_current_terms_id: value.current_terms_id,
    p_expected_pending_terms_id: value.pending_terms_id,
    p_owner_transfer_kind: "give",
    p_owner_lend_starts_at: null,
    p_owner_lend_ends_at: null,
    p_requester_transfer_kind: "none",
    p_requester_resource_description: null,
    p_requester_lend_starts_at: null,
    p_requester_lend_ends_at: null,
    p_private_note: "Consegna immaginaria dei vasi, senza pagamenti.",
  });
  await writeFile(
    path.join(directory, "agreement.json"),
    JSON.stringify({ agreement: value.agreement_id, terms }, null, 2),
  );
  console.log(
    "Genuine pending Resource terms prepared through ordinary owner RPC.",
  );
} finally {
  if (people)
    for (const p of Object.values(people))
      await p.client.auth.signOut({ scope: "local" });
  await sql.end({ timeout: 5 });
}
