// Set only the documented experiment singleton in this task's owned local world.
import assert from "node:assert/strict";
import { openOwnedWorld } from "./owned-world.mjs";

assert.ok(["true", "false"].includes(process.argv[3]));
const { sql } = await openOwnedWorld(process.argv[2]);
try {
  const value = process.argv[3] === "true";
  await sql`update private.cocreate_settings set enabled=${value} where singleton`;
  console.log("Task-owned server gate:", value);
} finally {
  await sql.end({ timeout: 5 });
}
