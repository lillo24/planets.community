"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { removeModerationTemplateAction } from "./moderation-actions";
import type {
  TemplateRemovalInput,
  TemplateRemovalResult,
} from "./template-moderation-models";

export function TemplateRemovalForm({
  caseId,
  templateId,
  contentVersion,
  removed,
  pageStale,
}: {
  caseId: string;
  templateId: string;
  contentVersion: string;
  removed: boolean;
  pageStale: boolean;
}) {
  const router = useRouter();
  const request = useRef<TemplateRemovalInput | null>(null);
  const [reason, setReason] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [pending, setPending] = useState(false);
  const [result, setResult] = useState<TemplateRemovalResult | null>(null);
  const terminal =
    result?.status === "removed" ||
    result?.status === "already_removed" ||
    result?.status === "denied";
  const [frozen, setFrozen] = useState(false);
  async function submit(event: React.SubmitEvent<HTMLFormElement>) {
    event.preventDefault();
    if (
      pending ||
      terminal ||
      pageStale ||
      !confirmed ||
      reason.trim().length < 10 ||
      reason.trim().length > 4000
    )
      return;
    request.current ??= {
      caseId,
      templateId,
      reviewedContentVersion: contentVersion,
      requestId: crypto.randomUUID(),
      reason: reason.trim(),
    };
    setFrozen(true);
    setPending(true);
    try {
      setResult(await removeModerationTemplateAction(request.current));
    } catch {
      // Delivery may have committed. Retry the exact frozen request to recover
      // its receipt; never create a second action identifier for this attempt.
      setResult({ status: "error" });
    } finally {
      setPending(false);
    }
  }
  return (
    <section
      aria-labelledby="template-removal-heading"
      className="grid gap-3 rounded-lg border p-4"
    >
      <h3 id="template-removal-heading" className="font-semibold">
        Remove template from Workshop
      </h3>
      <p>
        This explicit action removes the template from Workshop and future
        reuse. It does not remove the source Proposal or independently created
        Projects. Completing the review is a separate action.
      </p>
      {result ? (
        <p role="status" className="whitespace-pre-wrap">
          {result.status === "removed"
            ? "Template removed. The source Proposal is unchanged."
            : result.status === "already_removed"
              ? "Already removed. The original removal time and staff attribution are retained."
              : result.status === "stale"
                ? "Template content changed. Refresh and review the current content before confirming again."
                : result.status === "denied"
                  ? "Current staff access is required. This screen cannot authorize removal."
                  : result.status === "invalid"
                    ? "The removal request is invalid. Refresh the review before starting a new request."
                    : "The result could not be confirmed. Retry the same request to recover its receipt."}
        </p>
      ) : null}
      {result?.status === "stale" || result?.status === "invalid" ? (
        <Button
          type="button"
          onClick={() => {
            request.current = null;
            setFrozen(false);
            setResult(null);
            setConfirmed(false);
            router.refresh();
          }}
        >
          Refresh review
        </Button>
      ) : null}
      {(!removed || result?.status === "error") && !terminal ? (
        <form onSubmit={submit} className="grid gap-3">
          <label htmlFor="template-removal-reason">
            Protected removal reason (10–4,000 characters)
          </label>
          <Textarea
            id="template-removal-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            required
            minLength={10}
            maxLength={4000}
            disabled={pending || frozen}
          />
          <label className="flex items-start gap-2">
            <input
              type="checkbox"
              checked={confirmed}
              disabled={pending || frozen}
              onChange={(e) => setConfirmed(e.target.checked)}
            />
            I reviewed the current template and confirm removal from Workshop.
            The source Proposal remains unchanged.
          </label>
          <Button
            type="submit"
            variant="destructive"
            disabled={
              pending ||
              pageStale ||
              !confirmed ||
              reason.trim().length < 10 ||
              result?.status === "stale" ||
              result?.status === "invalid"
            }
          >
            {pending
              ? "Removing…"
              : result?.status === "error"
                ? "Retry same removal request"
                : "Confirm template removal"}
          </Button>
        </form>
      ) : null}
    </section>
  );
}
