// Synthetic catalogue only. Callers must first assert their owned LOCAL stack.
// Nothing here activates the server experiment or creates real identities.
export const cocreateLocalTopics = [
  ["cc000000-0000-4000-8000-000000000001", "Calcetto"],
  ["cc000000-0000-4000-8000-000000000002", "Giochi da tavolo"],
  ["cc000000-0000-4000-8000-000000000003", "Nuovi a Trento"],
];
export const cocreateLocalHubs = [
  ["cc000000-0000-4000-8000-000000000011", cocreateLocalTopics[0][0], "Trento"],
  ["cc000000-0000-4000-8000-000000000012", cocreateLocalTopics[1][0], "Trento"],
  ["cc000000-0000-4000-8000-000000000013", cocreateLocalTopics[2][0], "Trento"],
];
export async function seedCocreateLocalCatalogue(sql) {
  for (const [id, label] of cocreateLocalTopics) {
    await sql`insert into private.cocreate_topics(id,label,active) values(${id}::uuid,${label},true)
      on conflict(id) do update set label=excluded.label,active=true`;
  }
  for (const [id, topic, locality] of cocreateLocalHubs) {
    await sql`insert into private.cocreate_hubs(id,topic_id,locality,active)
      values(${id}::uuid,${topic}::uuid,${locality},true)
      on conflict(id) do update set topic_id=excluded.topic_id,locality=excluded.locality,active=true`;
  }
}
