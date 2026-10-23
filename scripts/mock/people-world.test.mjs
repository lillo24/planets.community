import test from "node:test";
import assert from "node:assert/strict";
import { PERSONAS } from "./world.mjs";
import { PEOPLE_TOPICS } from "./people-world.mjs";

test("mock presentation catalogs have distinct synthetic login identities", () => {
  const activities = PERSONAS.filter((p) => p.dataset === "activities");
  const people = PERSONAS.filter((p) => p.dataset === "people");
  assert.equal(activities.length, 5);
  assert.equal(people.length, 5);
  assert.equal(new Set(PERSONAS.map((p) => p.id)).size, 10);
  assert.equal(new Set(PERSONAS.map((p) => p.key)).size, 10);
  assert.ok(
    PERSONAS.every((p) => p.email === `${p.key}@personas.planets.invalid`),
  );
  assert.ok(people.every((p) => !activities.some((a) => a.id === p.id)));
});
test("requested mock interests stay categorized and contain no Crazy Ideas fixture", () => {
  assert.deepEqual(PEOPLE_TOPICS, [
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
  assert.equal(
    PEOPLE_TOPICS.some(
      ([category]) => category === "projects" || category === "crazy_ideas",
    ),
    false,
  );
});
