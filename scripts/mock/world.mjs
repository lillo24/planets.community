import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { operator } from "./operator.mjs";

export const PERSONAS = Object.freeze(
  [
    {
      key: "giulia",
      name: "Giulia",
      id: "81000000-0000-4000-8000-000000000001",
      asset: "giulia.webp",
      scenario: "Group and Project organizing scenarios.",
    },
    {
      key: "marco",
      name: "Marco",
      id: "81000000-0000-4000-8000-000000000002",
      asset: "marco.webp",
      scenario: "Repairs, exchange and delegated organizing scenarios.",
    },
    {
      key: "sara",
      name: "Sara",
      id: "81000000-0000-4000-8000-000000000003",
      asset: "sara.webp",
      scenario: "Creative activities, member conversations and Ideas.",
    },
    {
      key: "dario",
      name: "Dario",
      id: "81000000-0000-4000-8000-000000000004",
      asset: null,
      scenario: "Photo-free invitation and participation scenarios.",
    },
    {
      key: "elena",
      name: "Elena",
      id: "81000000-0000-4000-8000-000000000005",
      asset: "sara.webp",
      scenario: "Discovery and explicit first-join scenarios.",
    },
    {
      key: "luca",
      name: "Luca",
      id: "82000000-0000-4000-8000-000000000001",
      asset: "giulia.webp",
      dataset: "people",
      scenario: "Organize Valorant meetings and ask General for a filling.",
    },
    {
      key: "maya",
      name: "Maya",
      id: "82000000-0000-4000-8000-000000000002",
      asset: "marco.webp",
      dataset: "people",
      scenario:
        "Join a meeting and its persistent group chat; organize board games.",
    },
    {
      key: "nora",
      name: "Nora",
      id: "82000000-0000-4000-8000-000000000003",
      asset: "sara.webp",
      dataset: "people",
      scenario:
        "Running, travel and creative meetings; pending community interests.",
    },
    {
      key: "teo",
      name: "Teo",
      id: "82000000-0000-4000-8000-000000000004",
      asset: null,
      dataset: "people",
      scenario: "Join, free a meeting place and remain in the group chat.",
    },
    {
      key: "iris",
      name: "Iris",
      id: "82000000-0000-4000-8000-000000000005",
      asset: "sara.webp",
      dataset: "people",
      scenario:
        "Newcomer: browse categories, explicitly join General, then a meeting.",
    },
  ].map((p) =>
    Object.freeze({
      dataset: "activities",
      ...p,
      email: `${p.key}@personas.planets.invalid`,
    }),
  ),
);

export function operationId(key) {
  const hex = createHash("sha256")
    .update(`mock-world-2026-10-21-v1/${key}`)
    .digest("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}
export async function rpc(person, name, args = {}) {
  const { data, error } = await person.client.rpc(name, args);
  if (error)
    throw new Error(
      `Mock fixture ${name} failed (${error.code ?? "unknown"}).`,
    );
  return data;
}
const expected = (p) => ({ p_expected_profile_id: p.id });

function authFailure(message, code, error) {
  return Object.assign(new Error(message), {
    code,
    authCode: /^[a-z_]{1,40}$/.test(error?.code ?? "") ? error.code : null,
    authStatus: Number.isInteger(error?.status) ? error.status : null,
  });
}

export async function personaSessions(context, { provision = false } = {}) {
  const people = {};
  const admin = context.admin();
  for (const definition of PERSONAS) {
    await context.guard();
    const [registered] =
      await context.sql`select * from mock_control.personas where persona_key=${definition.key}`;
    const { data, error } = await admin.auth.admin.getUserById(definition.id);
    let user = data?.user;
    if (!user) {
      if (!provision || registered || error?.status !== 404)
        throw authFailure(
          "Registered mock Auth user missing; manual recovery required.",
          "MOCK_AUTH_LOOKUP_FAILED",
          error,
        );
      const created = await admin.auth.admin.createUser({
        id: definition.id,
        email: definition.email,
        email_confirm: true,
      });
      if (created.error || created.data.user?.id !== definition.id)
        throw authFailure(
          "Exact synthetic Auth provisioning failed.",
          "MOCK_AUTH_CREATE_FAILED",
          created.error,
        );
      user = created.data.user;
    }
    if (
      user.id !== definition.id ||
      user.email !== definition.email ||
      (registered &&
        (registered.user_id !== definition.id ||
          registered.email !== definition.email))
    )
      throw authFailure(
        "Persona registry drift; no account adoption allowed.",
        "MOCK_AUTH_IDENTITY_DRIFT",
      );
    // Standard one-time Auth exchange, no reusable password or real email.
    const link = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: definition.email,
    });
    if (link.error || link.data.user.id !== definition.id)
      throw authFailure(
        "Mock one-time login preparation failed.",
        "MOCK_AUTH_LINK_FAILED",
        link.error,
      );
    const client = context.client();
    const login = await client.auth.verifyOtp({
      type: "magiclink",
      token_hash: link.data.properties.hashed_token,
    });
    if (login.error || login.data.user?.id !== definition.id)
      throw authFailure(
        "Mock standard Auth exchange failed.",
        "MOCK_AUTH_VERIFY_FAILED",
        login.error,
      );
    people[definition.key] = { ...definition, client };
  }
  return people;
}

export async function seed(context) {
  await context.guard();
  const { sql } = context;
  // One operator at a time; never disable triggers or reset the shared world.
  const lock = await sql.reserve();
  await lock`select pg_advisory_lock(684026240991819)`;
  let people;
  try {
    people = await personaSessions(context, { provision: true });
    const [marker] =
      await sql`select anchored_at from mock_control.environment where singleton`;
    const anchor = new Date(marker.anchored_at);
    const at = (days, hours = 0) =>
      new Date(anchor.getTime() + (days * 24 + hours) * 3600000).toISOString();
    async function once(key, action) {
      const [saved] =
        await sql`select receipt from mock_control.fixtures where fixture_key=${key}`;
      if (saved) return saved.receipt;
      await context.guard();
      const receipt = await action();
      const id =
        typeof receipt === "string" && /^[0-9a-f-]{36}$/i.test(receipt)
          ? receipt
          : operationId(key);
      await sql`insert into mock_control.fixtures(fixture_key,object_id,initial_digest,receipt)
        values(${key},${id}::uuid,${createHash("sha256").update(JSON.stringify(receipt)).digest("hex")},${sql.json(receipt)})`;
      return receipt;
    }
    for (const person of Object.values(people)) {
      await once(`profile:${person.key}`, async () => {
        const { data, error } = await person.client
          .from("profiles")
          .select("id,display_name")
          .eq("id", person.id)
          .maybeSingle();
        if (error) throw new Error("Read own mock profile failed.");
        if (!data) {
          const insert = await person.client
            .from("profiles")
            .insert({ id: person.id });
          if (insert.error)
            throw new Error("Create own mock profile anchor failed.");
        } else if (data.display_name)
          throw new Error(
            "Unreceipted profile content; explicit operator review required.",
          );
        await rpc(person, "update_own_profile", {
          ...expected(person),
          p_display_name: person.name,
          p_bio:
            "Profilo di una persona immaginaria per provare attività di quartiere.",
          p_skill_ids: [],
          p_display_name_audience: "public",
          p_bio_audience: "public",
          p_skills_audience: "public",
        });
        await rpc(person, "accept_policy_bundle", {
          p_expected_account_id: person.id,
          p_bundle_version: "POLICY01-2026-10-08-v1",
        });
        return person.id;
      });
      if (person.asset)
        await once(`avatar:${person.key}`, async () => {
          const object = `${person.id}/${operationId(`avatar:${person.key}`)}.webp`;
          const bytes = await readFile(
            `scripts/demo-assets/profiles/${person.asset}`,
          );
          const upload = await person.client.storage
            .from("profile-photos")
            .upload(object, bytes, {
              contentType: "image/webp",
              upsert: false,
            });
          if (
            upload.error &&
            !["KeyAlreadyExists", "Duplicate"].includes(
              upload.error.error ?? upload.error.code,
            )
          )
            throw new Error("Mock avatar upload failed.");
          await rpc(person, "set_own_profile_photo", {
            ...expected(person),
            p_object_path: object,
            p_audience: "interactions",
          });
          return object;
        });
      await sql`insert into mock_control.personas(persona_key,user_id,email,display_name,scenario,dataset)
        values(${person.key},${person.id}::uuid,${person.email},${person.name},${person.scenario},${person.dataset}) on conflict(persona_key) do nothing`;
    }
    const { giulia, marco, sara, dario } = people;
    async function group(key, owner, name) {
      const id = await once(`group:${key}`, () =>
        rpc(owner, "create_group_draft", {
          ...expected(owner),
          p_client_request_id: operationId(`group:${key}`),
          p_content: {
            name,
            description:
              "Una comunità immaginaria per organizzare piccoli progetti insieme.",
            group_kind: "informal",
            locality: "Trento",
            volunteering_focus: true,
          },
        }),
      );
      await once(`group:${key}:publish`, () =>
        rpc(owner, "set_group_publication_state", {
          ...expected(owner),
          p_client_request_id: operationId(`group:${key}:publish`),
          p_group_id: id,
          p_expected_version: 1,
          p_publication_state: "published",
        }),
      );
      return id;
    }
    const garden = await group("garden", giulia, "Orto del quartiere");
    const workshop = await group("workshop", marco, "Officina delle idee");
    async function delegate(owner, person, groupId, role) {
      const key = `delegate:${groupId}:${person.key}`;
      const [invitation] = await once(key + ":invite", () =>
        rpc(owner, "create_group_authority_invitation", {
          ...expected(owner),
          p_client_request_id: operationId(key + ":invite"),
          p_group_id: groupId,
          p_role: role,
        }),
      );
      await once(key + ":accept", () =>
        rpc(person, "accept_group_authority_invitation", {
          ...expected(person),
          p_client_request_id: operationId(key + ":accept"),
          p_token: invitation.invite_token,
        }),
      );
    }
    async function member(owner, person, groupId) {
      const key = `member:${groupId}:${person.key}`;
      const [invitation] = await once(key + ":invite", () =>
        rpc(owner, "create_group_participant_invitation", {
          ...expected(owner),
          p_client_request_id: operationId(key + ":invite"),
          p_group_id: groupId,
        }),
      );
      await once(key + ":accept", () =>
        rpc(person, "accept_group_participant_invitation", {
          ...expected(person),
          p_client_request_id: operationId(key + ":accept"),
          p_token: invitation.invite_token,
        }),
      );
    }
    await delegate(giulia, marco, garden, "co_creator");
    await delegate(giulia, sara, garden, "co_organizer");
    await member(giulia, sara, garden);
    await member(giulia, dario, garden);
    await delegate(marco, people.elena, workshop, "co_organizer");
    await member(marco, sara, workshop);
    const roomResult = await once("idea:garden", () =>
      rpc(giulia, "create_group_discussion_v2", {
        ...expected(giulia),
        p_client_request_id: operationId("idea:garden"),
        p_group_id: garden,
        p_title: "Progettiamo le cassette per le erbe",
        p_purpose:
          "Scegliamo insieme materiali e tempi per una piccola attività.",
        p_visibility: "group",
      }),
    );
    const room = Array.isArray(roomResult)
      ? roomResult[0].room_id
      : roomResult.room_id;
    await once("idea:garden:join", () =>
      rpc(sara, "join_group_discussion", {
        ...expected(sara),
        p_room_id: room,
        p_client_request_id: operationId("idea:garden:join"),
      }),
    );
    await once("idea:garden:message", () =>
      rpc(giulia, "send_group_discussion_message", {
        ...expected(giulia),
        p_room_id: room,
        p_client_request_id: operationId("idea:garden:message"),
        p_body:
          "Possiamo iniziare con due cassette di legno e un elenco di erbe.",
      }),
    );
    const location = {
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Provincia autonoma di Trento",
      p_public_location_label: "Trento · Povo",
    };
    async function cover(key, owner, id, kind, asset) {
      return once(`cover:${key}`, async () => {
        const object = `${owner.id}/${kind === "project" ? "projects" : "resources"}/${id}/${operationId(`cover:${key}`)}.webp`;
        const upload = await owner.client.storage
          .from("cover-images")
          .upload(
            object,
            await readFile(`scripts/demo-assets/covers/${asset}`),
            { contentType: "image/webp", upsert: false },
          );
        if (
          upload.error &&
          !["KeyAlreadyExists", "Duplicate"].includes(
            upload.error.error ?? upload.error.code,
          )
        )
          throw new Error("Mock cover upload failed.");
        await rpc(
          owner,
          kind === "project"
            ? "set_own_project_cover"
            : "set_own_resource_listing_cover",
          {
            ...(kind === "project"
              ? { p_expected_creator_profile_id: owner.id, p_project_id: id }
              : { p_expected_owner_profile_id: owner.id, p_listing_id: id }),
            p_object_path: object,
          },
        );
        return object;
      });
    }
    async function proposal(key, title, offset) {
      const id = await once(`proposal:${key}`, () =>
        rpc(giulia, "create_editor_proposal_draft", {
          p_expected_creator_profile_id: giulia.id,
          p_client_request_id: operationId(`proposal:${key}`),
          p_title: title,
          p_summary: "Un piccolo progetto immaginario da realizzare insieme.",
          p_description:
            "Prepariamo i materiali e dividiamo il lavoro in un incontro di quartiere.",
          p_starts_at: at(offset),
          p_ends_at: at(offset, 3),
          p_event_timezone: "Europe/Rome",
          ...location,
          p_exact_meeting_text: "Laboratorio immaginario nel quartiere",
          p_exact_location_visibility: "participants",
          p_skill_ids: [],
          p_skill_importances: [],
          p_registration_capacity: 12,
          p_count_organizers_toward_capacity: false,
        }),
      );
      await cover(
        key,
        giulia,
        id,
        "project",
        key === "garden" ? "mural.webp" : "repair-cafe.webp",
      );
      await once(`proposal:${key}:publish`, () =>
        rpc(giulia, "publish_proposal", {
          p_expected_creator_profile_id: giulia.id,
          p_proposal_id: id,
        }),
      );
      return id;
    }
    const project = await proposal(
      "garden",
      "Costruiamo le cassette per le erbe",
      14,
    );
    const history = await proposal(
      "history",
      "Una mattina per sistemare il cortile",
      7,
    );
    await once("history:clock", async () => {
      // Narrow, traced fixture clock only, after genuine creation/publication.
      // Product triggers remain enabled; never rewrite this clock on repeat seed.
      await sql.begin(async (tx) => {
        await context.guard(tx);
        await tx`update public.proposals set starts_at=${at(-3)},ends_at=${at(-3, 3)} where id=${history}::uuid and creator_profile_id=${giulia.id}::uuid`;
        await tx`insert into private.audit_events(action,actor_user_id,target_type,target_id,metadata)
          values('mock.fixture.history_clock',${giulia.id}::uuid,'proposal',${history}::uuid,'{"generation":"mock-world-2026-10-21-v1"}'::jsonb)`;
      });
      return history;
    });
    const tavolo = await once("tavolo:repair", () =>
      rpc(marco, "create_editor_recurring_activity_draft", {
        p_expected_creator_profile_id: marco.id,
        p_client_request_id: operationId("tavolo:repair"),
        p_title: "Repair Café del sabato",
        p_summary: "Piccole riparazioni tra vicini.",
        p_description:
          "Un Tavolo immaginario per capire come riparare piccoli oggetti.",
        p_topic: "Riparazioni",
        ...location,
        p_exact_meeting_text: "Sala immaginaria del laboratorio",
        p_exact_location_visibility: "participants",
        p_recurrence_type: "weekly",
        p_weekday: 6,
        p_day_of_month: null,
        p_local_start_time: "15:00:00",
        p_duration_minutes: 90,
        p_event_timezone: "Europe/Rome",
        p_effective_from: at(1).slice(0, 10),
        p_registration_capacity: 12,
        p_count_organizers_toward_capacity: false,
      }),
    );
    await once("tavolo:repair:publish", () =>
      rpc(marco, "publish_recurring_activity", {
        p_expected_creator_profile_id: marco.id,
        p_recurring_activity_id: tavolo,
      }),
    );
    await cover("tavolo", marco, tavolo, "project", "repair-cafe.webp");
    for (const [key, mode, title] of [
      ["donation", "donate", "Vasi per nuove piante"],
      ["exchange", "exchange", "Attrezzi da condividere"],
    ]) {
      const id = await once(`listing:${key}`, () =>
        rpc(marco, "create_editor_resource_listing_draft", {
          p_expected_owner_profile_id: marco.id,
          p_client_request_id: operationId(`listing:${key}`),
          p_listing_mode: mode,
          p_title: title,
          p_description:
            "Risorsa immaginaria per provare una richiesta senza pagamenti.",
          ...location,
        }),
      );
      await once(`listing:${key}:publish`, () =>
        rpc(marco, "publish_resource_listing", {
          p_expected_owner_profile_id: marco.id,
          p_listing_id: id,
        }),
      );
      await cover(`listing:${key}`, marco, id, "resource", "repair-cafe.webp");
    }
    for (const person of [marco, sara]) {
      const key = `participation:${person.key}`;
      const requestId = await once(key, () =>
        rpc(person, "request_to_join_project", {
          p_expected_requester_profile_id: person.id,
          p_project_id: project,
          p_request_message: "Posso aiutare con i materiali.",
        }),
      );
      if (person === sara)
        await once(key + ":accept", () =>
          rpc(giulia, "accept_project_join_request", {
            p_expected_creator_profile_id: giulia.id,
            p_request_id: requestId,
          }),
        );
    }
    await once("project:message", async () => {
      const [chat] = await rpc(giulia, "get_own_project_group_chat", {
        ...expected(giulia),
        p_project_id: project,
      });
      return rpc(giulia, "send_project_chat_message", {
        ...expected(giulia),
        p_chat_id: chat.chat_id,
        p_body: "Dividiamo il lavoro: disegno, materiali e montaggio.",
      });
    });
    await once("project:link", () =>
      rpc(giulia, "save_project_workspace_link", {
        p_expected_manager_profile_id: giulia.id,
        p_project_id: project,
        p_client_request_id: operationId("project:link"),
        p_display_name: "Materiali per le cassette",
        p_workspace_url: "https://example.com/fictional-garden-materials",
      }),
    );
    const contact = await once("contact:groups", () =>
      rpc(giulia, "submit_group_contact_request", {
        ...expected(giulia),
        p_action_id: operationId("contact:groups"),
        p_source_group_id: garden,
        p_target_group_id: workshop,
        p_purpose: "collaboration",
        p_title: "Cassette e piccoli attrezzi",
        p_note: "Possiamo progettare insieme un laboratorio immaginario?",
      }),
    );
    const chat = await once("contact:groups:accept", () =>
      rpc(marco, "accept_group_contact_request", {
        ...expected(marco),
        p_action_id: operationId("contact:groups:accept"),
        p_request_id: contact.request_id,
      }),
    );
    await once("contact:groups:message", () =>
      rpc(giulia, "send_group_contact_message", {
        ...expected(giulia),
        p_action_id: operationId("contact:groups:message"),
        p_chat_id: chat.chat_id,
        p_body: "Proponiamo un incontro per scegliere i materiali.",
      }),
    );
    const memberContact = await once("contact:members", () =>
      rpc(dario, "submit_member_contact_request", {
        ...expected(dario),
        p_action_id: operationId("contact:members"),
        p_group_id: garden,
        p_recipient_profile_id: sara.id,
        p_note: "Possiamo confrontarci sulle cassette per le erbe?",
      }),
    );
    const memberChat = await once("contact:members:accept", () =>
      rpc(sara, "accept_member_contact_request", {
        ...expected(sara),
        p_action_id: operationId("contact:members:accept"),
        p_request_id: memberContact.request_id,
      }),
    );
    await once("contact:members:message", () =>
      rpc(dario, "send_member_contact_message", {
        ...expected(dario),
        p_action_id: operationId("contact:members:message"),
        p_chat_id: memberChat.chat_id,
        p_episode_id: memberChat.episode_id,
        p_body: "Porterò il disegno delle cassette.",
      }),
    );
    const { seedPeopleWorld } = await import("./people-world.mjs");
    const coCreation = await seedPeopleWorld(context, people, once, at);
    return {
      personas: PERSONAS.length,
      groups: 2,
      project,
      tavolo,
      history,
      coCreation,
    };
  } finally {
    if (people)
      for (const person of Object.values(people))
        await person.client.auth.signOut({ scope: "local" });
    await lock`select pg_advisory_unlock(684026240991819)`;
    lock.release();
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  let context;
  try {
    context = await operator(process.argv[2]);
    await seed(context);
    console.log(
      "Mock seed completed; existing fixture receipts and tester changes preserved.",
    );
  } catch {
    console.error(
      "Mock seed failed; inspect target and canonical fixture requirements. No credentials logged.",
    );
    process.exitCode = 1;
  } finally {
    await context?.sql.end();
  }
}
