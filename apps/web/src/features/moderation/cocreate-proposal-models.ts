import { isUuid } from "./moderation-models";

export type CoProposalReview = Readonly<{
  evidence: Readonly<{
    proposalId: string;
    name: string;
    locality: string;
    explanation: string;
    category: string;
    createdAt: string;
  }>;
  version: number;
  state: "pending" | "activated" | "cancelled" | "rejected";
  suppressed: boolean;
}>;
export type CoProposalOperation = "suppress" | "restore" | "reject";
export type CoProposalModerationInput = Readonly<{
  caseId: string;
  proposalId: string;
  commandId: string;
  version: number;
  operation: CoProposalOperation;
}>;
export type CoProposalModerationResult = Readonly<{
  status: "accepted" | "stale" | "denied" | "invalid" | "error";
}>;

function object(value: unknown, keys: string[]): Record<string, unknown> {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).length !== keys.length ||
    !keys.every((k) => k in value)
  ) {
    throw new Error("The proposal report evidence is malformed.");
  }
  return value as Record<string, unknown>;
}
function text(value: unknown, max: number, empty = false): string {
  if (
    typeof value !== "string" ||
    Array.from(value).length > max ||
    (!empty && !value.trim())
  ) {
    throw new Error("The proposal report evidence is malformed.");
  }
  return value;
}
export function parseCoProposalReview(value: unknown): CoProposalReview {
  const r = object(value, ["evidence", "version", "suppressed", "state"]);
  const e = object(r.evidence, [
    "proposal_id",
    "category_id",
    "name",
    "locality",
    "explanation",
    "state",
    "interested_count",
    "activation_threshold",
    "hub_id",
    "version",
    "created_at",
    "expires_at",
  ]);
  const category = text(e.category_id, 31);
  if (
    !isUuid(e.proposal_id) ||
    !Number.isSafeInteger(r.version) ||
    (r.version as number) < 1 ||
    typeof r.suppressed !== "boolean" ||
    !["pending", "activated", "cancelled", "rejected"].includes(
      r.state as string,
    ) ||
    !/^[a-z][a-z_]{1,30}$/.test(category) ||
    !Number.isSafeInteger(e.interested_count) ||
    (e.interested_count as number) < 0 ||
    !Number.isSafeInteger(e.activation_threshold) ||
    (e.activation_threshold as number) < 3 ||
    (e.activation_threshold as number) > 10 ||
    !Number.isSafeInteger(e.version) ||
    (e.version as number) < 1 ||
    !["pending", "activated", "cancelled", "rejected", "expired"].includes(
      e.state as string,
    ) ||
    (e.hub_id !== null && !isUuid(e.hub_id)) ||
    (e.state === "activated") !== (e.hub_id !== null) ||
    typeof e.created_at !== "string" ||
    !Number.isFinite(Date.parse(e.created_at)) ||
    typeof e.expires_at !== "string" ||
    !(Date.parse(e.expires_at) > Date.parse(e.created_at))
  ) {
    throw new Error("The proposal report evidence is malformed.");
  }
  return {
    version: r.version as number,
    state: r.state as CoProposalReview["state"],
    suppressed: r.suppressed,
    evidence: {
      proposalId: e.proposal_id,
      category,
      name: text(e.name, 80),
      locality: text(e.locality, 100),
      explanation: text(e.explanation, 500, true),
      createdAt: e.created_at,
    },
  };
}
