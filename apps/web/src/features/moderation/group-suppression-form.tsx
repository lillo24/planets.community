"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { setGroupSuppressionAction } from "./moderation-actions";
import type {
  GroupSuppressionInput,
  GroupSuppressionResult,
} from "./group-moderation-models";

export function GroupSuppressionForm({
  caseId,
  groupId,
  version,
  suppressed,
}: {
  caseId: string;
  groupId: string;
  version: number;
  suppressed: boolean;
}) {
  const router = useRouter();
  const request = useRef<GroupSuppressionInput | null>(null);
  const [reason, setReason] = useState("");
  const [pending, setPending] = useState(false);
  const [frozen, setFrozen] = useState(false);
  const [result, setResult] = useState<GroupSuppressionResult | null>(null);
  const busy = useRef(false);
  const length = Array.from(reason.trim()).length;
  const terminal = result && result.status !== "error";
  async function submit(event: React.SubmitEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy.current || terminal || length < 10 || length > 4000) return;
    busy.current = true;
    request.current ??= {
      caseId,
      groupId,
      version,
      suppressed: !suppressed,
      reason: reason.trim(),
      requestId: crypto.randomUUID(),
    };
    setPending(true);
    setFrozen(true);
    try {
      const next = await setGroupSuppressionAction(request.current);
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
  return (
    <section
      aria-labelledby="group-suppression-heading"
      className="grid gap-3 rounded-lg border p-4"
    >
      <h3 id="group-suppression-heading" className="font-semibold">
        Directory eligibility
      </h3>
      <p>
        Hiding removes public directory eligibility. Restoring only clears staff
        suppression; it does not publish drafts or archived pages, or restore an
        absent manager. Case review transitions are separate.
      </p>
      {result ? (
        <p role="status">
          {result.status === "accepted"
            ? "Directory suppression updated. Reloading current group context."
            : result.status === "stale"
              ? "This group changed. Review the reloaded current version before a new action."
              : result.status === "denied"
                ? "Current staff access is required. No action is authorized by this screen."
                : result.status === "invalid"
                  ? "Invalid request. Reload and review before starting another action."
                  : "Result unconfirmed. Retry the same frozen request to recover its receipt."}
        </p>
      ) : null}
      {terminal ? (
        <Button onClick={() => router.refresh()}>Reload current review</Button>
      ) : (
        <form onSubmit={submit} className="grid gap-3">
          <label htmlFor="group-suppression-reason">
            Private reason (10–4,000 characters)
          </label>
          <Textarea
            id="group-suppression-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            disabled={pending || frozen}
            required
          />
          <Button
            type="submit"
            variant={suppressed ? "outline" : "destructive"}
            disabled={pending || length < 10 || length > 4000}
          >
            {pending
              ? "Saving…"
              : result?.status === "error"
                ? "Retry same directory action"
                : suppressed
                  ? "Restore directory eligibility"
                  : "Hide from directory"}
          </Button>
        </form>
      )}
    </section>
  );
}
