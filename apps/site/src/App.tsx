import { type PointerEvent, useRef, useState } from "react";

import { PUBLIC_CONTACT_EMAIL } from "./site-content";
import { WaitlistForm } from "./WaitlistForm";

const activityExamples = [
  ["Creare", "Dare forma a un'idea condivisa."],
  ["Coltivare", "Prendersi cura di uno spazio comune."],
  ["Costruire", "Mettere insieme capacità e materiali."],
  ["Organizzare", "Far incontrare persone e iniziative."],
] as const;

const primaryNavigation = [
  ["Home", "#inizio"],
  ["Chi siamo", "#chi-siamo"],
  ["Contatti", "#contatti"],
  ["Privacy", "#privacy"],
] as const;

type AnnouncementVariant = "base" | "reflection" | "fluid";

const developerRevealWindowMs = 500;
const announcementVariants = [
  ["base", "Base"],
  ["reflection", "Riflesso"],
  ["fluid", "Fluido"],
] as const satisfies ReadonlyArray<readonly [AnnouncementVariant, string]>;

function AnnouncementExperiment({ isVisible }: { isVisible: boolean }) {
  const [variant, setVariant] = useState<AnnouncementVariant>("base");

  return (
    <div className="hero__announcement-experiment">
      <p
        className={`hero__announcement hero__announcement--${variant}`}
        data-variant={variant}
      >
        <span>In arrivo su iOS e Android</span>
      </p>

      {isVisible ? (
        <div
          className="hero__announcement-toggle"
          role="group"
          aria-label="Effetto dell'annuncio"
        >
          {announcementVariants.map(([value, label]) => (
            <button
              key={value}
              type="button"
              aria-pressed={variant === value}
              onClick={() => setVariant(value)}
            >
              {label}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function App() {
  const [isAnnouncementExperimentVisible, setAnnouncementExperimentVisible] =
    useState(false);
  const lastDeveloperActivation = useRef<number | null>(null);

  function handleDeveloperActivation(event: PointerEvent<HTMLSpanElement>) {
    if (event.button !== 0 || isAnnouncementExperimentVisible) {
      return;
    }

    const now = Date.now();
    const elapsed =
      lastDeveloperActivation.current === null
        ? null
        : now - lastDeveloperActivation.current;

    if (
      elapsed !== null &&
      elapsed >= 0 &&
      elapsed <= developerRevealWindowMs
    ) {
      lastDeveloperActivation.current = null;
      setAnnouncementExperimentVisible(true);
      return;
    }

    lastDeveloperActivation.current = now;
  }

  return (
    <div className="site-page">
      <a className="skip-link" href="#contenuto">
        Vai al contenuto
      </a>

      <header className="site-header">
        <div className="site-header__inner">
          <a
            className="brand"
            href="#inizio"
            aria-label="PLANETS, torna all'inizio"
          >
            <span className="brand__mark" aria-hidden="true">
              <img
                src="/brand/planets-logo.png"
                alt=""
                width="1080"
                height="1150"
              />
            </span>
            <span>PLANETS</span>
          </a>

          <nav className="primary-nav" aria-label="Navigazione principale">
            {primaryNavigation.map(([label, href]) => (
              <a href={href} key={href}>
                {label}
              </a>
            ))}
          </nav>
        </div>
      </header>

      <main id="contenuto">
        <section className="hero" id="inizio" aria-labelledby="hero-title">
          <AnnouncementExperiment isVisible={isAnnouncementExperimentVisible} />

          <div className="hero__body">
            <div className="hero__content">
              <h1 id="hero-title">
                Le idee prendono vita, <em>insieme.</em>
              </h1>
              <p className="hero__lead">
                Un luogo per incontrarsi vicino a casa, unire capacità diverse e
                trasformare un'idea in un'attività concreta.
              </p>
            </div>

            <div className="hero__visual" aria-label="Identità visiva PLANETS">
              <span className="orbit orbit--far" aria-hidden="true" />
              <span className="orbit orbit--outer" aria-hidden="true" />
              <span className="orbit orbit--inner" aria-hidden="true" />
              <div className="logo-stage">
                <img
                  className="hero__logo"
                  src="/brand/planets-logo.png"
                  alt="Logo PLANETS, simbolo multicolore della comunità"
                  width="1080"
                  height="1150"
                  fetchPriority="high"
                />
              </div>
            </div>

            <WaitlistForm />
          </div>
        </section>

        <section className="activity-strip" aria-label="Esempi di attività">
          <ul>
            {activityExamples.map(([title, description], index) => (
              <li key={title}>
                <span
                  className={`activity-strip__number activity-strip__number--${index + 1}`}
                >
                  0{index + 1}
                </span>
                <span>
                  <strong>{title}</strong>
                  {description}
                </span>
              </li>
            ))}
          </ul>
        </section>

        <section
          className="section section--about"
          id="chi-siamo"
          aria-labelledby="about-title"
        >
          <div className="section__heading">
            <p className="eyebrow">Chi siamo</p>
            <h2 id="about-title">Una comunità comincia da un incontro.</h2>
          </div>

          <div className="about-copy">
            <p>
              PLANETS mette in contatto persone che vogliono creare qualcosa
              insieme nella propria comunità.
            </p>
            <p>
              La piattaforma è pensata per progetti e incontri collaborativi
              locali: creare, costruire, coltivare, organizzare e contribuire
              insieme alla comunità.
            </p>
            <aside className="about-note" aria-label="Il principio di PLANETS">
              <span aria-hidden="true">✦</span>
              <p>Persone, idee e luoghi che si incontrano.</p>
            </aside>
          </div>
        </section>

        <section
          className="section section--detail section--contact"
          id="contatti"
          aria-labelledby="contact-title"
        >
          <article className="detail-card">
            <p className="eyebrow">Parliamone</p>
            <h2 id="contact-title">Contatti</h2>
            <p>Per informazioni o domande su PLANETS.</p>
            {PUBLIC_CONTACT_EMAIL ? (
              <a
                className="contact-link"
                href={`mailto:${PUBLIC_CONTACT_EMAIL}`}
              >
                {PUBLIC_CONTACT_EMAIL}
              </a>
            ) : (
              <p className="content-pending">
                Il contatto pubblico sarà aggiunto qui prima della messa online.
              </p>
            )}
          </article>
        </section>

        <section
          className="section section--detail section--privacy"
          id="privacy"
          aria-labelledby="privacy-title"
        >
          <article className="detail-card detail-card--privacy">
            <p className="eyebrow">Privacy, in breve</p>
            <h2 id="privacy-title">Una sola email, per un solo scopo.</h2>
            <p>
              Quando invii il modulo, chiediamo il tuo indirizzo solo per
              avvisarti una volta quando PLANETS sarà disponibile.
            </p>
            <ul>
              <li>Non è un'iscrizione a una newsletter.</li>
              <li>
                L'indirizzo non sarà usato per pubblicità, promozioni,
                aggiornamenti ricorrenti o comunicazioni estranee al lancio.
              </li>
              <li>
                Prima dell'invio potrai chiederne la rimozione tramite il
                contatto privacy che verrà pubblicato prima dell'attivazione.
              </li>
            </ul>
            <p className="privacy-preview">
              Il consenso è facoltativo e specifico per questa unica notifica. I
              dati del titolare e il contatto privacy saranno completati prima
              della pubblicazione; fino ad allora la lista resta disponibile
              solo negli ambienti locali e di test.
            </p>
          </article>
        </section>
      </main>

      <footer className="site-footer">
        <div className="site-footer__inner">
          <div>
            <div className="brand brand--footer">
              <span
                className="brand__mark brand__developer-trigger"
                data-developer-trigger=""
                aria-hidden="true"
                onPointerUp={handleDeveloperActivation}
              >
                <img
                  src="/brand/planets-logo.png"
                  alt=""
                  width="1080"
                  height="1150"
                />
              </span>
              <a className="brand__home-link" href="#inizio">
                PLANETS
              </a>
            </div>
            <p>iOS e Android — prossimamente</p>
          </div>

          <nav aria-label="Navigazione a piè di pagina">
            {primaryNavigation.slice(1).map(([label, href]) => (
              <a href={href} key={href}>
                {label}
              </a>
            ))}
          </nav>
        </div>
      </footer>
    </div>
  );
}
