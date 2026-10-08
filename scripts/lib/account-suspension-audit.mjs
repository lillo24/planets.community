// Inspectable call-chain coverage, not a replacement for real authorization tests.
// Overloads share a name; the committed per-signature inventory catches new API
// overloads even when an existing sibling already reaches a gate.
const gates = new Set([
  "private.assert_profile_account_active",
  "public.assert_own_account_active",
  "private.current_account_is_active",
]);

export function accountGatePath(functions, start, visited = new Set()) {
  const name = `${start.schema}.${start.name}`;
  if (gates.has(name)) return [name];
  if (visited.has(start.signature)) return null;
  const nextVisited = new Set(visited).add(start.signature);
  const calls = [
    ...start.source.matchAll(/\b(private|public)\.([a-z_]+)\s*\(/gu),
  ].map((match) => `${match[1]}.${match[2]}`);
  for (const call of calls) {
    if (gates.has(call)) return [name, call];
    for (const candidate of functions.filter(
      (item) => `${item.schema}.${item.name}` === call,
    )) {
      const path = accountGatePath(functions, candidate, nextVisited);
      if (path) return [name, ...path];
    }
  }
  return null;
}

export function classifyAccountRpc(functions, entry) {
  // Reviewed MAP01 service entry points carry a verified/stored actor. Their
  // service-only grants do not exempt that actor from the account boundary.
  if (
    [
      "reserve_location_search_v1",
      "issue_location_selections_v1",
      "resolve_location_selection_v1",
    ].includes(entry.name)
  ) {
    const gate = accountGatePath(functions, entry);
    if (!gate)
      throw new Error(`Service actor account gate missing: ${entry.signature}`);
    if (entry.auth || entry.anon)
      throw new Error(`Location service grants widened: ${entry.signature}`);
    return { classification: "SERVICE/WORKER_ONLY", gate };
  }
  if (!entry.auth) return { classification: "SERVICE/WORKER_ONLY", gate: null };
  if (entry.name === "get_own_account_suspension_status") {
    return { classification: "ALLOW_WHILE_SUSPENDED", gate: null };
  }
  if (entry.anon)
    return { classification: "PUBLIC/ANONYMOUS_DATA", gate: null };
  const gate = accountGatePath(functions, entry);
  if (!gate) throw new Error(`Account gate missing: ${entry.signature}`);
  return { classification: "DENY_WHILE_SUSPENDED", gate };
}
