"use client";

import { useActionState, useEffect, useId, useRef, useState } from "react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
  Field,
  FieldDescription,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Textarea } from "@/components/ui/textarea";
import { moderationConsequenceAction } from "./moderation-actions";
import {
  consequenceErrors,
  parseConsequenceActionResult,
  type ConsequenceActionResult,
  type ConsequenceChoice,
} from "./moderation-consequence-models";

const initialResult: ConsequenceActionResult = { status: "idle" };
function choiceKey(choice: ConsequenceChoice) {
  return `${choice.mode}:${choice.type}:${choice.consequenceId ?? "new"}`;
}

// Receives only compatible choices, not the report/evidence/staff-note bodies.
// Action state lives above the selected form so success survives RSC revalidation
// removing an apply button or replacing an active episode with revoked history.
export function ModerationConsequenceControls({
  caseId,
  choices,
}: {
  caseId: string;
  choices: ConsequenceChoice[];
}) {
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const panelId = useId();
  const trigger = useRef<HTMLButtonElement | null>(null);
  const successFeedback = useRef<HTMLParagraphElement | null>(null);
  const errorFeedback = useRef<HTMLDivElement | null>(null);
  const [result, action, pending] = useActionState(
    async (
      previous: ConsequenceActionResult,
      data: FormData,
    ): Promise<ConsequenceActionResult> => {
      try {
        return parseConsequenceActionResult(
          await moderationConsequenceAction(previous, data),
        );
      } catch {
        return { status: "error", kind: "unavailable" };
      }
    },
    initialResult,
  );
  const selected = choices.find((choice) => choiceKey(choice) === selectedKey);
  // Saving disables the focused submit control; refreshed choices can also
  // remove its form. Restore focus to the persistent, explicit outcome instead
  // of leaving keyboard users at the document body after either kind of result.
  useEffect(() => {
    if (pending) return;
    if (result.status === "success") successFeedback.current?.focus();
    if (result.status === "error") errorFeedback.current?.focus();
  }, [result, pending]);
  return (
    <div className="flex flex-col gap-4">
      {result.status === "success" ? (
        <p role="status" tabIndex={-1} ref={successFeedback}>
          Consequence {result.kind}. Case data has been refreshed.
        </p>
      ) : null}
      {result.status === "error" ? (
        <Alert
          variant="destructive"
          role="alert"
          id={`${panelId}-error`}
          tabIndex={-1}
          ref={errorFeedback}
        >
          <AlertTitle>Consequence not confirmed</AlertTitle>
          <AlertDescription>
            {consequenceErrors[result.kind]}{" "}
            <a href={`/admin/cases/${caseId}`} className="underline">
              Reload case
            </a>
          </AlertDescription>
        </Alert>
      ) : null}
      <div className="flex flex-wrap gap-2">
        {choices.map((choice) => (
          <Button
            key={choiceKey(choice)}
            type="button"
            variant="outline"
            disabled={pending}
            aria-expanded={selectedKey === choiceKey(choice)}
            aria-controls={panelId}
            onClick={(event) => {
              trigger.current = event.currentTarget;
              setSelectedKey(choiceKey(choice));
            }}
          >
            {choice.label}
          </Button>
        ))}
      </div>
      {selected ? (
        <section
          id={panelId}
          aria-labelledby={`${panelId}-title`}
          className="flex flex-col gap-4 rounded-lg border p-4"
        >
          <h3 id={`${panelId}-title`} className="font-semibold">
            {selected.label}
          </h3>
          <p>{selected.effect}</p>
          <ConsequenceForm
            key={choiceKey(selected)}
            caseId={caseId}
            choice={selected}
            action={action}
            pending={pending}
            invalid={
              result.status === "error" && result.kind === "invalid_input"
            }
            errorId={result.status === "error" ? `${panelId}-error` : undefined}
          />
          <Button
            type="button"
            variant="ghost"
            disabled={pending}
            onClick={() => {
              setSelectedKey(null);
              trigger.current?.focus();
            }}
          >
            Cancel
          </Button>
        </section>
      ) : null}
    </div>
  );
}

function ConsequenceForm({
  caseId,
  choice,
  action,
  pending,
  invalid,
  errorId,
}: {
  caseId: string;
  choice: ConsequenceChoice;
  action: (data: FormData) => void;
  pending: boolean;
  invalid: boolean;
  errorId?: string;
}) {
  const id = useId();
  const [reason, setReason] = useState("");
  const [note, setNote] = useState("");
  // Native maxLength counts UTF-16 units; allow surrogate pairs here while the
  // server enforces PostgreSQL's exact 2,000/4,000 Unicode-character limits.
  return (
    <form action={action}>
      <input type="hidden" name="caseId" value={caseId} />
      <input type="hidden" name="type" value={choice.type} />
      <input type="hidden" name="mode" value={choice.mode} />
      {choice.consequenceId ? (
        <input
          type="hidden"
          name="consequenceId"
          value={choice.consequenceId}
        />
      ) : null}
      <FieldGroup>
        <Field data-invalid={invalid} data-disabled={pending}>
          <FieldLabel htmlFor={`${id}-reason`}>
            Reason shown to the user
          </FieldLabel>
          <FieldDescription id={`${id}-reason-help`}>
            The affected user can read this plain text. Do not include reporter
            identity or staff-only evidence. Required, at most 2,000 characters.
          </FieldDescription>
          <Textarea
            autoFocus
            id={`${id}-reason`}
            name="userReason"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            required
            maxLength={4000}
            rows={4}
            disabled={pending}
            aria-invalid={invalid}
            aria-describedby={[`${id}-reason-help`, errorId]
              .filter(Boolean)
              .join(" ")}
          />
        </Field>
        <Field data-invalid={invalid} data-disabled={pending}>
          <FieldLabel htmlFor={`${id}-note`}>
            Private moderation note
          </FieldLabel>
          <FieldDescription id={`${id}-note-help`}>
            Visible only to moderation staff, never to the affected user. Use
            for internal reasoning or evidence references. Required, at most
            4,000 characters.
          </FieldDescription>
          <Textarea
            id={`${id}-note`}
            name="internalNote"
            value={note}
            onChange={(event) => setNote(event.target.value)}
            required
            maxLength={8000}
            rows={4}
            disabled={pending}
            aria-invalid={invalid}
            aria-describedby={[`${id}-note-help`, errorId]
              .filter(Boolean)
              .join(" ")}
          />
        </Field>
        <p className="text-sm text-muted-foreground">
          Review both fields before confirming. This action does not change the
          case review state. Previously withdrawn requests and unrelated
          consequences or blocks are not restored.
        </p>
        <Button
          type="submit"
          variant={
            choice.mode === "apply" && choice.type !== "safety_notice"
              ? "destructive"
              : "default"
          }
          disabled={pending}
        >
          {pending
            ? "Saving…"
            : `Confirm ${choice.mode === "apply" ? "apply" : "revoke"}`}
        </Button>
      </FieldGroup>
    </form>
  );
}
