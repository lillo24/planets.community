// @vitest-environment jsdom

import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { App } from "./App";
import { WaitlistForm } from "./WaitlistForm";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
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

  it("shows an accessible error for an invalid email address", () => {
    render(<WaitlistForm />);

    fireEvent.change(screen.getByLabelText("La tua email"), {
      target: { value: "indirizzo-non-valido" },
    });
    fireEvent.submit(
      screen.getByRole("form", { name: "Sapere quando parte." }),
    );

    expect(screen.getByRole("alert").textContent).toContain(
      "Inserisci un indirizzo email valido.",
    );
  });

  it("does not transmit or claim to save a valid preview address", () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);
    render(<WaitlistForm />);

    fireEvent.change(screen.getByLabelText("La tua email"), {
      target: { value: "persona@example.com" },
    });
    fireEvent.submit(
      screen.getByRole("form", { name: "Sapere quando parte." }),
    );

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(screen.getByRole("status").textContent).toContain(
      "non è stato inviato né salvato",
    );
  });
});
