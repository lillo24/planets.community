import { readFile } from "node:fs/promises";
import path from "node:path";

import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

import { signInLocalOtpUser } from "./local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./local-profile-photo.mjs";
import {
  ensureDemoInvitation,
  exerciseDemoInvitationTransitions,
  seedDemoParticipantInvitations,
  verifyDemoParticipantInvitations,
} from "./demo-participant-invitations.mjs";

const DEMO_LOCK_ID = 684026240991817n;
const COVER_BUCKET = "cover-images";
const TRENTO_ADMINISTRATIVE_AREA = "Provincia autonoma di Trento";
const LEGACY_CHAT_BODIES = deepFreeze([
  "Welcome! I will bring the sketch and washable markers.",
  "Great — I can photograph the wall and help with the color plan.",
  "Perfect. We will confirm materials here before the meetup.",
]);

export const DEMO_PERSONAS = deepFreeze({
  alice: {
    photoState: "present",
    email: "demo-alice@planets.invalid",
    displayName: "Giulia",
    bio: "Mi piace trasformare idee di quartiere in progetti semplici da fare insieme.",
    skillSlugs: ["event-organization", "facilitation", "mural-painting"],
    profileAsset: "giulia.webp",
    profileVersion: "d0100000-0000-4000-8000-000000000001",
  },
  bob: {
    photoState: "present",
    email: "demo-bob@planets.invalid",
    displayName: "Marco",
    bio: "Mi piace aggiustare cose, lavorare con il legno e dare una mano nei progetti pratici.",
    skillSlugs: ["basic-repairs", "programming", "woodworking"],
    profileAsset: "marco.webp",
    profileVersion: "d0100000-0000-4000-8000-000000000002",
  },
  carla: {
    photoState: "present",
    email: "demo-carla@planets.invalid",
    displayName: "Sara",
    bio: "Fotografia, musica e attività creative: soprattutto quando diventano occasioni per conoscere persone.",
    skillSlugs: ["facilitation", "musician", "photography"],
    profileAsset: "sara.webp",
    profileVersion: "d0100000-0000-4000-8000-000000000003",
  },
  dario: {
    email: "demo-dario@planets.invalid",
    displayName: "Dario",
    bio: "Partecipo ai progetti di quartiere tramite un invito, senza una foto di profilo.",
    skillSlugs: ["basic-repairs"],
    photoState: "absent",
  },
  elena: {
    email: "demo-elena@planets.invalid",
    displayName: "Elena",
    bio: "Vorrei provare un progetto di quartiere: il mio primo Join resta una scelta esplicita.",
    skillSlugs: [],
    photoState: "absent",
  },
});

export const DEMO_SCENARIOS = deepFreeze({
  proposals: {
    mural: {
      key: "mural",
      ownerKey: "alice",
      legacyTitle: "DEMO · Riverside mural",
      title: "Coloriamo insieme il muro del sottopasso",
      summary:
        "Un pomeriggio per ridare colore al sottopasso con un murale progettato insieme.",
      description:
        "Partiamo da una bozza semplice, prepariamo il muro e poi dipingiamo insieme.\nNon serve essere illustratori: servono anche mani per nastro, colori, pulizia e foto.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Povo",
        exactMeetingText:
          "Cortile privato vicino a Povo — dettagli nel gruppo dei partecipanti",
        exactLocationVisibility: "participants",
      },
      coverAsset: "mural.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000001",
      skillSlugs: ["mural-painting", "event-organization"],
      skillImportances: ["required", "useful"],
    },
    repairCafe: {
      key: "repairCafe",
      ownerKey: "alice",
      legacyTitle: "DEMO · Repair café",
      title: "Repair Café: aggiustiamo piccoli oggetti insieme",
      summary:
        "Porta un piccolo oggetto da riparare oppure vieni a dare una mano al banco.",
      description:
        "Ci concentriamo su lampade, piccoli elettrodomestici e oggetti in legno che si possono controllare in sicurezza. Non è un servizio professionale: proviamo insieme a capire il problema e, quando possibile, a fare una piccola riparazione.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · San Martino",
        exactMeetingText: "Sala laboratorio del centro civico di San Martino",
        exactLocationVisibility: "public",
      },
      coverAsset: "repair-cafe.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000002",
      skillSlugs: ["basic-repairs", "woodworking"],
      skillImportances: ["required", "useful"],
    },
    participantWorkshop: {
      key: "participantWorkshop",
      ownerKey: "alice",
      title: "Prepariamo insieme le cassette per l'orto",
      summary:
        "Un laboratorio con invito diretto per costruire piccole cassette.",
      description:
        "Un esempio locale per provare inviti, partecipazione e chat. Le offerte restano nella richiesta originale.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Povo",
        exactMeetingText: "Laboratorio sintetico riservato ai partecipanti",
        exactLocationVisibility: "participants",
      },
      coverAsset: "repair-cafe.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000010",
      skillSlugs: ["basic-repairs"],
      skillImportances: ["useful"],
    },
    participantFull: {
      key: "participantFull",
      ownerKey: "alice",
      title: "Piccolo banco di riparazione — posti esauriti",
      summary: "Un posto, già occupato dalla Creator che conta nella capienza.",
      description:
        "Il link resta valido: il Join deve mostrare la capienza esaurita, senza creare un episodio.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Centro",
        exactMeetingText: "Banco sintetico",
        exactLocationVisibility: "public",
      },
      coverAsset: "repair-cafe.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000011",
      skillSlugs: ["basic-repairs"],
      skillImportances: ["useful"],
      registrationCapacity: 1,
      countOrganizersTowardCapacity: true,
    },
    concert: {
      key: "concert",
      ownerKey: "alice",
      legacyTitle: "DEMO · Courtyard concert",
      title: "Concerto acustico nel cortile",
      summary:
        "Un piccolo concerto di quartiere con strumenti acustici e qualche sedia portata da casa.",
      description:
        "Prepariamo un set breve con chitarra, percussioni leggere e voci. Chi viene può portare una sedia, aiutare con l'audio o semplicemente fermarsi ad ascoltare.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Le Albere",
        exactMeetingText: "Cortile pubblico nel quartiere Le Albere",
        exactLocationVisibility: "public",
      },
      coverAsset: "acoustic-concert.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000003",
      skillSlugs: ["musician", "audio-sound-setup"],
      skillImportances: ["required", "useful"],
    },
  },
  tavoli: {
    participantTable: {
      key: "participantTable",
      ownerKey: "alice",
      title: "Orto condiviso — idee e lavori del mese",
      summary:
        "Un Tavolo aperto con inviti riutilizzabili e partecipanti anche senza foto.",
      description:
        "Condividiamo idee e piccoli lavori. Entrare con un invito non accetta automaticamente offerte di risorse.",
      topic: "Orto di quartiere",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Povo",
        exactMeetingText: "Sala sintetica riservata ai partecipanti",
        exactLocationVisibility: "participants",
      },
      coverAsset: "weekly-community-table.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000012",
      countOrganizersTowardCapacity: true,
    },
    participantEnded: {
      key: "participantEnded",
      ownerKey: "alice",
      title: "Idee per il cortile — Tavolo concluso",
      summary:
        "Un Tavolo concluso conserva il suo vecchio invito, che non ammette più.",
      description:
        "Il link viene creato quando il Tavolo è attivo e poi il ciclo viene concluso attraverso l'API della Creator.",
      topic: "Cortile di quartiere",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Centro",
        exactMeetingText: "Sala sintetica",
        exactLocationVisibility: "public",
      },
      coverAsset: "weekly-community-table.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000013",
    },
    weekly: {
      key: "weekly",
      ownerKey: "alice",
      legacyTitle: "DEMO · Weekly community table",
      title: "Idee per il quartiere — tavolo del mercoledì",
      summary:
        "Un incontro settimanale per trasformare piccole idee locali in cose da fare davvero.",
      description:
        "Porta un'idea concreta, ascolta quelle degli altri e scegliamo insieme un piccolo passo da fare prima dell'incontro successivo.",
      topic: "Progetti di quartiere",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Centro",
        exactMeetingText:
          "Sala riservata del centro di quartiere — dettagli nel gruppo dei partecipanti",
        exactLocationVisibility: "participants",
      },
      coverAsset: "weekly-community-table.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000004",
    },
    monthly: {
      key: "monthly",
      ownerKey: "alice",
      legacyTitle: "DEMO · Monthly makers table",
      title: "Laboratorio aperto: legno e piccole riparazioni",
      summary:
        "Una mattina al mese per condividere attrezzi, tecniche e lavori lasciati a metà.",
      description:
        "Portiamo piccoli lavori in legno e oggetti da sistemare, condividiamo gli attrezzi disponibili e ci aiutiamo senza sostituirci a un servizio professionale.",
      topic: "Fare e riparare",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · San Martino",
        exactMeetingText: "Laboratorio condiviso del quartiere San Martino",
        exactLocationVisibility: "public",
      },
      coverAsset: "makers-table.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000005",
    },
    paused: {
      key: "paused",
      ownerKey: "alice",
      legacyTitle: "DEMO · Paused reading table",
      title: "Gruppo di lettura del sabato",
      summary:
        "Un incontro tranquillo per leggere e discutere insieme, in pausa finché non troviamo un nuovo facilitatore.",
      description:
        "Scegliamo un testo breve alla volta e lasciamo spazio a opinioni diverse. Il gruppo resta in pausa finché qualcuno non potrà facilitare con continuità.",
      topic: "Lettura e discussione",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Centro",
        exactMeetingText: "Sala lettura di quartiere in centro a Trento",
        exactLocationVisibility: "public",
      },
      coverAsset: "reading-group.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000006",
    },
  },
  listings: {
    donate: {
      key: "donate",
      ownerKey: "alice",
      legacyTitle: "DEMO · Community garden tools",
      title: "Regalo attrezzi da giardinaggio",
      listingMode: "donate",
      description:
        "Un rastrello, due palette e due annaffiatoi che non uso più. Preferirei darli a qualcuno che li userà per un orto o un giardino condiviso.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Povo",
      },
      coverAsset: "garden-tools.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000007",
    },
    exchange: {
      key: "exchange",
      ownerKey: "bob",
      legacyTitle: "DEMO · Folding tables for a skill swap",
      title: "Scambio due tavoli pieghevoli per aiuto con una mensola",
      listingMode: "exchange",
      description:
        "Ho due tavoli pieghevoli in buono stato. Li scambio volentieri con una mano per sistemare e fissare una mensola in legno.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · San Martino",
      },
      coverAsset: "folding-tables.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000008",
    },
    closed: {
      key: "closed",
      ownerKey: "carla",
      legacyTitle: "DEMO · Seedling trays (claimed)",
      title: "Vassoi per piantine — già assegnati",
      listingMode: "donate",
      description:
        "Vassoi riutilizzabili da semina. Questo annuncio resta nel demo come esempio di inserzione chiusa.",
      location: {
        countryCode: "IT",
        locality: "Trento",
        administrativeArea: TRENTO_ADMINISTRATIVE_AREA,
        publicLabel: "Trento · Le Albere",
      },
      coverAsset: "seedling-trays.webp",
      coverVersion: "d0200000-0000-4000-8000-000000000009",
    },
  },
  chatBodies: [
    "Ho preparato una bozza del murale e porto nastro e pennarelli per decidere i colori.",
    "Io posso fare qualche foto del muro prima di iniziare e dare una mano con la composizione.",
    "Perfetto. Domani confermiamo qui materiali e orario così arriviamo già organizzati.",
  ],
});

export function assertSafeLocalDemoTarget({
  environment = "local",
  apiUrl,
  databaseUrl,
  mailpitUrl,
}) {
  if (environment !== "local") {
    throw new Error(
      "Demo world tooling supports only the explicit local target; staging and production are refused.",
    );
  }

  const api = parseRequiredUrl(apiUrl, "Supabase API URL");
  const database = parseRequiredUrl(databaseUrl, "database URL");
  const mailpit = parseRequiredUrl(mailpitUrl, "Mailpit URL");

  if (
    api.protocol !== "http:" ||
    !isLoopbackHost(api.hostname) ||
    !["postgres:", "postgresql:"].includes(database.protocol) ||
    !isLoopbackHost(database.hostname) ||
    mailpit.protocol !== "http:" ||
    !isLoopbackHost(mailpit.hostname)
  ) {
    throw new Error(
      "Demo world tooling refused a non-loopback target. Use the project-scoped local Supabase stack and local Mailpit only.",
    );
  }

  return Object.freeze({
    apiUrl: api.toString().replace(/\/$/u, ""),
    databaseUrl: databaseUrl,
    mailpitUrl: mailpit.toString().replace(/\/$/u, ""),
  });
}

export function buildDemoTimes(now = new Date()) {
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
    throw new Error("A valid clock value is required to build demo times.");
  }

  const anchor = new Date(now);
  anchor.setUTCSeconds(0, 0);
  const at = (hours) =>
    new Date(anchor.getTime() + hours * 60 * 60 * 1000).toISOString();
  const effectiveFrom = formatLocalDate(
    new Date(anchor.getTime() - 14 * 24 * 60 * 60 * 1000),
    "Europe/Rome",
  );

  return Object.freeze({
    anchor: anchor.toISOString(),
    muralStartsAt: at(36),
    muralEndsAt: at(40),
    repairStartsAt: at(7 * 24),
    repairEndsAt: at(7 * 24 + 5),
    concertStartsAt: at(-8),
    concertEndsAt: at(-2),
    safeInitialHistoricalStartsAt: at(48),
    safeInitialHistoricalEndsAt: at(51),
    recurringEffectiveFrom: effectiveFrom,
  });
}

export function classifyDemoScenarioCounts(counts) {
  const values = Object.values(counts);
  if (values.some((count) => !Number.isInteger(count) || count < 0)) {
    throw new Error("Demo scenario counts must be non-negative integers.");
  }
  if (values.some((count) => count > 1)) return "duplicate";
  if (values.every((count) => count === 0)) return "empty";
  if (values.every((count) => count === 1)) return "complete";
  return "partial";
}

export function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

export function demoReadyMessage() {
  return `Demo world ready for ${Object.values(DEMO_PERSONAS)
    .map((persona) => persona.email)
    .join(", ")}. Use Mailpit to request a fresh local sign-in code.`;
}

export async function seedLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl = "http://127.0.0.1:54324",
  now = new Date(),
  onInvitationCheckpoint,
  sessionPool,
}) {
  const target = requireTrustedLocalStatus(status, mailpitUrl);
  const sql = postgres(target.databaseUrl, { max: 1, onnotice: () => {} });
  const serviceClient = createClient(target.apiUrl, status.serviceRoleKey, {
    auth: { persistSession: false },
  });
  let lockAcquired = false;

  try {
    const [lock] = await sql`
      select pg_try_advisory_lock(${DEMO_LOCK_ID}) as acquired
    `;
    lockAcquired = lock?.acquired === true;
    if (!lockAcquired) {
      throw new Error(
        "Another demo-world seed is already running for this local database.",
      );
    }

    const context = await createAuthenticatedContext({
      repositoryRoot,
      status,
      mailpitUrl: target.mailpitUrl,
      sql,
      serviceClient,
      sessionPool,
    });
    const times = buildDemoTimes(now);
    await migrateLegacyDemoWorld(context);
    const scenario = await bringDemoWorldToDesiredState(context, times);
    await seedDemoParticipantInvitations(
      context,
      scenario,
      onInvitationCheckpoint,
    );
    await projectNotificationOutbox(serviceClient);
    await verifyDemoWorldState(context, scenario, times);
    await verifyDemoParticipantInvitations(context, scenario);

    return Object.freeze({
      personas: Object.values(DEMO_PERSONAS).map((persona) => persona.email),
      proposals: Object.values(DEMO_SCENARIOS.proposals).map(
        (scenarioDefinition) => scenarioDefinition.title,
      ),
      tavoli: Object.values(DEMO_SCENARIOS.tavoli).map(
        (scenarioDefinition) => scenarioDefinition.title,
      ),
      listings: Object.values(DEMO_SCENARIOS.listings).map(
        (scenarioDefinition) => scenarioDefinition.title,
      ),
    });
  } finally {
    if (lockAcquired) {
      await sql`select pg_advisory_unlock(${DEMO_LOCK_ID})`;
    }
    await sql.end({ timeout: 5 });
  }
}

export async function verifyLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl = "http://127.0.0.1:54324",
  now = new Date(),
  sessionPool,
}) {
  const target = requireTrustedLocalStatus(status, mailpitUrl);
  const sql = postgres(target.databaseUrl, { max: 1, onnotice: () => {} });
  const serviceClient = createClient(target.apiUrl, status.serviceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    const existing = await sql`
      select profile.id from auth.users identity join public.profiles profile on profile.id = identity.id
      where identity.email = any(${Object.values(DEMO_PERSONAS).map((p) => p.email)}::text[])
    `;
    if (existing.length !== Object.keys(DEMO_PERSONAS).length) {
      throw new Error(
        "The demo profiles are missing; verification never creates or completes them.",
      );
    }
    const context = await createAuthenticatedContext({
      repositoryRoot,
      status,
      mailpitUrl: target.mailpitUrl,
      sql,
      serviceClient,
      updateProfiles: false,
      sessionPool,
    });
    const scenario = await resolveExistingScenario(context);
    await verifyDemoParticipantInvitations(context, scenario);
    await verifyDemoWorldState(context, scenario, buildDemoTimes(now));
    return scenario;
  } finally {
    await sql.end({ timeout: 5 });
  }
}

// Explicit mutating integration checks are separate from non-repairing verify.
export async function exerciseLocalDemoInvitations({
  repositoryRoot,
  status,
  mailpitUrl = "http://127.0.0.1:54324",
  sessionPool,
}) {
  const target = requireTrustedLocalStatus(status, mailpitUrl);
  const sql = postgres(target.databaseUrl, { max: 1, onnotice: () => {} });
  let lockAcquired = false;
  try {
    const [lock] =
      await sql`select pg_try_advisory_lock(${DEMO_LOCK_ID}) as acquired`;
    lockAcquired = lock?.acquired === true;
    if (!lockAcquired)
      throw new Error(
        "Another demo-world mutation is already running for this local database.",
      );
    const context = await createAuthenticatedContext({
      repositoryRoot,
      status,
      mailpitUrl: target.mailpitUrl,
      sql,
      updateProfiles: false,
      sessionPool,
    });
    return await exerciseDemoInvitationTransitions(
      context,
      await resolveExistingScenario(context),
    );
  } finally {
    if (lockAcquired) await sql`select pg_advisory_unlock(${DEMO_LOCK_ID})`;
    await sql.end({ timeout: 5 });
  }
}

function requireTrustedLocalStatus(status, mailpitUrl) {
  if (!status?.serviceRoleKey || !status?.databaseUrl) {
    throw new Error(
      "Local Supabase status must provide its database URL and service-role key for trusted demo tooling.",
    );
  }
  return assertSafeLocalDemoTarget({
    environment: "local",
    apiUrl: status.apiUrl,
    databaseUrl: status.databaseUrl,
    mailpitUrl,
  });
}

async function createAuthenticatedContext({
  repositoryRoot,
  status,
  mailpitUrl,
  sql,
  serviceClient,
  updateProfiles = true,
  sessionPool,
}) {
  const personaEntries = await Promise.all(
    Object.entries(DEMO_PERSONAS).map(async ([key, definition]) => [
      key,
      await signInDemoPersona(sessionPool, {
        apiUrl: status.apiUrl,
        publishableKey: status.publishableKey,
        mailpitUrl,
        email: definition.email,
        verifierName: `demo ${key}`,
      }),
    ]),
  );
  const personas = Object.fromEntries(personaEntries);

  if (updateProfiles) {
    const skillSlugs = [
      ...new Set(
        Object.values(DEMO_PERSONAS).flatMap((persona) => persona.skillSlugs),
      ),
    ];
    const { data: skills, error: skillError } = await personas.alice.client
      .from("skills")
      .select("id, slug")
      .in("slug", skillSlugs);
    if (skillError || skills?.length !== skillSlugs.length) {
      throw safeDatabaseFailure(
        "load the controlled demo skill catalog",
        skillError ?? {},
      );
    }
    const skillsBySlug = new Map(skills.map((skill) => [skill.slug, skill.id]));
    await Promise.all(
      Object.entries(personas).map(([key, user]) =>
        ensureCompleteProfile(user, DEMO_PERSONAS[key], skillsBySlug),
      ),
    );
    await Promise.all(
      Object.entries(personas).map(([key, user]) => {
        const definition = DEMO_PERSONAS[key];
        if (definition.photoState === "absent") {
          return clearDemoProfilePhoto(user);
        }
        return ensureLocalProfilePhoto(user, {
          audience: "interactions",
          fixturePath: path.join(
            repositoryRoot,
            "scripts",
            "demo-assets",
            "profiles",
            definition.profileAsset,
          ),
          fixtureVersion: definition.profileVersion,
        });
      }),
    );
    await Promise.all(
      Object.values(personas).map((user) =>
        ensureDemoNotificationPreferences(user),
      ),
    );
  }

  return {
    repositoryRoot,
    status,
    mailpitUrl,
    sql,
    serviceClient,
    personas,
    anonymous: createClient(status.apiUrl, status.publishableKey, {
      auth: { persistSession: false },
    }),
  };
}

function signInDemoPersona(sessionPool, options) {
  if (!sessionPool) return signInLocalOtpUser(options);
  // Bounded checker-owned in-memory sessions avoid repeated OTP email requests
  // within the local one-second throttle. CLI runs never persist session state.
  const key = JSON.stringify([
    options.apiUrl,
    options.publishableKey,
    options.email,
  ]);
  if (!sessionPool.has(key)) sessionPool.set(key, signInLocalOtpUser(options));
  return sessionPool.get(key);
}

async function clearDemoProfilePhoto(user) {
  const { data, error } = await user.client.rpc("get_own_profile_photo", {
    p_expected_profile_id: user.id,
  });
  if (error) throw safeDatabaseFailure("read a photo-free demo profile", error);
  if (data.length === 0) return;
  const cleared = await user.client.rpc("clear_own_profile_photo", {
    p_expected_profile_id: user.id,
  });
  if (cleared.error)
    throw safeDatabaseFailure("clear a photo-free demo profile", cleared.error);
}

async function ensureCompleteProfile(user, definition, skillsBySlug) {
  const { data: anchors, error: readError } = await user.client
    .from("profiles")
    .select("id")
    .eq("id", user.id);
  if (readError) {
    throw safeDatabaseFailure("read a demo profile anchor", readError);
  }
  if (anchors.length === 0) {
    const { error: insertError } = await user.client
      .from("profiles")
      .insert({ id: user.id });
    if (insertError) {
      throw safeDatabaseFailure("create a demo profile anchor", insertError);
    }
  }

  const skillIds = definition.skillSlugs.map((slug) => skillsBySlug.get(slug));
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: definition.displayName,
    p_bio: definition.bio,
    p_skill_ids: skillIds,
    p_display_name_audience: "public",
    p_bio_audience: "public",
    p_skills_audience: "public",
  });
  if (error) {
    throw safeDatabaseFailure("complete a demo profile", error);
  }
}

async function ensureDemoNotificationPreferences(user) {
  await Promise.all(
    ["participation", "chat"].map(async (categorySlug) => {
      const { error } = await user.client.rpc(
        "set_own_notification_preference",
        {
          p_expected_profile_id: user.id,
          p_category_slug: categorySlug,
          p_in_app_enabled: true,
          p_push_enabled: true,
        },
      );
      if (error) {
        throw safeDatabaseFailure(
          "restore a demo notification preference",
          error,
        );
      }
    }),
  );
}

async function migrateLegacyDemoWorld(context) {
  const groups = [
    ["proposal", Object.values(DEMO_SCENARIOS.proposals)],
    ["tavolo", Object.values(DEMO_SCENARIOS.tavoli)],
    ["listing", Object.values(DEMO_SCENARIOS.listings)],
  ];
  let muralId = null;

  for (const [kind, definitions] of groups) {
    for (const definition of definitions) {
      if (!definition.legacyTitle) continue;
      const owner = context.personas[definition.ownerKey];
      const candidates = [definition.legacyTitle, definition.title];
      let rows;
      if (kind === "proposal") {
        rows = await context.sql`
          select proposal.id, proposal.title, proposal.lifecycle_state,
                 cover.object_path as cover_object_path
          from public.proposals as proposal
          left join public.project_covers as cover
            on cover.project_id = proposal.id
          where proposal.creator_profile_id = ${owner.id}
            and proposal.title = any(${candidates}::text[])
        `;
      } else if (kind === "tavolo") {
        rows = await context.sql`
          select activity.id, activity.title, activity.lifecycle_state,
                 cover.object_path as cover_object_path
          from public.recurring_activities as activity
          left join public.project_covers as cover
            on cover.project_id = activity.id
          where activity.creator_profile_id = ${owner.id}
            and activity.title = any(${candidates}::text[])
        `;
      } else {
        rows = await context.sql`
          select listing.id, listing.title, listing.lifecycle_state,
                 cover.object_path as cover_object_path
          from public.resource_listings as listing
          left join public.resource_listing_covers as cover
            on cover.listing_id = listing.id
          where listing.owner_profile_id = ${owner.id}
            and listing.title = any(${candidates}::text[])
        `;
      }

      assertAtMostOne(rows, `${definition.legacyTitle} / ${definition.title}`);
      const existing = rows[0];
      if (!existing) continue;

      if (existing.title === definition.legacyTitle) {
        if (kind === "proposal") {
          await context.sql`
            update public.proposals
            set title = ${definition.title}
            where id = ${existing.id}
              and creator_profile_id = ${owner.id}
              and title = ${definition.legacyTitle}
          `;
        } else if (kind === "tavolo") {
          await context.sql`
            update public.recurring_activities
            set title = ${definition.title}
            where id = ${existing.id}
              and creator_profile_id = ${owner.id}
              and title = ${definition.legacyTitle}
          `;
        } else {
          await context.sql`
            update public.resource_listings
            set title = ${definition.title}
            where id = ${existing.id}
              and owner_profile_id = ${owner.id}
              and title = ${definition.legacyTitle}
          `;
        }
      }

      if (kind === "proposal" && definition.key === "mural") {
        muralId = existing.id;
      }
      if (
        kind === "listing" &&
        definition.key === "closed" &&
        existing.lifecycle_state === "closed" &&
        existing.cover_object_path !==
          expectedCoverObjectPath(owner.id, existing.id, definition, kind)
      ) {
        // A terminal legacy demo listing predates cover media and cannot be
        // repaired through the owner RPC. Re-open only this exact demo row to
        // its prior published state, then let normal APIs set its cover and
        // close it again without changing its canonical ID.
        await context.sql`
          update public.resource_listings
          set lifecycle_state = 'published',
              closed_at = null
          where id = ${existing.id}
            and owner_profile_id = ${owner.id}
            and lifecycle_state = 'closed'
        `;
      }
    }
  }

  if (muralId) {
    const [chat] = await context.sql`
      select id
      from public.project_group_chats
      where project_id = ${muralId}
    `;
    if (chat) {
      for (const [index, legacyBody] of LEGACY_CHAT_BODIES.entries()) {
        const currentBody = DEMO_SCENARIOS.chatBodies[index];
        const matchingMessages = await context.sql`
          select id
          from public.project_chat_messages
          where chat_id = ${chat.id}
            and body = any(${[legacyBody, currentBody]}::text[])
        `;
        assertAtMostOne(
          matchingMessages,
          `legacy demo chat message ${index + 1}`,
        );
      }
      await context.sql.begin(async (transaction) => {
        // Chat messages are intentionally immutable in production. Trusted
        // local migration preserves their IDs (and notification references)
        // while replacing only the three exact DEMO-B fixture bodies.
        await transaction`set local session_replication_role = replica`;
        for (const [index, legacyBody] of LEGACY_CHAT_BODIES.entries()) {
          await transaction`
            update public.project_chat_messages
            set body = ${DEMO_SCENARIOS.chatBodies[index]}
            where chat_id = ${chat.id}
              and body = ${legacyBody}
          `;
        }
      });
    }
  }
}

async function ensureProjectCover(context, owner, projectId, definition) {
  return ensureCanonicalCover({
    context,
    owner,
    parentId: projectId,
    definition,
    kind: "project",
  });
}

async function ensureResourceCover(context, owner, listingId, definition) {
  return ensureCanonicalCover({
    context,
    owner,
    parentId: listingId,
    definition,
    kind: "listing",
  });
}

async function ensureCanonicalCover({
  context,
  owner,
  parentId,
  definition,
  kind,
}) {
  const isProject = kind === "project";
  const objectPath = expectedCoverObjectPath(
    owner.id,
    parentId,
    definition,
    kind,
  );
  const readOperation = isProject
    ? "get_own_project_cover"
    : "get_own_resource_listing_cover";
  const readParams = isProject
    ? {
        p_expected_creator_profile_id: owner.id,
        p_project_id: parentId,
      }
    : {
        p_expected_owner_profile_id: owner.id,
        p_listing_id: parentId,
      };
  const { data: existing, error: readError } = await owner.client.rpc(
    readOperation,
    readParams,
  );
  if (readError || !Array.isArray(existing) || existing.length > 1) {
    throw safeDatabaseFailure("read a demo canonical cover", readError ?? {});
  }
  if (existing[0]?.object_path === objectPath) {
    await downloadCover(owner.client, objectPath, "verify a demo owner cover");
    return objectPath;
  }

  let bytes;
  try {
    bytes = await readFile(
      path.join(
        context.repositoryRoot,
        "scripts",
        "demo-assets",
        "covers",
        definition.coverAsset,
      ),
    );
  } catch (error) {
    throw safeDatabaseFailure("read a vendored demo cover", error);
  }

  const { error: uploadError } = await owner.client.storage
    .from(COVER_BUCKET)
    .upload(objectPath, bytes, {
      contentType: "image/webp",
      upsert: false,
    });
  const uploadedNewObject = !uploadError;
  if (uploadError && uploadError.code !== "KeyAlreadyExists") {
    throw safeDatabaseFailure("upload a vendored demo cover", uploadError);
  }

  const commitOperation = isProject
    ? "set_own_project_cover"
    : "set_own_resource_listing_cover";
  const commitParams = isProject
    ? {
        p_expected_creator_profile_id: owner.id,
        p_project_id: parentId,
        p_object_path: objectPath,
      }
    : {
        p_expected_owner_profile_id: owner.id,
        p_listing_id: parentId,
        p_object_path: objectPath,
      };
  const { data: committed, error: commitError } = await owner.client.rpc(
    commitOperation,
    commitParams,
  );
  if (commitError || committed?.length !== 1) {
    if (uploadedNewObject) {
      await removeStorageObjectsBestEffort(owner.client, [objectPath]);
    }
    throw safeDatabaseFailure(
      "commit a demo canonical cover",
      commitError ?? {},
    );
  }
  if (committed[0].current_object_path !== objectPath) {
    throw new Error("Demo cover commit returned an unexpected canonical path.");
  }
  const replacedPath = committed[0].previous_object_path;
  if (replacedPath && replacedPath !== objectPath) {
    await removeStorageObjectsBestEffort(owner.client, [replacedPath]);
  }
  await downloadCover(owner.client, objectPath, "verify a demo owner cover");
  return objectPath;
}

async function readExpectedResourceCover(owner, listingId, definition) {
  const expectedPath = expectedCoverObjectPath(
    owner.id,
    listingId,
    definition,
    "listing",
  );
  const { data, error } = await owner.client.rpc(
    "get_own_resource_listing_cover",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
  );
  if (error || data?.length !== 1 || data[0].object_path !== expectedPath) {
    throw safeDatabaseFailure("read a closed demo listing cover", error ?? {});
  }
  await downloadCover(
    owner.client,
    expectedPath,
    "verify a closed owner cover",
  );
  return expectedPath;
}

function expectedCoverObjectPath(ownerId, parentId, definition, kind) {
  const folder = kind === "project" ? "projects" : "resources";
  return `${ownerId}/${folder}/${parentId}/${definition.coverVersion}.webp`;
}

async function downloadCover(client, objectPath, action) {
  const { data, error } = await client.storage
    .from(COVER_BUCKET)
    .download(objectPath);
  if (error || !data || data.size < 1) {
    throw safeDatabaseFailure(action, error ?? {});
  }
  return data;
}

async function removeStorageObjectsBestEffort(client, objectPaths) {
  try {
    await client.storage.from(COVER_BUCKET).remove(objectPaths);
  } catch {
    // The database commit is authoritative; orphan cleanup is retryable.
  }
}

async function bringDemoWorldToDesiredState(context, times) {
  const { personas } = context;
  const mural = await ensureProposal(context, personas.alice, {
    ...DEMO_SCENARIOS.proposals.mural,
    startsAt: times.muralStartsAt,
    endsAt: times.muralEndsAt,
    initialStartsAt: times.muralStartsAt,
    initialEndsAt: times.muralEndsAt,
  });
  const repairCafe = await ensureProposal(context, personas.alice, {
    ...DEMO_SCENARIOS.proposals.repairCafe,
    startsAt: times.repairStartsAt,
    endsAt: times.repairEndsAt,
    initialStartsAt: times.repairStartsAt,
    initialEndsAt: times.repairEndsAt,
  });
  const participantWorkshop = await ensureProposal(context, personas.alice, {
    ...DEMO_SCENARIOS.proposals.participantWorkshop,
    startsAt: times.repairStartsAt,
    endsAt: times.repairEndsAt,
  });
  const participantFull = await ensureProposal(context, personas.alice, {
    ...DEMO_SCENARIOS.proposals.participantFull,
    startsAt: times.repairStartsAt,
    endsAt: times.repairEndsAt,
    participantInvitation: true,
  });
  const concert = await ensureProposal(context, personas.alice, {
    ...DEMO_SCENARIOS.proposals.concert,
    startsAt: times.concertStartsAt,
    endsAt: times.concertEndsAt,
    initialStartsAt: times.safeInitialHistoricalStartsAt,
    initialEndsAt: times.safeInitialHistoricalEndsAt,
    isHistorical: true,
    participantInvitation: true,
  });

  const participantTable = await ensureTavolo(context, personas.alice, {
    ...DEMO_SCENARIOS.tavoli.participantTable,
    recurrenceType: "weekly",
    weekday: 2,
    dayOfMonth: null,
    localStartTime: "18:00:00",
    durationMinutes: 60,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "published",
  });
  const participantEnded = await ensureTavolo(context, personas.alice, {
    ...DEMO_SCENARIOS.tavoli.participantEnded,
    recurrenceType: "weekly",
    weekday: 2,
    dayOfMonth: null,
    localStartTime: "18:00:00",
    durationMinutes: 60,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "ended",
    participantInvitation: true,
  });
  const weekly = await ensureTavolo(context, personas.alice, {
    ...DEMO_SCENARIOS.tavoli.weekly,
    recurrenceType: "weekly",
    weekday: 3,
    dayOfMonth: null,
    localStartTime: "18:30:00",
    durationMinutes: 90,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "published",
  });
  const monthly = await ensureTavolo(context, personas.alice, {
    ...DEMO_SCENARIOS.tavoli.monthly,
    recurrenceType: "monthly",
    weekday: null,
    dayOfMonth: 15,
    localStartTime: "10:00:00",
    durationMinutes: 120,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "published",
  });
  const paused = await ensureTavolo(context, personas.alice, {
    ...DEMO_SCENARIOS.tavoli.paused,
    recurrenceType: "weekly",
    weekday: 6,
    dayOfMonth: null,
    localStartTime: "16:00:00",
    durationMinutes: 75,
    effectiveFrom: times.recurringEffectiveFrom,
    lifecycle: "paused",
    participantInvitation: true,
  });

  const muralPendingRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    mural.id,
    "pending",
    "Posso aiutare a preparare il muro e organizzare i materiali.",
  );
  const muralMembershipId = await ensureCurrentMembership(
    context,
    personas.carla,
    personas.alice,
    mural.id,
    "Posso occuparmi delle foto e dare una mano con colori e composizione.",
  );
  const repairRejectedRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    repairCafe.id,
    "rejected",
    "Mi piacerebbe occuparmi del banco delle riparazioni elettriche.",
  );
  const weeklyWithdrawnRequestId = await ensureRequestState(
    context,
    personas.bob,
    personas.alice,
    weekly.id,
    "withdrawn",
    "Forse riesco a partecipare al tavolo del mercoledì.",
  );
  const chat = await ensureChatHistory(
    context,
    personas.alice,
    personas.carla,
    mural.id,
  );

  const donate = await ensureListing(context, personas.alice, {
    ...DEMO_SCENARIOS.listings.donate,
    lifecycle: "published",
  });
  const exchange = await ensureListing(context, personas.bob, {
    ...DEMO_SCENARIOS.listings.exchange,
    lifecycle: "published",
  });
  const closed = await ensureListing(context, personas.carla, {
    ...DEMO_SCENARIOS.listings.closed,
    lifecycle: "closed",
  });

  return {
    proposals: {
      mural,
      repairCafe,
      concert,
      participantWorkshop,
      participantFull,
    },
    tavoli: { weekly, monthly, paused, participantTable, participantEnded },
    participation: {
      muralPendingRequestId,
      muralMembershipId,
      repairRejectedRequestId,
      weeklyWithdrawnRequestId,
    },
    chat,
    listings: { donate, exchange, closed },
  };
}

async function ensureProposal(context, creator, definition) {
  const { sql } = context;
  const rows = await sql`
    select id, lifecycle_state, starts_at
    from public.proposals
    where creator_profile_id = ${creator.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let proposalId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  if (proposalId && definition.isHistorical && lifecycleState === "published") {
    await sql`
      update public.proposals
      set starts_at = ${definition.initialStartsAt},
          ends_at = ${definition.initialEndsAt}
      where id = ${proposalId}
    `;
  }

  const skillIds = await resolveSkillIds(creator.client, definition.skillSlugs);
  const params = {
    p_expected_creator_profile_id: creator.id,
    p_title: definition.title,
    p_summary: definition.summary,
    p_description: definition.description,
    p_starts_at: definition.isHistorical
      ? definition.initialStartsAt
      : definition.startsAt,
    p_ends_at: definition.isHistorical
      ? definition.initialEndsAt
      : definition.endsAt,
    p_event_timezone: "Europe/Rome",
    p_country_code: definition.location.countryCode,
    p_locality: definition.location.locality,
    p_administrative_area: definition.location.administrativeArea,
    p_public_location_label: definition.location.publicLabel,
    p_exact_meeting_text: definition.location.exactMeetingText,
    p_exact_location_visibility: definition.location.exactLocationVisibility,
    p_skill_ids: skillIds,
    p_skill_importances: definition.skillImportances,
    p_registration_capacity: definition.registrationCapacity ?? 20,
    p_count_organizers_toward_capacity:
      definition.countOrganizersTowardCapacity ?? false,
  };

  if (!proposalId) {
    const { data, error } = await creator.client.rpc(
      "create_proposal_draft",
      params,
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo Proposal", error ?? {});
    }
    proposalId = data;
    lifecycleState = "draft";
  } else if (lifecycleState === "draft" || lifecycleState === "published") {
    const { error } = await creator.client.rpc("update_own_proposal", {
      ...params,
      p_proposal_id: proposalId,
    });
    if (error) throw safeDatabaseFailure("update a demo Proposal", error);
  }

  if (lifecycleState === "cancelled") {
    throw new Error(
      `Demo-owned Proposal "${definition.title}" is cancelled; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  const coverObjectPath = await ensureProjectCover(
    context,
    creator,
    proposalId,
    definition,
  );
  if (lifecycleState === "draft") {
    const { error } = await creator.client.rpc("publish_proposal", {
      p_expected_creator_profile_id: creator.id,
      p_proposal_id: proposalId,
    });
    if (error) throw safeDatabaseFailure("publish a demo Proposal", error);
  }

  if (definition.participantInvitation) {
    await ensureDemoInvitation(context, proposalId);
  }
  await sql`
    update public.proposals
    set starts_at = ${definition.startsAt},
        ends_at = ${definition.endsAt}
    where id = ${proposalId}
  `;
  return { id: proposalId, title: definition.title, coverObjectPath };
}

async function ensureTavolo(context, creator, definition) {
  const { sql } = context;
  const rows = await sql`
    select id, lifecycle_state
    from public.recurring_activities
    where creator_profile_id = ${creator.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let tavoloId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  const params = {
    p_expected_creator_profile_id: creator.id,
    p_title: definition.title,
    p_summary: definition.summary,
    p_description: definition.description,
    p_topic: definition.topic,
    p_country_code: definition.location.countryCode,
    p_locality: definition.location.locality,
    p_administrative_area: definition.location.administrativeArea,
    p_public_location_label: definition.location.publicLabel,
    p_exact_meeting_text: definition.location.exactMeetingText,
    p_exact_location_visibility: definition.location.exactLocationVisibility,
    p_recurrence_type: definition.recurrenceType,
    p_weekday: definition.weekday,
    p_day_of_month: definition.dayOfMonth,
    p_local_start_time: definition.localStartTime,
    p_duration_minutes: definition.durationMinutes,
    p_event_timezone: "Europe/Rome",
    p_effective_from: definition.effectiveFrom,
    p_registration_capacity: definition.registrationCapacity ?? 20,
    p_count_organizers_toward_capacity:
      definition.countOrganizersTowardCapacity ?? false,
  };

  if (!tavoloId) {
    const { data, error } = await creator.client.rpc(
      "create_recurring_activity_draft",
      params,
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo Tavolo", error ?? {});
    }
    tavoloId = data;
    lifecycleState = "draft";
  } else if (["draft", "published", "paused"].includes(lifecycleState)) {
    const { error } = await creator.client.rpc(
      "update_own_recurring_activity",
      {
        ...params,
        p_recurring_activity_id: tavoloId,
      },
    );
    if (error) throw safeDatabaseFailure("update a demo Tavolo", error);
  }

  if (lifecycleState === "ended" && definition.lifecycle !== "ended") {
    throw new Error(
      `Demo-owned Tavolo "${definition.title}" is ended; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  const coverObjectPath = await ensureProjectCover(
    context,
    creator,
    tavoloId,
    definition,
  );
  if (lifecycleState === "draft") {
    await transitionTavolo(creator, "publish_recurring_activity", tavoloId);
    lifecycleState = "published";
  }
  if (definition.participantInvitation) {
    const [current] = await sql`
      select id from private.project_participant_invitations
      where project_id = ${tavoloId} and revoked_at is null
    `;
    // Lifecycle-sensitive links are issued while active, never fabricated on
    // frozen fixtures. A resumed interrupted run can retrieve its generation.
    if (!current && lifecycleState === "paused") {
      await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
      lifecycleState = "published";
    }
    await ensureDemoInvitation(context, tavoloId);
  }
  if (definition.lifecycle === "paused" && lifecycleState === "published") {
    await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  } else if (
    definition.lifecycle === "published" &&
    lifecycleState === "paused"
  ) {
    await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  }
  if (definition.lifecycle === "ended" && lifecycleState !== "ended") {
    await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  }
  return { id: tavoloId, title: definition.title, coverObjectPath };
}

async function transitionTavolo(user, operation, tavoloId) {
  const { error } = await user.client.rpc(operation, {
    p_expected_creator_profile_id: user.id,
    p_recurring_activity_id: tavoloId,
  });
  if (error) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error);
  }
}

async function ensureRequestState(
  context,
  requester,
  creator,
  projectId,
  desiredStatus,
  message,
) {
  const rows = await context.sql`
    select id, status
    from public.project_join_requests
    where project_id = ${projectId}
      and requester_profile_id = ${requester.id}
      and status = ${desiredStatus}
    order by created_at desc
  `;
  if (rows.length > 0) return rows[0].id;

  const pendingRows = await context.sql`
    select id
    from public.project_join_requests
    where project_id = ${projectId}
      and requester_profile_id = ${requester.id}
      and status = 'pending'
  `;
  assertAtMostOne(pendingRows, `pending request for ${projectId}`);
  let requestId = pendingRows[0]?.id;
  if (!requestId) {
    const { data, error } = await requester.client.rpc(
      "request_to_join_project",
      {
        p_expected_requester_profile_id: requester.id,
        p_project_id: projectId,
        p_request_message: message,
      },
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure(
        "create a demo participation request",
        error ?? {},
      );
    }
    requestId = data;
  }

  if (desiredStatus === "rejected") {
    const { error } = await creator.client.rpc("reject_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    });
    if (error) throw safeDatabaseFailure("reject a demo request", error);
  } else if (desiredStatus === "withdrawn") {
    const { error } = await requester.client.rpc(
      "withdraw_project_join_request",
      {
        p_expected_requester_profile_id: requester.id,
        p_request_id: requestId,
      },
    );
    if (error) throw safeDatabaseFailure("withdraw a demo request", error);
  } else if (desiredStatus !== "pending") {
    throw new Error(`Unsupported demo request state: ${desiredStatus}.`);
  }
  return requestId;
}

async function ensureCurrentMembership(
  context,
  participant,
  creator,
  projectId,
  message,
) {
  const memberships = await context.sql`
    select id
    from public.project_memberships
    where project_id = ${projectId}
      and participant_profile_id = ${participant.id}
      and left_at is null
      and removed_at is null
  `;
  assertAtMostOne(memberships, `current membership for ${projectId}`);
  if (memberships.length === 1) return memberships[0].id;

  const requestId = await ensureRequestState(
    context,
    participant,
    creator,
    projectId,
    "pending",
    message,
  );
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "accept a demo participation request",
      error ?? {},
    );
  }
  return data;
}

async function ensureChatHistory(context, creator, participant, projectId) {
  const { data, error } = await creator.client.rpc(
    "get_own_project_group_chat",
    {
      p_expected_profile_id: creator.id,
      p_project_id: projectId,
    },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("resolve the demo Project chat", error ?? {});
  }
  const chatId = data[0].chat_id;
  const senders = [creator, participant, creator];
  for (const [index, body] of DEMO_SCENARIOS.chatBodies.entries()) {
    const existing = await context.sql`
      select id
      from public.project_chat_messages
      where chat_id = ${chatId}
        and body = ${body}
    `;
    assertAtMostOne(existing, `demo chat message ${index + 1}`);
    if (existing.length === 0) {
      const { data: sent, error: sendError } = await senders[index].client.rpc(
        "send_project_chat_message",
        {
          p_expected_profile_id: senders[index].id,
          p_chat_id: chatId,
          p_body: body,
        },
      );
      if (sendError || sent?.length !== 1) {
        throw safeDatabaseFailure(
          "send a demo Project chat message",
          sendError ?? {},
        );
      }
    }
  }
  return { id: chatId, projectId };
}

async function ensureListing(context, owner, definition) {
  const rows = await context.sql`
    select id, lifecycle_state, listing_mode
    from public.resource_listings
    where owner_profile_id = ${owner.id}
      and title = ${definition.title}
  `;
  assertAtMostOne(rows, definition.title);
  let listingId = rows[0]?.id;
  let lifecycleState = rows[0]?.lifecycle_state;

  const params = {
    p_expected_owner_profile_id: owner.id,
    p_listing_mode: definition.listingMode,
    p_title: definition.title,
    p_description: definition.description,
    p_country_code: definition.location.countryCode,
    p_locality: definition.location.locality,
    p_administrative_area: definition.location.administrativeArea,
    p_public_location_label: definition.location.publicLabel,
  };
  if (!listingId) {
    const { data, error } = await owner.client.rpc(
      "create_resource_listing_draft",
      params,
    );
    if (error || typeof data !== "string") {
      throw safeDatabaseFailure("create a demo resource listing", error ?? {});
    }
    listingId = data;
    lifecycleState = "draft";
  } else if (lifecycleState === "draft" || lifecycleState === "published") {
    const { error } = await owner.client.rpc("update_own_resource_listing", {
      ...params,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("update a demo listing", error);
  }

  if (lifecycleState === "closed") {
    const coverObjectPath = await readExpectedResourceCover(
      owner,
      listingId,
      definition,
    );
    return { id: listingId, title: definition.title, coverObjectPath };
  }
  const coverObjectPath = await ensureResourceCover(
    context,
    owner,
    listingId,
    definition,
  );
  if (lifecycleState === "draft") {
    const { error } = await owner.client.rpc("publish_resource_listing", {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("publish a demo listing", error);
    lifecycleState = "published";
  }
  if (definition.lifecycle === "closed" && lifecycleState === "published") {
    const { error } = await owner.client.rpc("close_resource_listing", {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    });
    if (error) throw safeDatabaseFailure("close a demo listing", error);
  } else if (
    definition.lifecycle === "published" &&
    lifecycleState === "closed"
  ) {
    throw new Error(
      `Demo-owned listing "${definition.title}" is closed; run \`npm run demo:reset:local\` to rebuild it.`,
    );
  }
  return { id: listingId, title: definition.title, coverObjectPath };
}

async function projectNotificationOutbox(serviceClient) {
  for (let batch = 0; batch < 20; batch += 1) {
    const { data, error } = await serviceClient.rpc(
      "process_notification_outbox_batch",
      { p_limit: 100 },
    );
    const result = data?.[0];
    if (error || !Number.isInteger(result?.processed_count)) {
      throw safeDatabaseFailure("project demo notifications", error ?? {});
    }
    if (result.processed_count === 0) return;
  }
  throw new Error(
    "The local notification backlog did not drain within 20 projector batches.",
  );
}

async function resolveExistingScenario(context) {
  const findProposal = async (owner, definition) => {
    const row = await findOneByTitle(
      context.sql,
      "proposal",
      owner.id,
      definition.title,
    );
    return {
      ...row,
      coverObjectPath: expectedCoverObjectPath(
        owner.id,
        row.id,
        definition,
        "project",
      ),
    };
  };
  const findTavolo = async (owner, definition) => {
    const row = await findOneByTitle(
      context.sql,
      "tavolo",
      owner.id,
      definition.title,
    );
    return {
      ...row,
      coverObjectPath: expectedCoverObjectPath(
        owner.id,
        row.id,
        definition,
        "project",
      ),
    };
  };
  const findListing = async (owner, definition) => {
    const row = await findOneByTitle(
      context.sql,
      "listing",
      owner.id,
      definition.title,
    );
    return {
      ...row,
      coverObjectPath: expectedCoverObjectPath(
        owner.id,
        row.id,
        definition,
        "listing",
      ),
    };
  };
  const { alice, bob, carla } = context.personas;
  const mural = await findProposal(alice, DEMO_SCENARIOS.proposals.mural);
  const repairCafe = await findProposal(
    alice,
    DEMO_SCENARIOS.proposals.repairCafe,
  );
  const concert = await findProposal(alice, DEMO_SCENARIOS.proposals.concert);
  const participantWorkshop = await findProposal(
    alice,
    DEMO_SCENARIOS.proposals.participantWorkshop,
  );
  const participantFull = await findProposal(
    alice,
    DEMO_SCENARIOS.proposals.participantFull,
  );
  const weekly = await findTavolo(alice, DEMO_SCENARIOS.tavoli.weekly);
  const monthly = await findTavolo(alice, DEMO_SCENARIOS.tavoli.monthly);
  const paused = await findTavolo(alice, DEMO_SCENARIOS.tavoli.paused);
  const participantTable = await findTavolo(
    alice,
    DEMO_SCENARIOS.tavoli.participantTable,
  );
  const participantEnded = await findTavolo(
    alice,
    DEMO_SCENARIOS.tavoli.participantEnded,
  );
  const donate = await findListing(alice, DEMO_SCENARIOS.listings.donate);
  const exchange = await findListing(bob, DEMO_SCENARIOS.listings.exchange);
  const closed = await findListing(carla, DEMO_SCENARIOS.listings.closed);
  const [chat] = await context.sql`
    select chat.id
    from public.project_group_chats as chat
    where chat.project_id = ${mural.id}
  `;
  if (!chat) throw new Error("The demo mural chat is missing.");
  return {
    proposals: {
      mural,
      repairCafe,
      concert,
      participantWorkshop,
      participantFull,
    },
    tavoli: { weekly, monthly, paused, participantTable, participantEnded },
    chat: { id: chat.id, projectId: mural.id },
    listings: { donate, exchange, closed },
  };
}

async function verifyDemoWorldState(context, scenario, times) {
  const { personas, anonymous, sql } = context;
  const profileIds = Object.values(personas).map((p) => p.id);
  const [profileRows, profilePhotoRows, scenarioRows, lifecycleRows] =
    await Promise.all([
      sql`
        select id, display_name, bio
        from public.profiles
        where id = any(${profileIds}::uuid[])
      `,
      sql`
        select profile_id, object_path, audience
        from public.profile_photos
        where profile_id = any(${profileIds}::uuid[])
      `,
      sql`
        select 'proposal' as kind, creator_profile_id as owner_id, id, title
        from public.proposals
        where creator_profile_id = any(${profileIds}::uuid[])
          and title = any(${knownDemoTitles()}::text[])
        union all
        select 'tavolo' as kind, creator_profile_id as owner_id, id, title
        from public.recurring_activities
        where creator_profile_id = any(${profileIds}::uuid[])
          and title = any(${knownDemoTitles()}::text[])
        union all
        select 'listing' as kind, owner_profile_id as owner_id, id, title
        from public.resource_listings
        where owner_profile_id = any(${profileIds}::uuid[])
          and title = any(${knownDemoTitles()}::text[])
      `,
      sql`
        select 'proposal' as kind, id, lifecycle_state,
               starts_at > statement_timestamp() as starts_in_future,
               ends_at < statement_timestamp()
                 and ends_at > statement_timestamp() - interval '24 hours'
                 as recently_finished
        from public.proposals
        where id = any(${Object.values(scenario.proposals).map((row) => row.id)}::uuid[])
        union all
        select 'tavolo' as kind, id, lifecycle_state,
               false as starts_in_future, false as recently_finished
        from public.recurring_activities
        where id = any(${Object.values(scenario.tavoli).map((row) => row.id)}::uuid[])
        union all
        select 'listing' as kind, id, lifecycle_state,
               false as starts_in_future, false as recently_finished
        from public.resource_listings
        where id = any(${Object.values(scenario.listings).map((row) => row.id)}::uuid[])
      `,
    ]);
  if (profileRows.length !== Object.keys(DEMO_PERSONAS).length) {
    throw new Error("Demo personas do not have all complete profiles.");
  }
  for (const [key, user] of Object.entries(personas)) {
    const definition = DEMO_PERSONAS[key];
    const profile = profileRows.find((row) => row.id === user.id);
    if (
      profile?.display_name !== definition.displayName ||
      profile?.bio !== definition.bio
    ) {
      throw new Error(`Demo persona ${key} does not match its canonical copy.`);
    }
    const photo = profilePhotoRows.find((row) => row.profile_id === user.id);
    if (definition.photoState === "absent") {
      if (photo)
        throw new Error(`Demo persona ${key} must have no canonical photo.`);
      continue;
    }
    const expectedPath = `${user.id}/${definition.profileVersion}.webp`;
    if (
      photo?.object_path !== expectedPath ||
      photo?.audience !== "interactions"
    ) {
      throw new Error(`Demo persona ${key} lacks its canonical profile photo.`);
    }
    const { data, error } = await user.client.storage
      .from("profile-photos")
      .download(expectedPath);
    if (error || !data || data.size < 1) {
      throw safeDatabaseFailure("download a demo profile photo", error ?? {});
    }
  }

  const expectedDefinitions = allScenarioDefinitions();
  if (
    scenarioRows.length !== expectedDefinitions.length ||
    scenarioRows.some((row) => row.title.startsWith("DEMO ·")) ||
    expectedDefinitions.some(
      (definition) =>
        scenarioRows.filter((row) => row.title === definition.title).length !==
        1,
    )
  ) {
    throw new Error(
      "Demo scenario reconciliation left a missing, duplicate, or legacy-titled row.",
    );
  }
  const stateById = new Map(lifecycleRows.map((row) => [row.id, row]));
  if (
    !stateById.get(scenario.proposals.mural.id)?.starts_in_future ||
    !stateById.get(scenario.proposals.repairCafe.id)?.starts_in_future ||
    !stateById.get(scenario.proposals.concert.id)?.recently_finished ||
    stateById.get(scenario.proposals.concert.id)?.lifecycle_state !==
      "published" ||
    stateById.get(scenario.tavoli.paused.id)?.lifecycle_state !== "paused" ||
    stateById.get(scenario.tavoli.participantEnded.id)?.lifecycle_state !==
      "ended" ||
    stateById.get(scenario.listings.closed.id)?.lifecycle_state !== "closed"
  ) {
    throw new Error(
      "Demo historical, paused, or closed lifecycle state drifted.",
    );
  }

  const [
    proposalList,
    tavoloList,
    bobMessages,
    bobNotifications,
    chatHistory,
    listings,
    publicMural,
    publicWeekly,
    publicDonate,
    ownerClosed,
  ] = await Promise.all([
    anonymous.rpc("list_public_proposals", {
      p_limit: 20,
      p_cursor_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
      p_skill_ids: null,
    }),
    anonymous.rpc("list_public_recurring_activities", {
      p_reference_time: times.anchor,
      p_limit: 20,
      p_cursor_next_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
    }),
    personas.bob.client.rpc("list_own_participation_request_message_items", {
      p_expected_profile_id: personas.bob.id,
      p_limit: 20,
      p_cursor_activity_at: null,
      p_cursor_request_id: null,
    }),
    personas.bob.client.rpc("list_own_notifications", {
      p_expected_profile_id: personas.bob.id,
      p_limit: 100,
      p_cursor_created_at: null,
      p_cursor_id: null,
    }),
    personas.carla.client.rpc("list_own_project_chat_messages", {
      p_expected_profile_id: personas.carla.id,
      p_chat_id: scenario.chat.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    }),
    anonymous.rpc("list_public_resource_listings", {
      p_limit: 20,
      p_cursor_published_at: null,
      p_cursor_id: null,
      p_listing_mode: null,
      p_locality: "Trento",
      p_query: null,
    }),
    anonymous.rpc("get_public_proposal", {
      p_proposal_id: scenario.proposals.mural.id,
    }),
    anonymous.rpc("get_public_recurring_activity", {
      p_recurring_activity_id: scenario.tavoli.weekly.id,
      p_occurrence_limit: 3,
      p_reference_time: times.anchor,
    }),
    anonymous.rpc("get_public_resource_listing", {
      p_listing_id: scenario.listings.donate.id,
    }),
    personas.carla.client.rpc("get_own_resource_listing", {
      p_expected_owner_profile_id: personas.carla.id,
      p_listing_id: scenario.listings.closed.id,
    }),
  ]);
  const results = [
    proposalList,
    tavoloList,
    bobMessages,
    bobNotifications,
    chatHistory,
    listings,
    publicMural,
    publicWeekly,
    publicDonate,
    ownerClosed,
  ];
  if (results.some((result) => result.error || !Array.isArray(result.data))) {
    const failed = results.find((result) => result.error);
    throw safeDatabaseFailure(
      "verify the demo-world read model",
      failed?.error ?? {},
    );
  }

  const proposalIds = new Set(proposalList.data.map((row) => row.proposal_id));
  if (
    !proposalIds.has(scenario.proposals.mural.id) ||
    !proposalIds.has(scenario.proposals.repairCafe.id) ||
    !proposalIds.has(scenario.proposals.concert.id)
  ) {
    throw new Error("Expected demo Proposals were missing from discovery.");
  }
  assertReadModelCovers(
    proposalList.data,
    "proposal_id",
    Object.values(scenario.proposals),
    "Proposal discovery",
  );
  const tavoloIds = new Set(
    tavoloList.data.map((row) => row.recurring_activity_id),
  );
  if (
    !tavoloIds.has(scenario.tavoli.weekly.id) ||
    !tavoloIds.has(scenario.tavoli.monthly.id)
  ) {
    throw new Error("Expected active demo Tavoli were missing from discovery.");
  }
  assertReadModelCovers(
    tavoloList.data,
    "recurring_activity_id",
    [scenario.tavoli.weekly, scenario.tavoli.monthly],
    "Tavolo discovery",
  );
  const messageStatuses = new Set(bobMessages.data.map((row) => row.status));
  if (
    !messageStatuses.has("pending") ||
    !messageStatuses.has("rejected") ||
    !messageStatuses.has("withdrawn")
  ) {
    throw new Error(
      "Marco's demo Messages do not cover the expected request states.",
    );
  }
  if (bobNotifications.data.length === 0) {
    throw new Error("Projected demo notifications were missing for Marco.");
  }
  const chatBodies = new Set(chatHistory.data.map((row) => row.body));
  if (
    DEMO_SCENARIOS.chatBodies.some((body) => !chatBodies.has(body)) ||
    LEGACY_CHAT_BODIES.some((body) => chatBodies.has(body))
  ) {
    throw new Error("The demo Project chat history was incomplete.");
  }
  const listingIds = new Set(listings.data.map((row) => row.listing_id));
  if (
    !listingIds.has(scenario.listings.donate.id) ||
    !listingIds.has(scenario.listings.exchange.id) ||
    listingIds.has(scenario.listings.closed.id)
  ) {
    throw new Error("Demo resource listing discovery was inconsistent.");
  }
  assertReadModelCovers(
    listings.data,
    "listing_id",
    [scenario.listings.donate, scenario.listings.exchange],
    "Resource discovery",
  );
  if (
    [...proposalList.data, ...tavoloList.data, ...listings.data].some((row) =>
      row.title.startsWith("DEMO ·"),
    )
  ) {
    throw new Error("Public demo discovery still exposes a technical title.");
  }

  if (
    publicMural.error ||
    publicMural.data?.length !== 1 ||
    publicMural.data[0].cover_object_path !==
      scenario.proposals.mural.coverObjectPath ||
    publicMural.data[0].exact_meeting_text !== null ||
    JSON.stringify(publicMural.data).includes(
      DEMO_SCENARIOS.proposals.mural.location.exactMeetingText,
    )
  ) {
    throw new Error("The restricted demo Proposal exposed its exact location.");
  }
  if (
    publicWeekly.error ||
    publicWeekly.data?.length !== 1 ||
    publicWeekly.data[0].cover_object_path !==
      scenario.tavoli.weekly.coverObjectPath ||
    publicDonate.error ||
    publicDonate.data?.length !== 1 ||
    publicDonate.data[0].cover_object_path !==
      scenario.listings.donate.coverObjectPath
  ) {
    throw new Error("A public demo detail omitted its canonical cover.");
  }
  if (
    ownerClosed.error ||
    ownerClosed.data?.length !== 1 ||
    ownerClosed.data[0].lifecycle_state !== "closed" ||
    ownerClosed.data[0].cover_object_path !==
      scenario.listings.closed.coverObjectPath
  ) {
    throw new Error("The closed demo listing is missing from owner history.");
  }

  const projectCoverRows = await sql`
    select project_id as id, object_path
    from public.project_covers
    where project_id = any(${Object.values(scenario.proposals)
      .concat(Object.values(scenario.tavoli))
      .map((row) => row.id)}::uuid[])
  `;
  const resourceCoverRows = await sql`
    select listing_id as id, object_path
    from public.resource_listing_covers
    where listing_id = any(${Object.values(scenario.listings).map((row) => row.id)}::uuid[])
  `;
  const expectedCoverRows = [
    ...Object.values(scenario.proposals),
    ...Object.values(scenario.tavoli),
    ...Object.values(scenario.listings),
  ];
  const canonicalCovers = new Map(
    [...projectCoverRows, ...resourceCoverRows].map((row) => [
      row.id,
      row.object_path,
    ]),
  );
  if (
    canonicalCovers.size !== expectedCoverRows.length ||
    expectedCoverRows.some(
      (row) => canonicalCovers.get(row.id) !== row.coverObjectPath,
    )
  ) {
    throw new Error("A demo entity lacks its deterministic canonical cover.");
  }
  for (const item of [
    ...Object.values(scenario.proposals),
    scenario.tavoli.weekly,
    scenario.tavoli.monthly,
    scenario.listings.donate,
    scenario.listings.exchange,
  ]) {
    await downloadCover(
      anonymous,
      item.coverObjectPath,
      "download a public demo cover anonymously",
    );
  }
  const hiddenCover = await anonymous.storage
    .from(COVER_BUCKET)
    .download(scenario.listings.closed.coverObjectPath);
  if (!hiddenCover.error) {
    throw new Error("The closed demo Resource cover became publicly readable.");
  }
  await downloadCover(
    personas.carla.client,
    scenario.listings.closed.coverObjectPath,
    "download the closed demo owner cover",
  );

  const unauthorizedMeeting = await personas.bob.client.rpc(
    "get_project_participant_meeting_details",
    {
      p_expected_profile_id: personas.bob.id,
      p_project_id: scenario.proposals.mural.id,
    },
  );
  const unrelatedChat = await personas.bob.client.rpc(
    "list_own_project_chat_messages",
    {
      p_expected_profile_id: personas.bob.id,
      p_chat_id: scenario.chat.id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    },
  );
  if (
    unauthorizedMeeting.error?.code !== "42501" ||
    unrelatedChat.error?.code !== "42501"
  ) {
    throw new Error(
      "An unrelated demo persona could access private Project data.",
    );
  }

  const authorizedMeeting = await personas.carla.client.rpc(
    "get_project_participant_meeting_details",
    {
      p_expected_profile_id: personas.carla.id,
      p_project_id: scenario.proposals.mural.id,
    },
  );
  if (
    authorizedMeeting.error ||
    authorizedMeeting.data?.[0]?.exact_meeting_text !==
      DEMO_SCENARIOS.proposals.mural.location.exactMeetingText
  ) {
    throw new Error(
      "The accepted demo participant lacks authorized meeting access.",
    );
  }
}

function assertReadModelCovers(rows, idField, expected, label) {
  for (const item of expected) {
    const row = rows.find((candidate) => candidate[idField] === item.id);
    if (row?.cover_object_path !== item.coverObjectPath) {
      throw new Error(`${label} omitted a deterministic canonical cover.`);
    }
  }
}

function allScenarioDefinitions() {
  return [
    ...Object.values(DEMO_SCENARIOS.proposals),
    ...Object.values(DEMO_SCENARIOS.tavoli),
    ...Object.values(DEMO_SCENARIOS.listings),
  ];
}

function knownDemoTitles() {
  return allScenarioDefinitions()
    .flatMap((definition) => [definition.legacyTitle, definition.title])
    .filter(Boolean);
}

async function findOneByTitle(sql, kind, ownerId, title) {
  let rows;
  if (kind === "proposal") {
    rows = await sql`
      select id, title
      from public.proposals
      where creator_profile_id = ${ownerId} and title = ${title}
    `;
  } else if (kind === "tavolo") {
    rows = await sql`
      select id, title
      from public.recurring_activities
      where creator_profile_id = ${ownerId} and title = ${title}
    `;
  } else {
    rows = await sql`
      select id, title
      from public.resource_listings
      where owner_profile_id = ${ownerId} and title = ${title}
    `;
  }
  if (rows.length !== 1) {
    throw new Error(
      `Expected exactly one demo-owned ${kind} named "${title}"; found ${rows.length}.`,
    );
  }
  return rows[0];
}

async function resolveSkillIds(client, slugs) {
  const { data, error } = await client
    .from("skills")
    .select("id, slug")
    .in("slug", slugs);
  if (error || data?.length !== slugs.length) {
    throw safeDatabaseFailure("resolve demo Proposal skills", error ?? {});
  }
  const bySlug = new Map(data.map((skill) => [skill.slug, skill.id]));
  return slugs.map((slug) => bySlug.get(slug));
}

function assertAtMostOne(rows, label) {
  if (rows.length > 1) {
    throw new Error(
      `Found duplicate demo-owned records for "${label}"; run \`npm run demo:reset:local\` to rebuild the local database.`,
    );
  }
}

function parseRequiredUrl(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} is required for demo tooling.`);
  }
  try {
    return new URL(value);
  } catch {
    throw new Error(`${label} is not a valid URL.`);
  }
}

function isLoopbackHost(hostname) {
  return ["127.0.0.1", "localhost", "::1", "[::1]"].includes(
    hostname.toLowerCase(),
  );
}

function formatLocalDate(value, timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(value);
  const read = (type) => parts.find((part) => part.type === type)?.value;
  return `${read("year")}-${read("month")}-${read("day")}`;
}

function deepFreeze(value) {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const nested of Object.values(value)) deepFreeze(nested);
  }
  return value;
}
