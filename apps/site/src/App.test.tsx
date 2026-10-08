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

  const form = screen.getByRole("form", { name: "Avviso lancio PLANETS" });
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
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  Reflect.deleteProperty(window, "turnstile");
});

describe("PLANETS public site", () => {
  it("renders the compact public navigation and approved contact links", () => {
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
    const contacts = screen.getByRole("region", { name: "Contatti" });
    expect(
      within(contacts)
        .getByRole("link", { name: "developer.planets.community@gmail.com" })
        .getAttribute("href"),
    ).toBe("mailto:developer.planets.community@gmail.com");
    expect(
      within(contacts)
        .getByRole("link", { name: "+39 3703263412" })
        .getAttribute("href"),
    ).toBe("tel:+393703263412");
    expect(contacts.textContent).not.toContain(
      "Il contatto pubblico sarà aggiunto qui prima della messa online.",
    );
  });

  it("renders the corrected text container mapping and independent detail sections", () => {
    render(<App />);

    expect(document.querySelector(".hero__announcement")?.textContent).toBe(
      "In arrivo su iOS e Android",
    );
    expect(document.querySelector(".hero__lead")?.textContent?.trim()).toBe(
      "Un luogo per incontrarsi vicino a casa, unire capacità diverse e trasformare un'idea in un'attività concreta.",
    );
    expect(document.querySelector(".hero__support")).toBeNull();
    expect(document.querySelector(".hero__caption")).toBeNull();
    expect(
      document
        .querySelector(".about-copy > p:first-child")
        ?.textContent?.trim(),
    ).toBe(
      "PLANETS mette in contatto persone che vogliono creare qualcosa insieme nella propria comunità.",
    );
    expect(document.body.textContent).not.toContain(
      "PLANETS nasce per rendere più semplice incontrare persone vicine con cui trasformare un'idea in un'attività concreta.",
    );
    expect(document.querySelector(".about-note p")?.textContent).toBe(
      "Persone, idee e luoghi che si incontrano.",
    );
    expect(document.querySelector(".about-note")?.textContent).toContain(
      "Persone, idee e luoghi che si incontrano.",
    );
    expect(document.body.textContent).not.toContain(
      "Ogni persona porta qualcosa. PLANETS aiuta a trovare chi vuole metterlo in comune.",
    );

    const contactSection = document.querySelector("section#contatti");
    const privacySection = document.querySelector("section#privacy");

    expect(contactSection).not.toBeNull();
    expect(privacySection).not.toBeNull();
    expect(contactSection?.nextElementSibling).toBe(privacySection);
  });

  it("reveals the Base, Riflesso, Fluido, and Prisma controls after two quick footer-logo activations", () => {
    render(<App />);

    const announcements = document.querySelectorAll(".hero__announcement");
    const announcement = announcements.item(0);
    const developerTrigger = document.querySelector("[data-developer-trigger]");
    const footer = document.querySelector(".site-footer");
    const initialHash = window.location.hash;
    let now = 1_000;
    vi.spyOn(Date, "now").mockImplementation(() => now);

    expect(announcements).toHaveLength(1);
    expect(announcement.textContent).toBe("In arrivo su iOS e Android");
    expect(announcement.getAttribute("data-variant")).toBe("fluid");
    expect(announcement.classList.contains("hero__announcement--fluid")).toBe(
      true,
    );
    expect(
      screen.queryByRole("group", { name: "Effetto dell'annuncio" }),
    ).toBeNull();
    expect(developerTrigger?.getAttribute("aria-hidden")).toBe("true");
    expect(developerTrigger?.closest("a")).toBeNull();
    expect(
      within(footer as HTMLElement)
        .getByRole("link", { name: "PLANETS" })
        .getAttribute("href"),
    ).toBe("#inizio");

    fireEvent.pointerUp(developerTrigger as Element, { button: 0 });

    expect(
      screen.queryByRole("group", { name: "Effetto dell'annuncio" }),
    ).toBeNull();
    expect(announcement.getAttribute("data-variant")).toBe("fluid");
    expect(window.location.hash).toBe(initialHash);

    now = 1_499;
    fireEvent.pointerUp(developerTrigger as Element, { button: 0 });

    const toggle = screen.getByRole("group", {
      name: "Effetto dell'annuncio",
    });
    const baseButton = within(toggle).getByRole("button", { name: "Base" });
    const reflectionButton = within(toggle).getByRole("button", {
      name: "Riflesso",
    });
    const fluidButton = within(toggle).getByRole("button", {
      name: "Fluido",
    });
    const prismaButton = within(toggle).getByRole("button", {
      name: "Prisma",
    });

    expect(within(toggle).getAllByRole("button")).toEqual([
      baseButton,
      reflectionButton,
      fluidButton,
      prismaButton,
    ]);
    expect(
      document.querySelectorAll(".hero__announcement-toggle"),
    ).toHaveLength(1);
    expect(announcement.getAttribute("data-variant")).toBe("fluid");
    expect(baseButton.getAttribute("aria-pressed")).toBe("false");
    expect(reflectionButton.getAttribute("aria-pressed")).toBe("false");
    expect(fluidButton.getAttribute("aria-pressed")).toBe("true");
    expect(prismaButton.getAttribute("aria-pressed")).toBe("false");

    fireEvent.click(reflectionButton);

    expect(announcement.getAttribute("data-variant")).toBe("reflection");
    expect(
      announcement.classList.contains("hero__announcement--reflection"),
    ).toBe(true);
    expect(baseButton.getAttribute("aria-pressed")).toBe("false");
    expect(reflectionButton.getAttribute("aria-pressed")).toBe("true");

    fireEvent.click(fluidButton);

    expect(announcement.getAttribute("data-variant")).toBe("fluid");
    expect(
      announcement.classList.contains("hero__announcement--reflection"),
    ).toBe(false);
    expect(announcement.classList.contains("hero__announcement--fluid")).toBe(
      true,
    );
    expect(fluidButton.getAttribute("aria-pressed")).toBe("true");

    fireEvent.click(prismaButton);

    expect(announcement.getAttribute("data-variant")).toBe("prisma");
    expect(announcement.classList.contains("hero__announcement--fluid")).toBe(
      false,
    );
    expect(announcement.classList.contains("hero__announcement--prisma")).toBe(
      true,
    );
    expect(prismaButton.getAttribute("aria-pressed")).toBe("true");

    fireEvent.click(baseButton);

    expect(announcement.getAttribute("data-variant")).toBe("base");
    expect(announcement.classList.contains("hero__announcement--base")).toBe(
      true,
    );
    expect(announcement.classList.contains("hero__announcement--fluid")).toBe(
      false,
    );
    expect(announcement.classList.contains("hero__announcement--prisma")).toBe(
      false,
    );
    expect(baseButton.getAttribute("aria-pressed")).toBe("true");
  });

  it("renders three decorative orbits around one hero logo", () => {
    render(<App />);

    const heroVisual = document.querySelector(".hero__visual");
    const orbits = heroVisual?.querySelectorAll(".orbit");

    expect(orbits).toHaveLength(3);
    expect(heroVisual?.querySelector(".orbit--inner")).not.toBeNull();
    expect(heroVisual?.querySelector(".orbit--outer")).not.toBeNull();
    expect(heroVisual?.querySelector(".orbit--far")).not.toBeNull();
    expect(
      Array.from(orbits ?? []).every(
        (orbit) => orbit.getAttribute("aria-hidden") === "true",
      ),
    ).toBe(true);
    expect(heroVisual?.querySelectorAll(".hero__logo")).toHaveLength(1);
  });

  it("uses the PLANETS logo for both brand marks", () => {
    render(<App />);

    const headerBrand = screen.getByRole("link", {
      name: "PLANETS, torna all'inizio",
    });
    const logo = headerBrand.querySelector(".brand__mark img");

    expect(logo?.getAttribute("src")).toBe("/brand/planets-logo.png");
    expect(logo?.getAttribute("alt")).toBe("");
    expect(headerBrand.querySelector(".brand__dot")).toBeNull();

    const footer = document.querySelector(".site-footer");
    const footerBrand = footer?.querySelector(".brand--footer");
    const footerLogo = footerBrand?.querySelector(".brand__mark img");

    expect(footerLogo?.getAttribute("src")).toBe("/brand/planets-logo.png");
    expect(footerLogo?.getAttribute("alt")).toBe("");
    expect(document.querySelector(".brand__dot")).toBeNull();
  });

  it("keeps one accessible waitlist form after the visual on mobile", () => {
    render(<App />);

    const forms = screen.getAllByRole("form", {
      name: "Avviso lancio PLANETS",
    });
    const email = screen.getByLabelText("La tua email");
    const emailLabel = document.querySelector('label[for="launch-email"]');
    const heroBody = document.querySelector(".hero__body");

    expect(forms).toHaveLength(1);
    expect(document.querySelectorAll("#launch-email")).toHaveLength(1);
    expect(email.getAttribute("placeholder")).toBe("nome@esempio.it");
    expect(emailLabel?.classList.contains("visually-hidden")).toBe(true);
    expect(forms[0].getAttribute("aria-label")).toBe("Avviso lancio PLANETS");
    expect(forms[0].hasAttribute("aria-labelledby")).toBe(false);
    expect(document.querySelector("#waitlist-title")).toBeNull();
    expect(screen.queryByText("Lista di attesa")).toBeNull();
    expect(screen.queryByText("Sapere quando parte.")).toBeNull();
    expect(
      Array.from(heroBody?.children ?? []).map(({ className }) => className),
    ).toEqual(["hero__content", "hero__visual", "waitlist"]);
  });

  it("omits the environment warning when Turnstile is configured", () => {
    const { form } = renderWaitlist();

    const turnstile = form.querySelector(".cf-turnstile.waitlist__turnstile");
    const feedback = form.querySelector("#waitlist-feedback");

    expect(turnstile).not.toBeNull();
    expect(turnstile?.getAttribute("data-action")).toBe("waitlist_signup");
    expect(feedback?.getAttribute("role")).toBe("status");
    expect(feedback?.textContent).toBe("");

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
