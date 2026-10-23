"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { moderateCoProposalAction } from "./moderation-actions";
import type {
  CoProposalReview,
  CoProposalModerationInput,
  CoProposalModerationResult,
  CoProposalOperation,
} from "./cocreate-proposal-models";

export function CoProposalReviewView({
  review,
  caseId,
}: {
  review: CoProposalReview;
  caseId: string;
}) {
  const router = useRouter();
  const request = useRef<CoProposalModerationInput | null>(null),
    busy = useRef(false);
  const [pending, setPending] = useState(false),
    [result, setResult] = useState<CoProposalModerationResult | null>(null);
  const [frozenOperation, setFrozenOperation] =
    useState<CoProposalOperation | null>(null);
  async function submit(operation: CoProposalOperation) {
    if (busy.current || (result && result.status !== "error")) return;
    busy.current = true;
    setPending(true);
    request.current ??= {
      caseId,
      proposalId: review.evidence.proposalId,
      version: review.version,
      operation,
      commandId: crypto.randomUUID(),
    };
    setFrozenOperation(request.current.operation);
    try {
      const next = await moderateCoProposalAction(request.current);
      setResult(next);
      if (next.status === "accepted" || next.status === "stale")
        router.refresh();
    } catch {
      setResult({ status: "error" });
    } finally {
      busy.current = false;
      setPending(false);
    }
  }
  const labels = {
    suppress: "Suppress proposal",
    restore: "Restore proposal",
    reject: "Reject pending proposal",
  };
  const operations: CoProposalOperation[] = frozenOperation
    ? [frozenOperation]
    : [
        review.suppressed ? "restore" : "suppress",
        ...(review.state === "pending" ? ["reject" as const] : []),
      ];
  return (
    <Card>
      <CardHeader>
        <CardTitle>Reported community proposal</CardTitle>
        <CardDescription>
          Exact proposal snapshot from this case. These controls affect the
          proposal; an activated hub and its chat history keep their existing
          rules.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <h3>{review.evidence.name}</h3>
        <p>{review.evidence.locality}</p>
        <p className="whitespace-pre-wrap">{review.evidence.explanation}</p>
        <p>
          Current state: {review.state} · version {review.version} ·{" "}
          {review.suppressed ? "suppressed" : "visible if otherwise eligible"}
        </p>
        {result ? (
          <p role="status">
            {result.status === "error"
              ? "Result unconfirmed. Retry the same frozen action."
              : result.status === "accepted"
                ? "Proposal action accepted."
                : result.status === "stale"
                  ? "Proposal changed. Reload and review its current version."
                  : result.status === "denied"
                    ? "Current staff access is required."
                    : "Invalid proposal action. Reload the case."}
          </p>
        ) : null}
        <div className="flex flex-wrap gap-2">
          {operations.map((op) => (
            <Button
              key={op}
              variant={op === "restore" ? "outline" : "destructive"}
              disabled={pending || (!!result && result.status !== "error")}
              onClick={() => submit(op)}
            >
              {pending
                ? "Saving…"
                : result?.status === "error"
                  ? "Retry same proposal action"
                  : labels[op]}
            </Button>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
