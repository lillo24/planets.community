import assert from "node:assert/strict";
import test from "node:test";
import {
  WORKSHOP_SOURCES,
  assertWorkshopInventory,
  workshopRequestId,
  workshopTimes,
  seedWorkshop,
} from "./demo-workshop.mjs";

test("Workshop has eight public core sources and separate destructive fixtures", () => {
  assertWorkshopInventory();
  assert.equal(WORKSHOP_SOURCES.length, 18);
  assert.ok(
    WORKSHOP_SOURCES.filter((s) => s.core).every(
      (s) =>
        s.state === "completed" && !["removed", "transition"].includes(s.key),
    ),
  );
  assert.ok(Object.isFrozen(WORKSHOP_SOURCES[0].needs));
  assert.throws(
    () => assertWorkshopInventory([...WORKSHOP_SOURCES, WORKSHOP_SOURCES[0]]),
    /Duplicate/,
  );
});
test("requests are deterministic, actor/purpose scoped and valid UUIDs", () => {
  const key = workshopRequestId("alice", "source:repair");
  assert.equal(key, workshopRequestId("alice", "source:repair"));
  assert.notEqual(key, workshopRequestId("bob", "source:repair"));
  assert.notEqual(key, workshopRequestId("alice", "removed-copy"));
  assert.match(
    key,
    /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-8[a-f0-9]{3}-[a-f0-9]{12}$/,
  );
  assert.throws(() => workshopRequestId("", "repair"), /requires/);
});
test("seed sends an approximate public label and keeps private fixture instructions", async () => {
  const source = WORKSHOP_SOURCES[0];
  let created;
  const stop = new Error("Captured creation; no database writes");
  const client = {
    async rpc(name, args) {
      if (name === "recover_editor_proposal_draft")
        return { data: null, error: null };
      assert.equal(name, "create_editor_proposal_draft");
      created = args;
      throw stop;
    },
  };
  const personas = Object.fromEntries(
    ["reviewer", ...WORKSHOP_SOURCES.map((s) => s.ownerKey)].map((key) => [
      key,
      { id: `synthetic-${key}`, client },
    ]),
  );
  await assert.rejects(
    seedWorkshop({
      sql: async () => [],
      personas,
      resolveSkillIds: async () => ["synthetic-skill"],
    }),
    (error) => error === stop,
  );
  assert.equal(
    created.p_public_location_label,
    `${source.locality}, zona indicativa`,
  );
  assert.doesNotMatch(
    created.p_public_location_label,
    /TW05_|sintetico|PRIVATE/,
  );
  assert.equal(created.p_locality, source.locality);
  assert.equal(created.p_exact_location_visibility, "participants");
  assert.equal(
    created.p_exact_meeting_text,
    source.operational
      ? "TW05_MEETING_PRIVATE — punto di incontro sintetico, nessun domicilio reale"
      : "Spazio di quartiere sintetico da concordare",
  );
  assert.equal(
    created.p_client_request_id,
    workshopRequestId(personas[source.ownerKey].id, `source:${source.key}`),
  );
});
test("Completed has comfortable elapsed-hour margins across Rome DST", () => {
  for (const instant of ["2026-03-29T01:15:00Z", "2026-10-25T01:15:00Z"]) {
    const now = new Date(instant);
    const times = workshopTimes("completed", 3, now);
    assert.equal(now - new Date(times.endsAt), 69 * 3600000);
    assert.equal(
      new Date(times.endsAt) - new Date(times.startsAt),
      3 * 3600000,
    );
    const upcoming = workshopTimes("upcoming", 3, now);
    assert.equal(new Date(upcoming.startsAt) - now, 96 * 3600000);
    const happening = workshopTimes("happening", 3, now);
    assert.ok(
      new Date(happening.startsAt) < now && new Date(happening.endsAt) > now,
    );
  }
  assert.throws(() => workshopTimes("completed", 3, new Date("bad")), /Valid/);
  assert.throws(() => workshopTimes("finished", 3), /Unknown/);
});
