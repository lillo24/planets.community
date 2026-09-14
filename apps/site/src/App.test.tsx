// @vitest-environment jsdom

import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { App } from "./App";
import { WaitlistForm } from "./WaitlistForm";

const testSiteKey = "1x00000000000000000000AA";

function renderWaitlist(apiClient = vi.fn().mockResolvedValue(undefined)) {
  render(<WaitlistForm apiClient={apiClient} turnstileSiteKey={testSiteKey} />);

  const form = screen.getByRole("form", { name: "Sapere quando parte." });
  const token = document.createElement("input");
  token.type = "hidden";
  token.name = "cf-turnstile-response";
  token.value = "test-turnstile-token";
  form.append(token);

  return { apiClient, form };
}

function enterValidSubmission() {
  fireEvent.change(screen.getByLabelText("La tua email"), {
    target: { value: " persona@example.com " },
  });
  fireEvent.click(
    screen.getByLabelText(
      "Voglio ricevere una sola email quando PLANETS sarà disponibile.",
    ),
  );
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  Reflect.deleteProperty(window, "turnstile");
});

describe("PLANETS public site", () => {
  it("renders the compact public navigation without inventing a contact address", () => {
    render(<App />);

    const navigation = screen.getByRole("navigation", {
      name: "Navigazione principale",
    });
    const destinations = within(navigation)
      .getAllByRole("link")
      .map((link) => link.getAttribute("href"));

    expect(destinations).toEqual([
      "#inizio",
      "#chi-siamo",
      "#contatti",
      "#privacy",
    ]);
    expect(document.querySelector('a[href^="mailto:"]')).toBeNull();
  });

  it("renders the founder-reviewed copy and independent detail sections", () => {
    render(<App />);

    expect(document.querySelector(".hero__announcement")?.textContent).toBe(
      "In arrivo su iOS e Android",
    );
    expect(document.querySelector(".hero__lead")?.textContent).toContain(
      "Persone, idee e luoghi che si incontrano.",
    );
    expect(document.querySelector(".hero__support")?.textContent).toContain(
      "PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.",
    );
    expect(document.querySelector(".hero__caption")?.textContent).toContain(
      "Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.",
    );
    expect(
      screen.queryByText(
        "Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.",
      ),
    ).toBeNull();
    expect(document.querySelector(".about-note")).toBeNull();

    const contactSection = document.querySelector("section#contatti");
    const privacySection = document.querySelector("section#privacy");

    expect(contactSection).not.toBeNull();
    expect(privacySection).not.toBeNull();
    expect(contactSection?.nextElementSibling).toBe(privacySection);
  });

  it("uses the PLANETS logo as the accessible header brand mark", () => {
    render(<App />);

    const headerBrand = screen.getByRole("link", {
      name: "PLANETS, torna all'inizio",
    });
    const logo = headerBrand.querySelector(".brand__mark img");

    expect(logo?.getAttribute("src")).toBe("/brand/planets-logo.png");
    expect(logo?.getAttribute("alt")).toBe("");
    expect(headerBrand.querySelector(".brand__dot")).toBeNull();
  });

  it("omits the environment warning when Turnstile is configured", () => {
    renderWaitlist();

    expect(
      screen.queryByText(
        "La lista di attesa non è configurata in questo ambiente.",
      ),
    ).toBeNull();
  });

  it("keeps the environment warning when Turnstile is unconfigured", () => {
    render(<WaitlistForm turnstileSiteKey={null} />);

    expect(
      screen.getByText(
        "La lista di attesa non è configurata in questo ambiente.",
      ),
    ).not.toBeNull();
  });

  it("does not submit an invalid email address", () => {
    const { apiClient, form } = renderWaitlist();

    fireEvent.change(screen.getByLabelText("La tua email"), {
      target: { value: "indirizzo-non-valido" },
    });
    fireEvent.submit(form);

    expect(screen.getByRole("alert").textContent).toContain(
      "Inserisci un indirizzo email valido.",
    );
    expect(apiClient).not.toHaveBeenCalled();
  });

  it("requires unchecked affirmative consent before submission", () => {
    const { apiClient, form } = renderWaitlist();

    fireEvent.change(screen.getByLabelText("La tua email"), {
      target: { value: "persona@example.com" },
    });
    fireEvent.submit(form);

    expect(screen.getByRole("alert").textContent).toContain(
      "Conferma di voler ricevere la sola email di lancio.",
    );
    expect(apiClient).not.toHaveBeenCalled();
  });

  it("sends valid input to the waitlist API boundary", async () => {
    const { apiClient, form } = renderWaitlist();
    enterValidSubmission();

    fireEvent.submit(form);

    await waitFor(() => {
      expect(apiClient).toHaveBeenCalledWith({
        email: "persona@example.com",
        consent: true,
        turnstileToken: "test-turnstile-token",
      });
    });
  });

  it("keeps controls disabled while the request is submitting", async () => {
    let resolveRequest: (() => void) | undefined;
    const apiClient = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveRequest = resolve;
        }),
    );
    const { form } = renderWaitlist(apiClient);
    enterValidSubmission();

    fireEvent.submit(form);

    expect(
      (screen.getByRole("button", { name: "Invio…" }) as HTMLButtonElement)
        .disabled,
    ).toBe(true);
    expect(
      (screen.getByLabelText("La tua email") as HTMLInputElement).disabled,
    ).toBe(true);

    resolveRequest?.();
    await screen.findByText(
      "Perfetto. Ti avviseremo una sola volta quando PLANETS sarà disponibile.",
    );
  });

  it("shows an accurate terminal success state", async () => {
    const { form } = renderWaitlist();
    enterValidSubmission();

    fireEvent.submit(form);

    expect(
      await screen.findByText(
        "Perfetto. Ti avviseremo una sola volta quando PLANETS sarà disponibile.",
      ),
    ).not.toBeNull();
    expect(
      (screen.getByLabelText("La tua email") as HTMLInputElement).value,
    ).toBe("");
    expect(
      (
        screen.getByRole("button", {
          name: "Richiesta registrata",
        }) as HTMLButtonElement
      ).disabled,
    ).toBe(true);

    act(() => window.planetsTurnstileError?.());
    expect(
      screen.getByText(
        "Perfetto. Ti avviseremo una sola volta quando PLANETS sarà disponibile.",
      ),
    ).not.toBeNull();
  });

  it("keeps a server or network failure visibly failed and retryable", async () => {
    const reset = vi.fn();
    window.turnstile = { reset };
    const apiClient = vi.fn().mockRejectedValue(new Error("network failed"));
    const { form } = renderWaitlist(apiClient);
    enterValidSubmission();

    fireEvent.submit(form);

    expect(
      await screen.findByText(
        "Non è stato possibile registrare la richiesta. Riprova tra poco.",
      ),
    ).not.toBeNull();
    expect(
      (screen.getByRole("button", { name: "Avvisami" }) as HTMLButtonElement)
        .disabled,
    ).toBe(false);
    expect(reset).toHaveBeenCalledOnce();
  });

  it("surfaces a Turnstile widget failure and clears it after recovery", () => {
    renderWaitlist();

    act(() => window.planetsTurnstileError?.());

    expect(screen.getByRole("alert").textContent).toContain(
      "La verifica anti-abuso non è riuscita.",
    );

    act(() => window.planetsTurnstileSuccess?.());

    expect(
      screen.queryByText(/La verifica anti-abuso non è riuscita/u),
    ).toBeNull();
  });
});
