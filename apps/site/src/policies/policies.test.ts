// @vitest-environment jsdom
import { describe, expect, it } from "vitest";
import { renderPolicy } from "./render";
import { policyLinks, POLICY_VERSION, POLICY_STATUS } from "./metadata";
import { readFileSync } from "node:fs";

describe("public policy HTML", () => {
  it.each(policyLinks)(
    "renders %s at %s without login, scripts or forms",
    (title, path) => {
      const html = renderPolicy(path);
      const doc = new DOMParser().parseFromString(html, "text/html");
      expect(doc.title).toContain("PLANETS");
      expect(doc.querySelector("h1")?.textContent).toContain(
        path === "/delete-account" ? "Richiesta eliminazione account" : title,
      );
      expect(doc.body.textContent).toContain(POLICY_VERSION);
      expect(doc.body.textContent).toContain(POLICY_STATUS);
      expect(doc.querySelectorAll("h2").length).toBeGreaterThan(3);
      expect(doc.querySelector("script, form, input, iframe")).toBeNull();
      for (const [, href] of policyLinks)
        expect(doc.querySelector(`a[href="${href}"]`)).not.toBeNull();
      expect(doc.querySelector('a[href="/"]')).not.toBeNull();
      expect(html).not.toMatch(
        /C8\.|CT-01|public\.profiles|auth\.users|\[DA |\[PROPOSTA|NOTA INTERNA/,
      );
    },
  );
  it("keeps unresolved retention/deletion and legal bases provisional", () => {
    const privacy = renderPolicy("/privacy");
    expect(privacy).toContain("proposte da validare");
    expect(privacy).toContain("non stabilisce una conservazione indefinita");
    expect(privacy).toContain("30 giorni");
    expect(privacy).toContain("non un termine garantito");
    expect(privacy).toContain("sul dispositivo");
    expect(privacy).toContain("La lista non viene attivata");
  });
  it("provides a reviewed manual mailto and instructions without sign-in", () => {
    const doc = new DOMParser().parseFromString(
      renderPolicy("/delete-account"),
      "text/html",
    );
    const action = doc.querySelector<HTMLAnchorElement>("a.action")!;
    const uri = new URL(action.href);
    expect(uri.pathname).toBe("developer.planets.community@gmail.com");
    expect(uri.searchParams.get("subject")).toBe(
      "PLANETS — Richiesta eliminazione account",
    );
    expect(uri.searchParams.get("body")).toContain("dati personali associati");
    expect(doc.body.textContent).toContain("senza reinstallare");
    expect(doc.body.textContent).toContain("Leonardo Colli");
    expect(doc.body.textContent).toContain(
      "non invia, registra, traccia o completa automaticamente",
    );
  });
  it("pins the same mobile Terms/Rules bundle version", () => {
    const dart = readFileSync(
      "../mobile/lib/features/policies/application/policy_documents.dart",
      "utf8",
    );
    expect(dart).toContain(`const policyBundleVersion = '${POLICY_VERSION}'`);
  });
});
