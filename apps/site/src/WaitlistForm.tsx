import { type FormEvent, useCallback, useState } from "react";

import { TurnstileWidget } from "./TurnstileWidget";
import { validateEmailAddress } from "./email-validation";
import { submitWaitlist, type WaitlistSubmission } from "./waitlist-api";
import { WAITLIST_TURNSTILE_SITE_KEY } from "./waitlist-config";

type Feedback =
  | { kind: "idle"; field: null; message: "" }
  | {
      kind: "error";
      field: "email" | "consent" | "turnstile" | "request";
      message: string;
    }
  | { kind: "submitting"; field: null; message: string }
  | { kind: "success"; field: null; message: string };

type WaitlistFormProps = {
  apiClient?: (submission: WaitlistSubmission) => Promise<void>;
  turnstileSiteKey?: string | null;
};

const idleFeedback: Feedback = { kind: "idle", field: null, message: "" };

function readTurnstileToken(form: HTMLFormElement) {
  const token = new FormData(form).get("cf-turnstile-response");
  return typeof token === "string" ? token : "";
}

export function WaitlistForm({
  apiClient = submitWaitlist,
  turnstileSiteKey = WAITLIST_TURNSTILE_SITE_KEY,
}: WaitlistFormProps) {
  const [email, setEmail] = useState("");
  const [consent, setConsent] = useState(false);
  const [feedback, setFeedback] = useState<Feedback>(idleFeedback);

  const isSubmitting = feedback.kind === "submitting";
  const isComplete = feedback.kind === "success";
  const controlsDisabled = isSubmitting || isComplete;

  const showTurnstileFailure = useCallback(() => {
    setFeedback((current) =>
      current.kind === "submitting" || current.kind === "success"
        ? current
        : {
            kind: "error",
            field: "turnstile",
            message:
              "La verifica anti-abuso non è riuscita. Attendi il nuovo tentativo o ricarica la pagina.",
          },
    );
  }, []);

  const clearTurnstileFailure = useCallback(() => {
    setFeedback((current) =>
      current.kind === "error" && current.field === "turnstile"
        ? idleFeedback
        : current,
    );
  }, []);

  function clearFailure() {
    if (feedback.kind === "error") {
      setFeedback(idleFeedback);
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (controlsDisabled) {
      return;
    }

    if (!validateEmailAddress(email)) {
      setFeedback({
        kind: "error",
        field: "email",
        message: "Inserisci un indirizzo email valido.",
      });
      return;
    }

    if (!consent) {
      setFeedback({
        kind: "error",
        field: "consent",
        message: "Conferma di voler ricevere la sola email di lancio.",
      });
      return;
    }

    const turnstileToken = readTurnstileToken(event.currentTarget);
    if (!turnstileSiteKey || turnstileToken.length === 0) {
      setFeedback({
        kind: "error",
        field: "turnstile",
        message: "Completa la verifica anti-abuso e riprova.",
      });
      return;
    }

    setFeedback({
      kind: "submitting",
      field: null,
      message: "Invio della richiesta in corso…",
    });

    try {
      await apiClient({
        email: email.trim(),
        consent: true,
        turnstileToken,
      });
      setEmail("");
      setConsent(false);
      setFeedback({
        kind: "success",
        field: null,
        message:
          "Perfetto. Ti avviseremo una sola volta quando PLANETS sarà disponibile.",
      });
    } catch {
      window.turnstile?.reset();
      setFeedback({
        kind: "error",
        field: "request",
        message:
          "Non è stato possibile registrare la richiesta. Riprova tra poco.",
      });
    }
  }

  return (
    <form
      className="waitlist"
      data-state={feedback.kind}
      onSubmit={handleSubmit}
      noValidate
      aria-label="Avviso lancio PLANETS"
    >
      <p className="waitlist__email-label" aria-hidden="true">
        La tua email
      </p>
      <label className="visually-hidden" htmlFor="launch-email">
        La tua email
      </label>
      <div className="waitlist__controls">
        <input
          id="launch-email"
          name="email"
          type="email"
          inputMode="email"
          autoComplete="email"
          placeholder="nome@esempio.it"
          value={email}
          onChange={(event) => {
            setEmail(event.currentTarget.value);
            clearFailure();
          }}
          aria-describedby="waitlist-purpose waitlist-feedback"
          aria-invalid={feedback.field === "email"}
          disabled={controlsDisabled}
          required
        />
        <button type="submit" disabled={controlsDisabled || !turnstileSiteKey}>
          {isSubmitting
            ? "Invio…"
            : isComplete
              ? "Richiesta registrata"
              : "Avvisami"}
        </button>
      </div>

      <label className="waitlist__consent" htmlFor="launch-consent">
        <input
          id="launch-consent"
          name="consent"
          type="checkbox"
          checked={consent}
          onChange={(event) => {
            setConsent(event.currentTarget.checked);
            clearFailure();
          }}
          aria-describedby="waitlist-purpose waitlist-feedback"
          aria-invalid={feedback.field === "consent"}
          disabled={controlsDisabled}
          required
        />
        <span>
          Voglio ricevere una sola email quando PLANETS sarà disponibile.
        </span>
      </label>

      <p className="waitlist__purpose" id="waitlist-purpose">
        Ti invieremo una sola email quando PLANETS sarà disponibile. Il tuo
        indirizzo non verrà usato per newsletter, pubblicità, promozioni o altre
        comunicazioni. <a href="#privacy">Leggi l'informativa privacy</a>.
      </p>

      {turnstileSiteKey ? (
        <TurnstileWidget
          siteKey={turnstileSiteKey}
          onError={showTurnstileFailure}
          onSuccess={clearTurnstileFailure}
        />
      ) : (
        <p className="waitlist__configuration" role="alert">
          La lista di attesa non è configurata in questo ambiente.
        </p>
      )}

      <p
        className="waitlist__feedback"
        id="waitlist-feedback"
        role={feedback.kind === "error" ? "alert" : "status"}
        aria-atomic="true"
      >
        {feedback.message}
      </p>
    </form>
  );
}
