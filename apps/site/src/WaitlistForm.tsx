import {
  type FormEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";

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
const accessibleConsentLabel =
  "Voglio ricevere una sola email quando PLANETS sarà disponibile.";

function readTurnstileToken(form: HTMLFormElement) {
  const token = new FormData(form).get("cf-turnstile-response");
  return typeof token === "string" ? token : "";
}

export function WaitlistForm({
  apiClient = submitWaitlist,
  turnstileSiteKey = WAITLIST_TURNSTILE_SITE_KEY,
}: WaitlistFormProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const [email, setEmail] = useState("");
  const [consent, setConsent] = useState(false);
  const [verificationRequested, setVerificationRequested] = useState(false);
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

  const handleTurnstileSuccess = useCallback(() => {
    setFeedback((current) =>
      current.kind === "error" && current.field === "turnstile"
        ? idleFeedback
        : current,
    );

    if (!verificationRequested) {
      return;
    }

    window.setTimeout(() => {
      formRef.current?.requestSubmit();
    }, 0);
  }, [verificationRequested]);

  useEffect(() => {
    window.planetsTurnstileError = showTurnstileFailure;
    window.planetsTurnstileSuccess = handleTurnstileSuccess;

    return () => {
      delete window.planetsTurnstileError;
      delete window.planetsTurnstileSuccess;
    };
  }, [handleTurnstileSuccess, showTurnstileFailure]);

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

    if (!turnstileSiteKey) {
      setFeedback({
        kind: "error",
        field: "turnstile",
        message: "La verifica anti-abuso non è disponibile in questo ambiente.",
      });
      return;
    }

    const turnstileToken = readTurnstileToken(event.currentTarget);
    if (turnstileToken.length === 0) {
      setVerificationRequested(true);
      setFeedback(idleFeedback);
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
      setVerificationRequested(false);
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
      ref={formRef}
      className="waitlist"
      data-state={feedback.kind}
      data-verification={verificationRequested ? "requested" : "idle"}
      onSubmit={handleSubmit}
      noValidate
      aria-label="Avviso lancio PLANETS"
    >
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
          aria-describedby="waitlist-feedback"
          aria-invalid={feedback.field === "email"}
          disabled={controlsDisabled}
          required
        />
        <button
          type="submit"
          aria-label={isComplete ? "Richiesta registrata" : undefined}
          disabled={controlsDisabled || !turnstileSiteKey}
        >
          {isSubmitting ? "Invio…" : isComplete ? "Sent!" : "Avvisami"}
        </button>
      </div>

      <div className="waitlist__consent">
        <input
          id="launch-consent"
          name="consent"
          type="checkbox"
          aria-label={accessibleConsentLabel}
          checked={consent}
          onChange={(event) => {
            setConsent(event.currentTarget.checked);
            clearFailure();
          }}
          aria-describedby="waitlist-feedback"
          aria-invalid={feedback.field === "consent"}
          disabled={controlsDisabled}
          required
        />
        <span>
          <label htmlFor="launch-consent">
            Non invieremo più di un'email e il tuo indirizzo non verrà usato in
            nessun altro modo.
          </label>{" "}
          <a href="#privacy">Informativa privacy</a>
        </span>
      </div>

      {turnstileSiteKey ? (
        verificationRequested ? (
          <div className="waitlist__turnstile-reveal">
            <TurnstileWidget
              siteKey={turnstileSiteKey}
              onError={showTurnstileFailure}
              onSuccess={handleTurnstileSuccess}
            />
          </div>
        ) : isComplete ? null : (
          <div
            className="cf-turnstile waitlist__turnstile"
            data-action="waitlist_signup"
            aria-hidden="true"
            hidden
            style={{ display: "none" }}
          />
        )
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
