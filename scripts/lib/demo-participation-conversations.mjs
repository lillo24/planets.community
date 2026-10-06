// MSG01's small extension to the existing, explicitly invoked demo world.
// Domain writes use authenticated canonical RPCs; verification never repairs.
const followUps = Object.freeze([
  [
    "bob",
    "Possiamo organizzarci qui sia per il murale sia per il Tavolo mensile.",
  ],
  [
    "alice",
    "Certo Marco, le due richieste restano separate e possiamo parlarne insieme qui.",
  ],
]);

async function rpc(user, name, params) {
  const result = await user.client.rpc(name, params);
  if (result.error)
    throw new Error(`Demo pair ${name} failed (code ${result.error.code}).`);
  return result.data;
}

async function pendingRequests(context, scenario) {
  const rows = await context.sql`
    select id, project_id from public.project_join_requests
    where requester_profile_id=${context.personas.bob.id}
      and project_id=any(${[scenario.proposals.mural.id, scenario.tavoli.monthly.id]}::uuid[])
      and status='pending' order by id
  `;
  if (rows.length !== 2)
    throw new Error(
      "MSG01 demo needs Marco's two distinct pending requests; use explicit demo seeding to restore the scenario.",
    );
  return rows;
}

export async function seedDemoParticipationConversation(context, scenario) {
  const messageIds = [];
  const requests = await pendingRequests(context, scenario);
  const [pair] = await rpc(
    context.personas.bob,
    "get_own_participation_conversation",
    {
      p_expected_profile_id: context.personas.bob.id,
      p_request_id: requests[0].id,
    },
  );
  for (const [persona, body] of followUps) {
    const user = context.personas[persona];
    const existing = await context.sql`
      select id from public.participation_conversation_messages
      where conversation_id=${pair.chat_id} and sender_profile_id=${user.id} and body=${body}
    `;
    if (existing.length > 1)
      throw new Error("Duplicate MSG01 demo follow-up history.");
    if (existing.length) {
      messageIds.push(existing[0].id);
    } else {
      const [message] = await rpc(
        user,
        "send_participation_conversation_message",
        {
          p_expected_profile_id: user.id,
          p_chat_id: pair.chat_id,
          p_body: body,
        },
      );
      if (!message?.message_id)
        throw new Error(
          "MSG01 demo follow-up did not return its canonical ID.",
        );
      messageIds.push(message.message_id);
    }
  }
  // The combined demo worker may project only these exact fixture messages;
  // unrelated messages in the same durable pair remain outside its inventory.
  return Object.freeze(messageIds);
}

export async function verifyDemoParticipationConversation(context, scenario) {
  const requests = await pendingRequests(context, scenario);
  const { bob, alice } = context.personas;
  for (const [user, counterparty] of [
    [bob, alice],
    [alice, bob],
  ]) {
    const rows = await rpc(user, "list_own_scoped_conversation_items", {
      p_expected_profile_id: user.id,
      p_scope: "private",
      p_limit: 50,
    });
    const pairs = rows.filter(
      (row) =>
        row.item_kind === "project_request_chat" &&
        row.project_request_counterparty_profile_id === counterparty.id,
    );
    if (
      pairs.length !== 1 ||
      pairs[0].pending_count !== 2 ||
      pairs[0].is_read_only
    )
      throw new Error(
        "MSG01 demo must show one writable Marco/Giulia pair with a canonical total of two pending requests.",
      );
    for (const request of requests) {
      const [contextRow] = await rpc(
        user,
        "get_own_participation_conversation",
        {
          p_expected_profile_id: user.id,
          p_request_id: request.id,
        },
      );
      if (contextRow.chat_id !== pairs[0].chat_id)
        throw new Error("MSG01 demo request context resolved to another pair.");
    }
    const feed = await rpc(user, "list_own_participation_conversation_items", {
      p_expected_profile_id: user.id,
      p_chat_id: pairs[0].chat_id,
      p_limit: 50,
    });
    const canonicalKeys = new Set(
      feed.map((row) => `${row.item_kind}:${row.item_id}`),
    );
    if (
      canonicalKeys.size !== feed.length ||
      requests.some(
        (request) =>
          feed.filter(
            (row) =>
              row.item_kind === "request" && row.request_id === request.id,
          ).length !== 1,
      )
    )
      throw new Error(
        "MSG01 demo requests must appear as distinct, single structured messages.",
      );
    if (
      !feed.some(
        (row) =>
          row.item_kind === "request" &&
          ["rejected", "withdrawn"].includes(row.request_status),
      )
    )
      throw new Error("MSG01 demo resolved request history is missing.");
    for (const [persona, body] of followUps) {
      if (
        feed.filter(
          (row) =>
            row.item_kind === "message" &&
            row.sender_profile_id === context.personas[persona].id &&
            row.body === body &&
            row.request_id === null,
        ).length !== 1
      )
        throw new Error(
          "MSG01 demo pair follow-up history is missing or duplicated.",
        );
    }
  }
}
