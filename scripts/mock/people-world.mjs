import { operationId, rpc } from "./world.mjs";

// Only imported by the guarded mock operator. Canonical RPCs own all community,
// attendance and chat state. Receipts preserve subsequent tester changes.
export const PEOPLE_TOPICS = Object.freeze([
  ["videogames", "Valorant"],
  ["videogames", "Minecraft"],
  ["boardgames", "Lupus in Fabula"],
  ["boardgames", "Catan"],
  ["concerts", "Rock"],
  ["concerts", "Techno"],
  ["sports", "Running"],
  ["travel", "China"],
  ["art", "Cucinare"],
  ["art", "Sewing 🧵"],
  ["art", "Drawing"],
]);
export async function seedPeopleWorld(context, people, once, at) {
  await context.guard();
  const { sql } = context;
  // Independent confirmed mock target; ordinary/local-demo seed never calls here.
  await sql`update private.cocreate_settings set enabled=true`;
  const members = [people.luca, people.maya, people.nora, people.teo];
  const hubs = [];
  for (const [index, [category, name]] of PEOPLE_TOPICS.entries()) {
    const key = `people:${category}:${name}`;
    const owner = members[index % members.length];
    const proposed = await once(`${key}:proposal`, () =>
      rpc(owner, "propose_cocreate_community", {
        p_expected_profile_id: owner.id,
        p_command_id: operationId(`${key}:proposal`),
        p_category_id: category,
        p_name: name,
        p_locality: "Trento · Mock",
        p_explanation:
          "Comunità di persone immaginarie per provare incontri e chat.",
      }),
    );
    let hub = proposed.hub_id;
    if (!hub) {
      for (const supporter of members
        .filter((p) => p.id !== owner.id)
        .slice(0, 2)) {
        const result = await once(`${key}:interest:${supporter.key}`, () =>
          rpc(supporter, "mutate_cocreate_community_interest", {
            p_expected_profile_id: supporter.id,
            p_command_id: operationId(`${key}:interest:${supporter.key}`),
            p_proposal_id: proposed.proposal_id,
            p_operation: "interest",
          }),
        );
        hub = result.hub_id ?? hub;
      }
    }
    if (!hub)
      throw Error(
        "Mock community did not activate through three distinct interests.",
      );
    const episodes = {};
    for (const person of members)
      episodes[person.key] = await once(`${key}:hub:${person.key}`, () =>
        rpc(person, "mutate_cocreate_hub", {
          p_expected_profile_id: person.id,
          p_command_id: operationId(`${key}:hub:${person.key}`),
          p_hub_id: hub,
          p_operation: "join",
        }),
      );
    const meeting = await once(`${key}:meeting`, () =>
      rpc(owner, "schedule_cocreate_meeting", {
        p_expected_profile_id: owner.id,
        p_command_id: operationId(`${key}:meeting`),
        p_hub_id: hub,
        p_starts_at: at(3 + index, index % 2 === 0 ? 18 : 20),
        p_capacity: index === 0 ? 7 : index === 2 ? 3 : 5,
      }),
    );
    for (const person of members
      .filter((p) => p.id !== owner.id)
      .slice(0, index === 0 ? 3 : index === 2 ? 2 : 1)) {
      await once(`${key}:meeting:${person.key}`, () =>
        rpc(person, "join_cocreate_recruitment", {
          p_expected_profile_id: person.id,
          p_command_id: operationId(`${key}:meeting:${person.key}`),
          p_hub_id: hub,
          p_room_id: meeting.room_id,
          p_recruitment_id: meeting.recruitment_id,
        }),
      );
    }
    await once(`${key}:general-message`, () =>
      rpc(owner, "send_cocreate_room_message", {
        p_expected_profile_id: owner.id,
        p_command_id: operationId(`${key}:general-message`),
        p_room_id: episodes[owner.key].room_id,
        p_episode_id: episodes[owner.key].episode_id,
        p_body:
          "La richiesta indica data, ora e posti. Unisciti per partecipare e aprire la chat del gruppo.",
      }),
    );
    await once(`${key}:group-message`, () =>
      rpc(owner, "send_cocreate_room_message", {
        p_expected_profile_id: owner.id,
        p_command_id: operationId(`${key}:group-message`),
        p_room_id: meeting.room_id,
        p_episode_id: meeting.episode_id,
        p_body:
          "Questa chat resta disponibile anche dopo l’incontro, per organizzarci di nuovo.",
      }),
    );
    hubs.push({ category, name, hub, meeting: meeting.meeting_id });
  }
  // Own-interest and ready-to-join scenarios. Iris supports without enrollment.
  const pending = await once("people:pending-proposal", () =>
    rpc(people.iris, "propose_cocreate_community", {
      p_expected_profile_id: people.iris.id,
      p_command_id: operationId("people:pending-proposal"),
      p_category_id: "art",
      p_name: "Watercolour · Mock",
      p_locality: "Trento · Mock",
      p_explanation: "Una proposta ancora in attesa di persone interessate.",
    }),
  );
  await once("people:pending-interest", () =>
    rpc(people.nora, "mutate_cocreate_community_interest", {
      p_expected_profile_id: people.nora.id,
      p_command_id: operationId("people:pending-interest"),
      p_proposal_id: pending.proposal_id,
      p_operation: "interest",
    }),
  );
  for (let n = 0; n < 100; n++) {
    const [result] =
      await sql`select * from public.process_notification_outbox_batch(100)`;
    if (result.processed_count === 0)
      return { hubs: hubs.length, pending: pending.proposal_id };
  }
  throw Error(
    "Mock filling notification projection exceeded its bounded drain.",
  );
}
