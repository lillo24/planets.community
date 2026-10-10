import assert from "node:assert/strict";
import test from "node:test";
import {
  applyParticipationRpcNullability,
  participationRpcNullableFields,
  participationRpcNullableNumberFields,
} from "./participation-rpc-nullability.mjs";

const fixture = () =>
  Object.entries(participationRpcNullableFields)
    .map(
      ([name, fields]) =>
        `      ${name}: {\n        Args: { p_expected_profile_id: string }\n        Returns: {\n${fields.map((field) => `          ${field}: string`).join("\n")}\n${(participationRpcNullableNumberFields[name] ?? []).map((field) => `          ${field}: number\n`).join("")}          unchanged: string\n        }[]\n      }`,
    )
    .join("\n");

test("nullable participation results are accurate while unrelated fields stay unchanged", () => {
  const output = applyParticipationRpcNullability(fixture());
  for (const fields of Object.values(participationRpcNullableFields)) {
    for (const field of fields)
      assert.ok(output.includes(`${field}: string | null`));
  }
  assert.ok(output.includes("Args: { p_expected_profile_id: string }"));
  assert.ok(output.includes("unchanged: string\n"));
  assert.ok(output.includes("pending_count: number | null"));
});
test("already accurate generated results are unchanged", () => {
  const output = applyParticipationRpcNullability(fixture());
  assert.equal(applyParticipationRpcNullability(output), output);
});

test("Idea logistics are nullable without weakening legacy event results", () => {
  const legacy =
    "      get_public_proposal: {\n        Returns: {\n          starts_at: string\n        }[]\n      }";
  const output = applyParticipationRpcNullability(`${fixture()}\n${legacy}`);
  assert.ok(output.includes(legacy));
  assert.ok(output.includes("starts_at: string | null"));
  assert.ok(output.includes("derived_status: string | null"));
  assert.ok(!participationRpcNullableFields.get_public_proposal);
});
test("missing RPCs fail instead of writing partial generated types", () => {
  assert.throws(
    () => applyParticipationRpcNullability(""),
    /missing participation RPC/,
  );
});
test("schema/type drift fails with the owning RPC and column", () => {
  assert.throws(
    () =>
      applyParticipationRpcNullability(
        fixture().replace("membership_id: string", "membership_id: number"),
      ),
    /accept_project_participant_invitation.*membership_id/,
  );
});
