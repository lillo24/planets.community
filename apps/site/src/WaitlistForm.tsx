import { type FormEvent, useState } from "react";

import { validateEmailAddress } from "./email-validation";

type Feedback =
  | { kind: "idle"; message: "" }
  | { kind: "error"; message: string }
  | { kind: "preview"; message: string };

const idleFeedback: Feedback = { kind: "idle", message: "" };

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [feedback, setFeedback] = useState<Feedback>(idleFeedback);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!validateEmailAddress(email)) {
      setFeedback({
        kind: "error",
        message: "Inserisci un indirizzo email valido.",
      });
      return;
    }

    setFeedback({
      kind: "preview",
      message:
        "La lista di attesa non è ancora attiva: il tuo indirizzo non è stato inviato né salvato.",
    });
  }

  return (
    <form
      className="waitlist"
      data-state={feedback.kind}
      onSubmit={handleSubmit}
      noValidate
      aria-labelledby="waitlist-title"
    >
      <div className="waitlist__heading">
        <p className="waitlist__kicker">Lista di attesa — anteprima</p>
        <h2 id="waitlist-title">Sapere quando parte.</h2>
      </div>

      <label htmlFor="launch-email">La tua email</label>
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
            if (feedback.kind !== "idle") {
              setFeedback(idleFeedback);
            }
          }}
          aria-describedby="waitlist-purpose waitlist-feedback"
          aria-invalid={feedback.kind === "error"}
          required
        />
        <button type="submit">Avvisami</button>
      </div>

      <p className="waitlist__purpose" id="waitlist-purpose">
        Ti invieremo una sola email quando PLANETS sarà disponibile. Il tuo
        indirizzo non verrà usato per newsletter, pubblicità, promozioni o altre
        comunicazioni. <a href="#privacy">Leggi l'informativa privacy</a>.
      </p>

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
