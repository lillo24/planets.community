import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";

// Finite synthetic inventory, shared by seed, read-only verification and native QA.
// No production starter-content exception: each source is an ordinary Proposal.
export const WORKSHOP_PERSONAS = Object.freeze({
  planets: Object.freeze({
    email: "demo-planets@planets.invalid",
    displayName: "PLANETS — demo locale",
    bio: "Identità sintetica per provare esempi locali. Questi eventi non sono attività realmente organizzate da PLANETS.",
    skillSlugs: ["event-organization", "facilitation"],
    profileAsset: "planets.webp",
    profileVersion: "d0500000-0000-4000-8000-000000000001",
  }),
  reviewer: Object.freeze({
    email: "demo-reviewer@planets.invalid",
    displayName: "Revisore — demo locale",
    bio: "Revisore sintetico per la sola prova locale della rimozione di un modello.",
    skillSlugs: ["facilitation"],
    profileAsset: "reviewer.webp",
    profileVersion: "d0500000-0000-4000-8000-000000000002",
  }),
});

const source = (
  key,
  ownerKey,
  title,
  summary,
  description,
  skillSlugs,
  coverAsset,
  needs,
  capacity = 16,
) => ({
  key,
  ownerKey,
  title,
  summary,
  description,
  skillSlugs,
  coverAsset,
  needs,
  capacity,
  durationHours: 3,
  state: "completed",
  locality: "Trento",
  skillImportances: ["required", "useful"],
  coverVersion: workshopRequestId("media", key),
});
const need = (title, details) => ({ title, details, state: "open" });
const core = [
  source(
    "repair",
    "planets",
    "Repair Café: una mattina per aggiustare piccoli oggetti",
    "Accoglienza, piccoli controlli sicuri e un banco condiviso: un esempio da adattare al proprio quartiere.",
    "Accogliamo gli oggetti e decidiamo insieme quali controlli semplici possiamo fare. Separiamo le riparazioni alla nostra portata da quelle da affidare a un professionista; niente lavori su impianti o apparecchi alimentati. Organizziamo piccoli gruppi, annotiamo il prossimo passo e lasciamo puliti i tavoli. È un esempio sintetico, non una garanzia di riparazione.",
    ["basic-repairs", "woodworking"],
    "repair-cafe.webp",
    [
      need(
        "Attrezzi manuali",
        "Cacciaviti, pinze e piccoli morsetti; condividiamo solo utensili adatti al lavoro.",
      ),
      need(
        "Tavoli da lavoro",
        "Due superfici stabili e protezioni per appoggiare gli oggetti.",
      ),
    ],
  ),
  source(
    "mural",
    "alice",
    "Murale di quartiere: prepariamo e dipingiamo insieme",
    "Dal disegno condiviso alla pulizia finale, con ruoli anche per chi non dipinge.",
    "Concordiamo un disegno semplice e verifichiamo prima le autorizzazioni necessarie per la superficie scelta. Proteggiamo il pavimento, prepariamo il supporto e dividiamo il disegno in parti. Lavoriamo in piccoli gruppi con colori adatti; riordiniamo materiali e spazio senza promettere un risultato professionale.",
    ["mural-painting", "event-organization"],
    "mural.webp",
    [
      need(
        "Teli di protezione",
        "Teli riutilizzabili e nastro per proteggere le superfici vicine.",
      ),
      need(
        "Pennelli e rulli",
        "Pennelli di diverse misure e contenitori per lavaggio e riuso.",
      ),
    ],
    20,
  ),
  source(
    "flowerbed",
    "planets",
    "Aiuola condivisa: piantiamo e curiamo uno spazio comune",
    "Prepariamo il terreno, scegliamo piante adatte e concordiamo i turni di cura.",
    "Verifichiamo che lo spazio possa essere usato e scegliamo piante adatte al luogo. Prepariamo il terreno con attrezzi manuali, disponiamo le piante e annaffiamo. Concludiamo concordando chi potrà seguire la cura e quando rivedersi; il modello non certifica autorizzazioni o manutenzione futura.",
    ["gardening", "urban-gardening"],
    "seedling-trays.webp",
    [
      need(
        "Attrezzi da aiuola",
        "Palette, guanti e un piccolo rastrello da condividere.",
      ),
      need(
        "Annaffiatoi",
        "Annaffiatoi e acqua disponibile nel luogo concordato.",
      ),
    ],
    12,
  ),
  source(
    "concert",
    "carla",
    "Concerto acustico di quartiere: suoniamo e prepariamo lo spazio",
    "Set brevi, allestimento semplice e tempo per riordinare insieme.",
    "Concordiamo brevi set acustici e controlliamo le condizioni d'uso dello spazio. Prepariamo posti a sedere e un passaggio libero; proviamo il volume senza disturbare. Alterniamo musica e pause, poi ritiriamo strumenti e sedie. Chi non suona può aiutare nell'allestimento.",
    ["musician", "audio-sound-setup"],
    "acoustic-concert.webp",
    [
      need(
        "Sedie pieghevoli",
        "Sedie stabili, con spazio per passaggi accessibili.",
      ),
      need(
        "Audio essenziale",
        "Un piccolo impianto solo se adatto allo spazio e gestito da chi lo conosce.",
      ),
    ],
    24,
  ),
  source(
    "trail",
    "alice",
    "Pulizia del sentiero: raccogliamo e separiamo i rifiuti",
    "Un percorso breve con briefing, raccolta sicura e conferimento concordato.",
    "Scegliamo un percorso accessibile e verifichiamo come conferire i materiali. Spieghiamo quali rifiuti possiamo raccogliere: oggetti taglienti o sospetti restano a personale competente. In coppia raccogliamo e separiamo i materiali ordinari, poi portiamo i sacchi al punto concordato e riordiniamo gli attrezzi.",
    ["event-organization", "gardening"],
    null,
    [
      need(
        "Guanti da lavoro",
        "Guanti integri della misura adatta; niente raccolta a mani nude.",
      ),
      need(
        "Sacchi per raccolta",
        "Sacchi distinti per i materiali ordinari e pinze manuali.",
      ),
    ],
    18,
  ),
  source(
    "books",
    "planets",
    "Scambio di libri: portane uno e scopri nuove letture",
    "Esponiamo libri, scambiamo consigli e decidiamo la destinazione di quelli rimasti.",
    "Raccogliamo libri in buono stato e li ordiniamo su tavoli con etichette leggibili. Ognuno può proporre una lettura o scegliere un libro; concordiamo una regola semplice di scambio. Prima di chiudere decidiamo insieme dove lasciare i libri rimasti, senza promettere donazioni già autorizzate.",
    ["facilitation", "event-organization"],
    "reading-group.webp",
    [
      need(
        "Tavoli espositivi",
        "Superfici asciutte e stabili per libri ed etichette.",
      ),
      need(
        "Cartelli leggibili",
        "Cartoncini e pennarelli per orientarsi tra le letture.",
      ),
    ],
  ),
  source(
    "bookcase",
    "bob",
    "Libreria di comunità: costruiamo un piccolo punto di scambio",
    "Progetto semplice, assemblaggio e scelta sicura del posto per i libri.",
    "Disegniamo un piccolo mobile e verifichiamo materiale, stabilità e collocazione consentita. Prepariamo i pezzi con persone capaci di usare gli utensili e assembliamo in piccoli gruppi. Controlliamo bordi e fissaggio, poi concordiamo come mantenerlo e quali libri ospitare. Non sostituisce una verifica tecnica professionale.",
    ["woodworking", "practical-making"],
    "makers-table.webp",
    [
      need(
        "Legno e ferramenta",
        "Pezzi integri di misura concordata, viti e protezioni adatte.",
      ),
      need(
        "Utensili manuali",
        "Morsetti e attrezzi usati solo da chi sa gestirli in sicurezza.",
      ),
    ],
    10,
  ),
  source(
    "dinner",
    "carla",
    "Cena di quartiere: prepariamo e condividiamo una tavolata",
    "Coordiniamo preparazione, allestimento e riordino con informazioni chiare sugli alimenti.",
    "Concordiamo luogo e condizioni d'uso, poi dividiamo i compiti tra allestimento, preparazione condivisa e riordino. Ogni contributo alimentare indica ingredienti e allergeni, senza promettere assenza di contaminazioni. Disponiamo tavoli e passaggi comodi, condividiamo la cena e puliamo insieme.",
    ["cooking", "event-organization"],
    null,
    [
      need(
        "Tavoli pieghevoli",
        "Tavoli stabili e tovaglie lavabili per lo spazio concordato.",
      ),
      need(
        "Materiale per servire",
        "Piatti e utensili riutilizzabili, contenitori e cartelli degli ingredienti.",
      ),
    ],
    24,
  ),
];
// Closure is an ordinary need state, not a claim of verified fulfillment.
core[0].needs.push({
  title: "Cartelli per i banchi",
  details: "Esempio chiuso, escluso dal riuso.",
  state: "closed",
});
const extra = (key, overrides) => ({
  ...core[0],
  key,
  ownerKey: "alice",
  coverVersion: workshopRequestId("media", key),
  needs: [],
  ...overrides,
});
export const WORKSHOP_SOURCES = freeze([
  ...core.map((s) => ({ ...s, core: true })),
  extra("activeMural", {
    title: "Murale di quartiere: prepariamo il disegno",
    skillSlugs: core[1].skillSlugs,
    coverAsset: "mural.webp",
    state: "upcoming",
  }),
  extra("activeFlowerbed", {
    title: "Aiuola condivisa: piantiamo nuovi fiori",
    skillSlugs: core[2].skillSlugs,
    coverAsset: "seedling-trays.webp",
    state: "upcoming",
  }),
  extra("fullRepair", {
    title: "Repair Café: aggiustiamo piccoli oggetti al banco",
    state: "upcoming",
    capacity: 1,
    countOrganizers: true,
  }),
  extra("broadRepair", {
    title: "Repair Café: aggiustiamo piccoli oggetti a Rovereto",
    state: "upcoming",
    locality: "Rovereto",
  }),
  extra("unrelated", {
    title: "Prepariamo cartelli per la festa",
    skillSlugs: ["basic-repairs", "event-organization"],
    state: "upcoming",
  }),
  extra("happening", {
    title: "Repair Café: piccoli oggetti in laboratorio oggi",
    state: "happening",
  }),
  extra("draft", {
    title: "Repair Café: idea privata da completare",
    state: "draft",
  }),
  extra("cancelled", {
    title: "Repair Café: prova annullata",
    state: "cancelled",
  }),
  extra("removed", {
    title: "Repair Café: modello per la prova di rimozione",
    operational: true,
    needs: core[0].needs,
  }),
  extra("transition", {
    title: "Repair Café: prova locale del cambio di versione",
    needs: core[0].needs,
  }),
]);

export function workshopRequestId(actor, purpose) {
  if (!actor || !purpose)
    throw new Error("Workshop action requires actor and purpose.");
  const hex = createHash("sha256")
    .update(JSON.stringify(["tw05.v1", actor, purpose]))
    .digest("hex")
    .slice(0, 32);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20)}`;
}
export function workshopTimes(state, durationHours, now = new Date()) {
  assert.ok(
    Number.isFinite(now.getTime()) && durationHours > 0 && durationHours <= 12,
    "Valid Workshop clock and duration required.",
  );
  assert.ok(
    ["completed", "upcoming", "happening", "draft", "cancelled"].includes(
      state,
    ),
    "Unknown Workshop fixture state.",
  );
  const hours = state === "completed" ? -72 : state === "happening" ? -1 : 96;
  const startsAt = new Date(now.getTime() + hours * 3600000).toISOString();
  const endsAt = new Date(
    new Date(startsAt).getTime() + durationHours * 3600000,
  ).toISOString();
  return { startsAt, endsAt };
}
export function assertWorkshopInventory(definitions = WORKSHOP_SOURCES) {
  for (const field of ["key", "title", "coverVersion"])
    assert.equal(
      new Set(definitions.map((d) => d[field])).size,
      definitions.length,
      `Duplicate Workshop ${field}.`,
    );
  assert.equal(
    definitions.filter((d) => d.core).length,
    8,
    "Eight core templates required.",
  );
}
export async function workshopRpc(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error(`Workshop ${name} failed (code ${error.code}).`);
  return data;
}
const rpc = workshopRpc;
export async function workshopDenied(client, name, args, code) {
  const { error } = await client.rpc(name, args);
  assert.equal(error?.code, code, `${name} must fail explicitly.`);
}
const denied = workshopDenied;
function freeze(value) {
  if (value && typeof value === "object") {
    Object.freeze(value);
    for (const child of Object.values(value)) freeze(child);
  }
  return value;
}

export async function resolveWorkshopSources(
  context,
  { allowMissing = false } = {},
) {
  const result = {};
  for (const d of WORKSHOP_SOURCES) {
    const owner = context.personas[d.ownerKey];
    const matches =
      await context.sql`select p.id from public.proposals p where p.creator_profile_id=${owner.id} and p.title=${d.title}
        and not exists(select 1 from private.proposal_template_applications a where a.proposal_id=p.id)`;
    assert.ok(
      matches.length <= 1,
      `Duplicate Workshop source ${d.key}; explicit reset required.`,
    );
    const request = workshopRequestId(owner.id, `source:${d.key}`);
    const id = await rpc(owner.client, "recover_editor_proposal_draft", {
      p_expected_creator_profile_id: owner.id,
      p_client_request_id: request,
    });
    if (!id) {
      assert.equal(
        matches.length,
        0,
        `Unreceipted Workshop source ${d.key}; refuse ambiguous adoption.`,
      );
      if (allowMissing) continue;
      throw new Error(
        `Workshop source ${d.key} is missing; run the explicit seed on this disposable stack.`,
      );
    }
    const rows =
      await context.sql`select p.*, t.id as template_id, t.removed_at from public.proposals p left join private.proposal_templates t on t.source_proposal_id=p.id where p.id=${id} and p.creator_profile_id=${owner.id}`;
    assert.equal(
      rows.length,
      1,
      `Workshop source ${d.key} receipt destination unavailable.`,
    );
    result[d.key] = rows[0];
  }
  return result;
}
export async function workshopContent(context, id) {
  return (
    await context.sql`select private.proposal_template_reusable_content(${id}::uuid) as payload, private.proposal_template_content_version(private.proposal_template_reusable_content(${id}::uuid)) as token`
  )[0];
}
function proposalArgs(
  context,
  d,
  skillIds,
  times,
  description = d.description,
) {
  return {
    p_expected_creator_profile_id: context.personas[d.ownerKey].id,
    p_title: d.title,
    p_summary: d.summary,
    p_description: description,
    p_starts_at: times.startsAt,
    p_ends_at: times.endsAt,
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: d.locality,
    p_administrative_area: "Provincia autonoma di Trento",
    p_public_location_label: `${d.locality} · luogo sintetico`,
    p_exact_meeting_text: d.operational
      ? "TW05_MEETING_PRIVATE — punto di incontro sintetico, nessun domicilio reale"
      : "Spazio di quartiere sintetico da concordare",
    p_exact_location_visibility: "participants",
    p_skill_ids: skillIds,
    p_skill_importances: d.skillImportances,
    p_registration_capacity: d.capacity,
    p_count_organizers_toward_capacity: d.countOrganizers ?? false,
  };
}
export async function seedWorkshop(
  context,
  { now = new Date(), onCheckpoint } = {},
) {
  assertWorkshopInventory();
  const { sql, personas } = context;
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at) values(${personas.reviewer.id},'moderator',true,null) on conflict(profile_id) do nothing`;
  const existing = await resolveWorkshopSources(context, {
    allowMissing: true,
  });
  for (const d of WORKSHOP_SOURCES) {
    const owner = personas[d.ownerKey];
    const skillIds = await context.resolveSkillIds(owner.client, d.skillSlugs);
    let row = existing[d.key];
    if (!row) {
      const initial = workshopTimes("upcoming", d.durationHours, now);
      const id = await rpc(owner.client, "create_editor_proposal_draft", {
        ...proposalArgs(
          context,
          d,
          skillIds,
          initial,
          `Bozza locale originale: ${d.description}`,
        ),
        p_client_request_id: workshopRequestId(owner.id, `source:${d.key}`),
      });
      row = {
        id,
        lifecycle_state: "draft",
        description: `Bozza locale originale: ${d.description}`,
        starts_at: initial.startsAt,
        ends_at: initial.endsAt,
      };
    }
    if (row.lifecycle_state === "draft" && d.state !== "draft") {
      await context.ensureProjectCover(
        context,
        owner,
        row.id,
        d.coverAsset ? d : { ...d, coverAsset: null },
      );
      await reconcileNeeds(context, owner, row.id, d);
      await rpc(owner.client, "publish_proposal", {
        p_expected_creator_profile_id: owner.id,
        p_proposal_id: row.id,
      });
      row.lifecycle_state = "published";
    }
    if (
      d.state !== "draft" &&
      row.description === `Bozza locale originale: ${d.description}`
    ) {
      // Only the genuine initial phase can edit; a Completed fixture is never reopened by ordinary seed.
      await rpc(owner.client, "update_own_proposal", {
        ...proposalArgs(context, d, skillIds, {
          startsAt: new Date(row.starts_at).toISOString(),
          endsAt: new Date(row.ends_at).toISOString(),
        }),
        p_proposal_id: row.id,
      });
    }
    if (
      d.operational &&
      row.lifecycle_state === "published" &&
      new Date(row.starts_at) > now
    )
      await operationalSource(context, owner, row.id);
    if (d.state === "cancelled" && row.lifecycle_state === "published")
      await rpc(owner.client, "cancel_proposal", {
        p_expected_creator_profile_id: owner.id,
        p_proposal_id: row.id,
      });
    if (["completed", "happening", "upcoming"].includes(d.state)) {
      const status = (
        await sql`select private.derive_proposal_status(starts_at,ends_at,statement_timestamp()) as state from public.proposals where id=${row.id}`
      )[0].state;
      if (d.state !== "completed" || status !== "completed") {
        const times = workshopTimes(d.state, d.durationHours, now);
        await sql`update public.proposals set starts_at=${times.startsAt}, ends_at=${times.endsAt} where id=${row.id} and creator_profile_id=${owner.id}`;
      }
    }
  }
  const sources = await resolveWorkshopSources(context);
  await ensureCopy(context, sources.removed, "removed-copy", true, {
    edit: true,
    onCheckpoint,
  });
  await ensureCopy(context, sources.repair, "capacity-copy", true);
  await ensureCopy(context, sources.flowerbed, "optout-copy", false);
  await ensureCopy(context, sources.transition, "version-A-copy", true);
  await ensureRemoval(context, sources.removed);
  return sources;
}
async function reconcileNeeds(context, owner, projectId, d) {
  for (const n of d.needs) {
    const rows =
      await context.sql`select id,details,state from public.project_resource_needs where project_id=${projectId} and title=${n.title}`;
    assert.ok(rows.length <= 1, `Duplicate need on ${d.key}: ${n.title}.`);
    let id = rows[0]?.id;
    if (!id)
      id = await rpc(owner.client, "create_project_resource_need", {
        p_expected_creator_profile_id: owner.id,
        p_project_id: projectId,
        p_title: n.title,
        p_details: n.details,
      });
    else
      assert.equal(
        rows[0].details,
        n.details,
        `Need content drift on ${d.key}.`,
      );
    if (n.state === "closed" && rows[0]?.state !== "closed")
      await rpc(owner.client, "close_project_resource_need", {
        p_expected_creator_profile_id: owner.id,
        p_resource_need_id: id,
      });
  }
}
async function operationalSource(context, owner, id) {
  const [workspace] =
    await context.sql`select * from public.project_shared_workspaces where project_id=${id}`;
  if (!workspace)
    await rpc(owner.client, "set_project_shared_workspace", {
      p_expected_manager_profile_id: owner.id,
      p_project_id: id,
      p_workspace_url:
        "https://drive.google.com/drive/folders/TW05_WORKSPACE_SYNTHETIC",
    });
  await context.ensureCurrentMembership(
    context,
    context.personas.carla,
    owner,
    id,
    "Prova locale di partecipazione prima del completamento.",
  );
  const [chat] = await rpc(owner.client, "get_own_project_group_chat", {
    p_expected_profile_id: owner.id,
    p_project_id: id,
  });
  const messages =
    await context.sql`select id from public.project_chat_messages where chat_id=${chat.chat_id} and body='TW05_CHAT_PRIVATE — coordinamento sintetico'`;
  assert.ok(messages.length <= 1);
  if (!messages.length)
    await rpc(owner.client, "send_project_chat_message", {
      p_expected_profile_id: owner.id,
      p_chat_id: chat.chat_id,
      p_body: "TW05_CHAT_PRIVATE — coordinamento sintetico",
    });
}
export async function application(context, purpose) {
  const actor = context.personas.bob;
  return (
    await rpc(actor.client, "get_own_proposal_template_application", {
      p_expected_creator_profile_id: actor.id,
      p_client_request_id: workshopRequestId(actor.id, purpose),
    })
  )[0];
}
export function applyArgs(context, source, purpose, token, prefill = true) {
  const actor = context.personas.bob;
  return {
    p_expected_creator_profile_id: actor.id,
    p_template_id: source.template_id,
    p_content_version: token,
    p_client_request_id: workshopRequestId(actor.id, purpose),
    p_prefill_capacity: prefill,
  };
}
async function ensureCopy(
  context,
  source,
  purpose,
  prefill,
  { edit = false, onCheckpoint } = {},
) {
  let receipt = await application(context, purpose);
  if (!receipt) {
    const content = await workshopContent(context, source.id);
    [receipt] = await rpc(
      context.personas.bob.client,
      "create_proposal_draft_from_template",
      applyArgs(context, source, purpose, content.token, prefill),
    );
    if (onCheckpoint)
      await onCheckpoint({
        phase: "copy-committed",
        purpose,
        proposalId: receipt.proposal_id,
      });
  }
  if (edit) {
    const [draft] =
      await context.sql`select * from public.proposals where id=${receipt.proposal_id}`;
    if (draft.title === source.title) {
      assert.ok(
        new Date(draft.updated_at) <= new Date(receipt.accepted_at),
        "Owner-edited removed-copy cannot resume its seed edit; explicit reset required.",
      );
      const skills =
        await context.sql`select skill_id,importance from public.proposal_skills where proposal_id=${draft.id} order by skill_id`;
      await rpc(context.personas.bob.client, "update_own_proposal", {
        p_expected_creator_profile_id: context.personas.bob.id,
        p_proposal_id: draft.id,
        p_title: "La mia Repair Café: copia indipendente modificata",
        p_summary: draft.summary,
        p_description:
          draft.description +
          "\nAppunto privato della copia: organizzo i miei turni.",
        p_starts_at: null,
        p_ends_at: null,
        p_event_timezone: null,
        p_country_code: null,
        p_locality: null,
        p_administrative_area: null,
        p_public_location_label: null,
        p_exact_meeting_text: null,
        p_exact_location_visibility: "participants",
        p_skill_ids: skills.map((s) => s.skill_id),
        p_skill_importances: skills.map((s) => s.importance),
        p_registration_capacity: receipt.capacity_recommendation,
        p_count_organizers_toward_capacity: false,
      });
    }
  }
  return receipt;
}
async function ensureReport(context, source, actor, purpose) {
  const key = workshopRequestId(actor.id, purpose);
  const rows =
    await context.sql`select * from private.moderation_reports where reporter_profile_id=${actor.id} and client_submission_id=${key}`;
  assert.ok(rows.length <= 1);
  if (rows[0]) return rows[0];
  const [report] = await rpc(actor.client, "submit_moderation_report", {
    p_expected_reporter_profile_id: actor.id,
    p_client_submission_id: key,
    p_category: "other",
    p_explanation:
      "Esempio sintetico locale: verificare manualmente le istruzioni prima di riutilizzarle. La segnalazione non rimuove automaticamente il modello.",
    p_target_kind: "proposal_template",
    p_target_id: source.template_id,
    p_context_kind: null,
    p_context_id: null,
  });
  return report;
}
async function ensureRemoval(context, source) {
  const self = await ensureReport(
    context,
    source,
    context.personas.alice,
    "self-report",
  );
  await ensureReport(
    context,
    source,
    context.personas.carla,
    "ordinary-report",
  );
  const actor = context.personas.reviewer;
  const key = workshopRequestId(actor.id, "remove-template");
  const actions =
    await context.sql`select * from private.proposal_template_removal_actions where actor_profile_id=${actor.id} and client_request_id=${key}`;
  if (actions.length) return;
  const [review] = await rpc(actor.client, "get_moderation_case_template", {
    p_expected_staff_profile_id: actor.id,
    p_case_id: self.case_id,
  });
  assert.equal(
    review.publicly_available,
    true,
    "Reports alone leave the template available.",
  );
  await rpc(actor.client, "remove_moderation_case_template", {
    p_expected_staff_profile_id: actor.id,
    p_case_id: self.case_id,
    p_template_id: source.template_id,
    p_client_request_id: key,
    p_reviewed_content_version: review.current_content_version,
    p_reason:
      "Prova locale: modello dedicato rimosso dopo revisione manuale; nessun giudizio su persone o eventi reali.",
  });
}

export async function verifyWorkshop(context) {
  const { sql, anonymous, personas } = context;
  const sources = await resolveWorkshopSources(context);
  let checks = 0;
  const equal = (a, b, message) => {
    assert.ok(isDeepStrictEqual(a, b), message);
    checks++;
  };
  const catalog = [];
  let cursor = {};
  do {
    const page = await rpc(anonymous, "list_public_proposal_templates", {
      p_limit: 50,
      ...cursor,
    });
    catalog.push(...page);
    if (page.length < 50) break;
    const last = page.at(-1);
    cursor = {
      p_cursor_linked_at: last.linked_at,
      p_cursor_id: last.template_id,
    };
  } while (catalog.length < 1000);
  assert.ok(
    catalog.length < 1000,
    "Bounded demo catalog scan exceeded 1000 rows.",
  );
  for (const d of WORKSHOP_SOURCES) {
    const row = sources[d.key];
    const owner = personas[d.ownerKey];
    equal(
      row.title,
      d.title,
      `Source ${d.key} title drift; reset is explicit.`,
    );
    const expectedState =
      d.state === "draft"
        ? "draft"
        : d.state === "cancelled"
          ? "cancelled"
          : "published";
    equal(
      row.lifecycle_state,
      expectedState,
      `Source ${d.key} lifecycle drift.`,
    );
    equal(
      Boolean(row.template_id),
      d.state !== "draft",
      `${d.key} automatic identity.`,
    );
    const usable = d.state === "completed" && d.key !== "removed";
    equal(
      catalog.some((t) => t.template_id === row.template_id),
      usable,
      `${d.key} catalog eligibility.`,
    );
    if (d.state === "draft") continue;
    const baseline = await rpc(
      owner.client,
      "get_own_proposal_template_baseline",
      {
        p_expected_creator_profile_id: owner.id,
        p_template_id: row.template_id,
      },
    );
    equal(baseline.length, 1, `${d.key} genuine baseline.`);
    equal(
      baseline[0].description,
      `Bozza locale originale: ${d.description}`,
      `${d.key} immutable saved Bozza.`,
    );
    equal(row.description, d.description, `${d.key} final reusable text.`);
    equal(
      row.summary,
      d.key === "transition" &&
        row.summary === "Variante B: portiamo anche una lista dei materiali."
        ? row.summary
        : d.summary,
      `${d.key} reusable summary drift.`,
    );
    const content = await workshopContent(context, row.id);
    equal(
      content.payload.registration_capacity_recommendation,
      d.capacity,
      `${d.key} capacity recommendation drift.`,
    );
    equal(
      Number(content.payload.duration_seconds),
      d.durationHours * 3600,
      `${d.key} duration drift.`,
    );
    equal(
      content.payload.resource_blueprints.length,
      d.needs.filter((n) => n.state === "open").length,
      `${d.key} open-only needs.`,
    );
    const needs =
      await sql`select title,details,state from public.project_resource_needs where project_id=${row.id} order by title`;
    equal(
      Array.from(needs),
      [...d.needs]
        .sort((a, b) => a.title.localeCompare(b.title, "en"))
        .map((n) => ({ title: n.title, details: n.details, state: n.state })),
      `${d.key} finite needs inventory.`,
    );
    const selection =
      await sql`select s.slug,ps.importance from public.proposal_skills ps join public.skills s on s.id=ps.skill_id where ps.proposal_id=${row.id}`;
    equal(
      selection.map((s) => `${s.slug}:${s.importance}`).sort(),
      d.skillSlugs.map((s, i) => `${s}:${d.skillImportances[i]}`).sort(),
      `${d.key} controlled skills.`,
    );
    const detail = await rpc(anonymous, "get_public_proposal_template", {
      p_template_id: row.template_id,
    });
    equal(detail.length, usable ? 1 : 0, `${d.key} exact public detail.`);
    if (usable) {
      equal(
        detail[0].content_version,
        content.token,
        `${d.key} one public content projection.`,
      );
      equal(
        detail[0].resource_blueprint_count,
        d.needs.filter((n) => n.state === "open").length,
        `${d.key} public need count.`,
      );
      equal(
        detail[0].cover_object_path,
        d.coverAsset
          ? `${owner.id}/projects/${row.id}/${d.coverVersion}.webp`
          : null,
        `${d.key} canonical cover or honest placeholder.`,
      );
    }
    assert.doesNotMatch(
      JSON.stringify([...detail, content.payload]),
      /Bozza locale originale|TW05_MEETING_PRIVATE|TW05_CHAT_PRIVATE|TW05_WORKSPACE_SYNTHETIC/,
    );
    if (
      d.state === "completed" ||
      d.state === "happening" ||
      d.state === "upcoming"
    ) {
      equal(
        (
          await sql`select private.derive_proposal_status(starts_at,ends_at,statement_timestamp()) as status from public.proposals where id=${row.id}`
        )[0].status,
        d.state,
        `${d.key} canonical elapsed-time status.`,
      );
    }
  }
  // No contextual participant or staff exception for the original Creator's saved draft.
  for (const actor of [personas.bob, personas.carla, personas.reviewer])
    await denied(
      actor.client,
      "get_own_proposal_template_baseline",
      {
        p_expected_creator_profile_id: actor.id,
        p_template_id: sources.removed.template_id,
      },
      "42501",
    );
  equal(
    (
      await sql`select count(*)::int as count from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id where c.target_proposal_template_id=${sources.removed.template_id}`
    )[0].count,
    2,
    "Ordinary + Creator self-report, no duplicate effects.",
  );
  equal(
    (
      await sql`select count(*)::int as count from private.proposal_template_removal_actions where template_id=${sources.removed.template_id} and outcome='removed'`
    )[0].count,
    1,
    "One effective reviewed removal.",
  );
  equal(
    (
      await rpc(anonymous, "get_public_proposal", {
        p_proposal_id: sources.removed.id,
      })
    ).length,
    1,
    "Removal preserves public source.",
  );
  equal(
    await rpc(anonymous, "list_public_proposal_template_resource_blueprints", {
      p_template_id: sources.removed.template_id,
      p_content_version: (await workshopContent(context, sources.removed.id))
        .token,
    }),
    [],
    "Removed blueprints closed.",
  );
  for (const [purpose, key, prefill] of [
    ["removed-copy", "removed", true],
    ["capacity-copy", "repair", true],
    ["optout-copy", "flowerbed", false],
    ["version-A-copy", "transition", true],
  ]) {
    const receipt = await application(context, purpose);
    assert.ok(receipt, `Missing Workshop application ${purpose}.`);
    const src = sources[key];
    equal(
      receipt.source_proposal_id,
      src.id,
      `${purpose} immutable source relationship.`,
    );
    const [draft] =
      await sql`select p.*, pr.registration_capacity, pr.count_organizers_toward_capacity from public.proposals p join public.projects pr on pr.id=p.id where p.id=${receipt.proposal_id}`;
    equal(
      draft.creator_profile_id,
      personas.bob.id,
      `${purpose} independent Creator.`,
    );
    equal(draft.lifecycle_state, "draft", `${purpose} private draft.`);
    equal(
      draft.title,
      purpose === "removed-copy"
        ? "La mia Repair Café: copia indipendente modificata"
        : src.title,
      `${purpose} saved owner content.`,
    );
    equal(
      draft.registration_capacity,
      prefill ? receipt.capacity_recommendation : null,
      `${purpose} capacity opt-in.`,
    );
    equal(
      draft.count_organizers_toward_capacity,
      false,
      `${purpose} normal organizer default.`,
    );
    for (const field of [
      "starts_at",
      "ends_at",
      "country_code",
      "locality",
      "administrative_area",
      "public_location_label",
    ])
      equal(draft[field], null, `${purpose} reset ${field}.`);
    // Existing accepted demo copies may predate UI-NEXT-03; never rewrite them.
    equal(
      [null, "Europe/Rome"].includes(draft.event_timezone),
      true,
      `${purpose} retained legacy or new Italy zone.`,
    );
    const copied =
      await sql`select id,title,details,state from public.project_resource_needs where project_id=${draft.id} order by title`;
    const original =
      await sql`select id,title,details,state from public.project_resource_needs where project_id=${src.id} and state='open' order by title`;
    equal(
      copied.map(({ id, ...n }) => n),
      original.map(({ id, ...n }) => n),
      `${purpose} copied open text.`,
    );
    equal(
      copied.some((n) => original.some((s) => s.id === n.id)),
      false,
      `${purpose} fresh need identities.`,
    );
    const tables =
      await sql`select n.nspname as schema,c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid where n.nspname in ('public','private') and c.relkind='r' and a.attname='project_id' and c.relname<>'project_resource_needs'`;
    for (const table of tables)
      equal(
        (
          await sql`select count(*)::int as count from ${sql(table.schema + "." + table.name)} where project_id=${draft.id}`
        )[0].count,
        0,
        `${purpose} no inherited ${table.name}.`,
      );
    equal(
      await rpc(anonymous, "get_public_proposal", { p_proposal_id: draft.id }),
      [],
      `${purpose} not public.`,
    );
  }
  const match = (title, skills = [], locality = null) =>
    rpc(personas.bob.client, "list_similar_active_proposals", {
      p_expected_profile_id: personas.bob.id,
      p_title: title,
      p_skill_ids: skills,
      p_country_code: locality ? "IT" : null,
      p_locality: locality,
      p_excluded_proposal_id: null,
      p_limit: 5,
    });
  for (const [query, key] of [
    ["Murale di quartiere", "activeMural"],
    ["Aiuola condivisa", "activeFlowerbed"],
  ]) {
    equal(
      (await match(query)).some((r) => r.proposal_id === sources[key].id),
      true,
      `${key} topic-only admission.`,
    );
    const skills = await context.resolveSkillIds(
      personas.bob.client,
      WORKSHOP_SOURCES.find((s) => s.key === key).skillSlugs,
    );
    equal(
      (await match(query, skills, "Trento")).some(
        (r) => r.proposal_id === sources[key].id,
      ),
      true,
      `${key} tags + rough geography.`,
    );
  }
  const repair = await match(
    "Repair Café: aggiustiamo piccoli oggetti",
    [],
    "Trento",
  );
  const availableRepairs =
    await sql`select p.id from public.proposals p join auth.users u on u.id=p.creator_profile_id where u.email='demo-alice@planets.invalid' and p.title='Repair Café: aggiustiamo piccoli oggetti insieme' and not exists(select 1 from private.proposal_template_applications a where a.proposal_id=p.id)`;
  equal(
    availableRepairs.length,
    1,
    "Exact original Repair source is unambiguous.",
  );
  const [availableRepair] = availableRepairs;
  equal(
    repair.findIndex((r) => r.proposal_id === availableRepair.id) <
      repair.findIndex((r) => r.proposal_id === sources.fullRepair.id),
    true,
    "Comparable available candidate precedes Full in canonical server order.",
  );
  equal(
    repair.findIndex((r) => r.proposal_id === availableRepair.id) <
      repair.findIndex((r) => r.proposal_id === sources.broadRepair.id),
    true,
    "Local topic candidate precedes broader locality.",
  );
  const concert = await match("Concerto acustico");
  equal(
    concert.some((r) => r.proposal_id === sources.concert.id),
    false,
    "Completed concert excluded from upcoming suggestions.",
  );
  equal(
    concert.some((r) => r.title === "Concerto acustico nel cortile"),
    false,
    "Original Just Finished concert remains excluded.",
  );
  equal(
    repair.some(
      (r) =>
        r.proposal_id === sources.fullRepair.id && r.availability === "full",
    ),
    true,
    "Canonical Full candidate remains distinguishable.",
  );
  equal(
    repair.some((r) => r.proposal_id === sources.broadRepair.id),
    true,
    "Broader truthful locality admitted.",
  );
  equal(
    repair.some((r) =>
      [
        sources.draft.id,
        sources.happening.id,
        sources.cancelled.id,
        sources.repair.id,
        sources.removed.id,
      ].includes(r.proposal_id),
    ),
    false,
    "Upcoming exclusions.",
  );
  const broadSkills = await context.resolveSkillIds(personas.bob.client, [
    "basic-repairs",
  ]);
  equal(
    (await match("Repair Café", broadSkills, "Trento")).some(
      (r) => r.proposal_id === sources.unrelated.id,
    ),
    false,
    "Geography/skill alone do not admit unrelated title.",
  );
  equal(
    await match("Idea insieme"),
    [],
    "Weak idea is a legitimate empty result.",
  );
  const search = await rpc(anonymous, "list_public_proposal_templates", {
    p_query: "Aiuola condivisa",
    p_skill_ids: await context.resolveSkillIds(personas.bob.client, [
      "gardening",
    ]),
  });
  equal(
    search.some((r) => r.template_id === sources.flowerbed.template_id),
    true,
    "Workshop useful search and tag filtering.",
  );
  return { sources, checks };
}

export async function exerciseWorkshopTransition(context) {
  const sources = await resolveWorkshopSources(context);
  const src = sources.transition;
  const actor = context.personas.alice;
  const receiptA = await application(context, "version-A-copy");
  const d = WORKSHOP_SOURCES.find((s) => s.key === "transition");
  const versionB = "Variante B: portiamo anche una lista dei materiali.";
  if (src.summary !== versionB) {
    assert.equal(
      src.summary,
      d.summary,
      "Transition source drift; explicit reset required.",
    );
    // Dedicated local clock fixture only. Product APIs still prohibit Completed structural edits.
    const originalTimes = {
      startsAt: new Date(src.starts_at).toISOString(),
      endsAt: new Date(src.ends_at).toISOString(),
    };
    const future = workshopTimes("upcoming", d.durationHours);
    await context.sql`update public.proposals set starts_at=${future.startsAt},ends_at=${future.endsAt} where id=${src.id} and creator_profile_id=${actor.id}`;
    try {
      await rpc(actor.client, "update_own_proposal", {
        ...proposalArgs(
          context,
          d,
          await context.resolveSkillIds(actor.client, d.skillSlugs),
          future,
        ),
        p_proposal_id: src.id,
        p_summary: versionB,
      });
    } finally {
      await context.sql`update public.proposals set starts_at=${originalTimes.startsAt},ends_at=${originalTimes.endsAt} where id=${src.id} and creator_profile_id=${actor.id}`;
    }
  }
  const current = await workshopContent(context, src.id);
  assert.notEqual(
    current.token,
    receiptA.accepted_content_version,
    "Version B changes token.",
  );
  const replay = (
    await rpc(
      context.personas.bob.client,
      "create_proposal_draft_from_template",
      applyArgs(
        context,
        src,
        "version-A-copy",
        receiptA.accepted_content_version,
      ),
    )
  )[0];
  assert.equal(
    replay.proposal_id,
    receiptA.proposal_id,
    "Accepted exact retry preserves version A.",
  );
  const receiptB = await application(context, "version-B-copy");
  if (!receiptB) {
    await denied(
      context.personas.bob.client,
      "create_proposal_draft_from_template",
      applyArgs(
        context,
        src,
        "version-B-copy",
        receiptA.accepted_content_version,
      ),
      "PT409",
    );
    await rpc(
      context.personas.bob.client,
      "create_proposal_draft_from_template",
      applyArgs(context, src, "version-B-copy", current.token),
    );
  }
  const b = await application(context, "version-B-copy");
  assert.notEqual(b.proposal_id, receiptA.proposal_id);
  const copies =
    await context.sql`select id,summary from public.proposals where id=any(${[b.proposal_id, receiptA.proposal_id]}::uuid[])`;
  assert.equal(copies.find((p) => p.id === b.proposal_id).summary, versionB);
  assert.equal(
    copies.find((p) => p.id === receiptA.proposal_id).summary,
    d.summary,
  );
  const removed = sources.removed;
  const before = await application(context, "removed-copy");
  const recovered = (
    await rpc(
      context.personas.bob.client,
      "create_proposal_draft_from_template",
      applyArgs(
        context,
        removed,
        "removed-copy",
        before.accepted_content_version,
      ),
    )
  )[0];
  assert.equal(recovered.proposal_id, before.proposal_id);
  await denied(
    context.personas.bob.client,
    "create_proposal_draft_from_template",
    applyArgs(
      context,
      removed,
      "new-after-removal",
      before.accepted_content_version,
    ),
    "42501",
  );
  return { versionA: receiptA.proposal_id, versionB: b.proposal_id };
}

// Digest every product table, including full audit/outbox/report/application history.
// Only clock-refresh fields in known tables are excluded; authentication is in auth schema.
export async function snapshotDemoDomain(sql) {
  const clocks =
    await sql`select p.id from public.proposals p join auth.users u on u.id=p.creator_profile_id
    where not exists(select 1 from private.proposal_template_applications a where a.proposal_id=p.id)
    and (u.email='demo-alice@planets.invalid' and p.title=any(${[
      "Coloriamo insieme il muro del sottopasso",
      "Repair Café: aggiustiamo piccoli oggetti insieme",
      "Concerto acustico nel cortile",
      "Prepariamo insieme le cassette per l'orto",
      "Piccolo banco di riparazione — posti esauriti",
      ...WORKSHOP_SOURCES.filter((d) =>
        ["upcoming", "happening"].includes(d.state),
      ).map((d) => d.title),
    ]}::text[]))`;
  const tables =
    await sql`select n.nspname||'.'||c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r' order by 1`;
  const snapshot = {};
  for (const { name } of tables) {
    const [{ rows }] =
      name === "public.proposals"
        ? await sql`select coalesce(jsonb_agg(content order by content::text),'[]'::jsonb) as rows from (select case when id=any(${clocks.map((c) => c.id)}::uuid[]) then to_jsonb(t)-array['starts_at','ends_at','updated_at'] else to_jsonb(t) end as content from public.proposals t) s`
        : await sql`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) as rows from ${sql(name)} t`;
    snapshot[name] = {
      count: rows.length,
      sha256: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
    };
  }
  return snapshot;
}
