// @vitest-environment jsdom

import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { WaitlistForm } from "./WaitlistForm";

const testSiteKey = "1x00000000000000000000AA";

function renderProgressiveWaitlist(
  apiClient = vi.fn().mockResolvedValue(undefined),
) {
  render(<WaitlistForm apiClient={apiClient} turnstileSiteKey={testSiteKey} />);
  const form = screen.getByRole("form", { name: "Avviso lancio PLANETS" });
  return { apiClient, form };
}

function enterReadySubmission() {
  fireEvent.change(screen.getByLabelText("La tua email"), {
    target: { value: "persona@example.com" },
  });
  fireEvent.click(screen.getByRole("checkbox"));
}

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  Reflect.deleteProperty(window, "turnstile");
  Reflect.deleteProperty(window, "planetsTurnstileError");
  Reflect.deleteProperty(window, "planetsTurnstileSuccess");
});

describe("progressive waitlist verification", () => {
  it("keeps the email label accessible without rendering visible label copy", () => {
    renderProgressiveWaitlist();

    expect(screen.getByLabelText("La tua email")).not.toBeNull();
    expect(document.querySelector(".waitlist__email-label")).toBeNull();
  });

  it("keeps the privacy promise and link on the consent row without a second paragraph", () => {
    renderProgressiveWaitlist();

    const consent = document.querySelector(".waitlist__consent");
    expect(consent?.textContent).toContain("Non invieremo più di un'email");
    expect(consent?.textContent).toContain(
      "il tuo indirizzo non verrà usato in nessun altro modo",
    );
    expect(consent?.querySelector('a[href="#privacy"]')?.textContent).toBe(
      "Informativa privacy",
    );
    expect(document.querySelector(".waitlist__purpose")).toBeNull();
  });

  it("reveals Turnstile only after Avvisami and submits automatically after verification", async () => {
    const { apiClient, form } = renderProgressiveWaitlist();
    enterReadySubmission();

    expect(document.querySelector(".waitlist__turnstile-reveal")).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "Avvisami" }));

    expect(
      document.querySelector(".waitlist__turnstile-reveal"),
    ).not.toBeNull();
    expect(apiClient).not.toHaveBeenCalled();

    const token = document.createElement("input");
    token.type = "hidden";
    token.name = "cf-turnstile-response";
    token.value = "verified-token";
    form.append(token);

    act(() => window.planetsTurnstileSuccess?.());

    await waitFor(() => {
      expect(apiClient).toHaveBeenCalledWith({
        email: "persona@example.com",
        consent: true,
        turnstileToken: "verified-token",
      });
    });

    expect(await screen.findByText("Sent!")).not.toBeNull();
    expect(document.querySelector(".waitlist__turnstile-reveal")).toBeNull();
  });
});
