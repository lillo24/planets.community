import { PUBLIC_CONTACT_EMAIL } from "../site-content";
import policyContent from "./content.json";

import { POLICY_VERSION, POLICY_STATUS, policyLinks } from "./metadata";

function escape(value: string) {
  return value.replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ]!,
  );
}

export function renderPolicy(path: string): string {
  const document = policyContent.find((entry) => entry.path === path);
  if (!document) throw new Error(`Unknown policy path: ${path}`);
  const nav = policyLinks
    .map(([title, href]) => `<a href="${href}">${escape(title)}</a>`)
    .join(" ");
  const mail = `mailto:${PUBLIC_CONTACT_EMAIL}?subject=${encodeURIComponent("PLANETS — Richiesta eliminazione account")}&body=${encodeURIComponent("Chiedo l’eliminazione del mio account PLANETS e dei dati personali associati.")}`;
  return `<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape(document.title)} | PLANETS</title><link rel="icon" href="/brand/planets-logo.png"><style>
  :root{color:#18302e;background:#fbfaf6;font-family:"Avenir Next","Segoe UI",system-ui,sans-serif;line-height:1.65;color-scheme:light}*{box-sizing:border-box}body{margin:0}header,main,footer{max-width:52rem;margin:auto;padding:1.5rem}a{color:#086b7d;overflow-wrap:anywhere}a:focus-visible{outline:3px solid #086b7d;outline-offset:4px}nav{display:flex;flex-wrap:wrap;gap:1rem}h1{font-size:clamp(1.7rem,5vw,2.5rem);line-height:1.2}h2{font-size:1.25rem;line-height:1.4;margin-top:2rem}p{overflow-wrap:anywhere}.status{border-left:5px solid #efb953;background:#f4f2eb;padding:1rem}.action{display:inline-block;padding:.75rem 1rem;border:2px solid #086b7d;border-radius:.5rem}footer{border-top:1px solid #536563}.skip{position:absolute;left:-9999px}.skip:focus{left:1rem;top:1rem;background:white;padding:1rem}
  </style></head><body><a class="skip" href="#contenuto">Vai al contenuto</a><header><a href="/">PLANETS — Torna al sito informativo</a></header><main id="contenuto"><h1>${escape(document.title)}</h1><aside class="status" aria-label="Stato del documento"><strong>${POLICY_STATUS}</strong><p>Versione del pacchetto Termini/Regole: ${POLICY_VERSION}. Test iniziale in Italia.</p><p>Questa è la bozza corrente richiesta per il test, con proposte e aspetti ancora da verificare. Non è una policy definitiva o una dichiarazione di validazione legale. Non è stata stabilita una decorrenza definitiva.</p></aside>
  ${path === "/delete-account" ? `<p><a class="action" href="${mail}">Apri email per richiedere l’eliminazione</a></p><p>Destinatario: <a href="mailto:${PUBLIC_CONTACT_EMAIL}">${PUBLIC_CONTACT_EMAIL}</a></p><p>Oggetto: <strong>PLANETS — Richiesta eliminazione account</strong></p>` : ""}
  <nav aria-label="Indice del documento">${document.sections.map((section, i) => `<a href="#sezione-${i + 1}">${escape(section.title)}</a>`).join(" ")}</nav>
  ${document.sections.map((section, i) => `<section aria-labelledby="sezione-${i + 1}"><h2 id="sezione-${i + 1}">${escape(section.title)}</h2>${section.paragraphs.map((p) => `<p>${escape(p)}</p>`).join("")}</section>`).join("")}
  <p>Assistenza, privacy e sicurezza: <a href="mailto:${PUBLIC_CONTACT_EMAIL}">${PUBLIC_CONTACT_EMAIL}</a>.</p></main><footer><nav aria-label="Documenti PLANETS">${nav}<a href="/">Sito informativo</a><a href="/#privacy">Privacy della lista d’attesa</a></nav></footer></body></html>`;
}
