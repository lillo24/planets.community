// Invitation scenarios are part of demo-world, not a second seed system.
// SQL reads coordinate reconciliation; all domain transitions use actor RPCs.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const NEED_TITLE = "Cassette e piccoli attrezzi per l'orto";
const REQUEST_MESSAGE = "Posso portare attrezzi: decidiamo insieme cosa serve.";
const REQUEST_CHAT_BODY =
  "La mia offerta resta da concordare, anche se entro con un invito.";
const GROUP_BODY = "Sono entrato tramite invito, senza una foto di profilo.";

export function demoAdmissionActionId(
  projectId,
  profileId,
  invitationId,
  step,
) {
  if (
    ![projectId, profileId, invitationId, step].every(
      (part) => typeof part === "string" && part.length > 0,
    )
  ) {
    throw new Error(
      "A demo admission needs Project, account, generation and explicit step.",
    );
  }
  const hex = createHash("sha256")
    .update(
      JSON.stringify([
        "planets-demo-pi05",
        projectId,
        profileId,
        invitationId,
        step,
      ]),
    )
    .digest("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

export async function demoRpc(user, operation, params) {
  const { data, error } = await user.client.rpc(operation, params);
  if (error) {
    const code = /^[a-z0-9_]+$/iu.test(error.code ?? "")
      ? error.code
      : "unknown";
    // Provider errors may contain bearer arguments; never expose their text.
    throw new Error(`Demo ${operation} failed (code ${code}).`);
  }
  return data;
}

export async function ensureDemoInvitation(context, projectId) {
  const owner = context.personas.alice;
  const data = await demoRpc(owner, "create_project_participant_invitation", {
    p_expected_profile_id: owner.id,
    p_project_id: projectId,
  });
  const link = requireLink(data);
  await rememberLocalLink(context, projectId, link);
  return link;
}

function requireLink(data) {
  if (
    data?.length !== 1 ||
    !/^[A-Za-z0-9_-]{43}$/u.test(data[0].invite_token ?? "")
  ) {
    throw new Error(
      "The demo manager did not receive one canonical sharing link.",
    );
  }
  return data[0];
}

async function rememberLocalLink(context, projectId, link) {
  const file = path.join(
    context.repositoryRoot,
    ".env.demo-participant-links.json",
  );
  let previous = { apiUrl: context.status.apiUrl, generations: {} };
  try {
    previous = JSON.parse(await readFile(file, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT")
      throw new Error("Cannot read the ignored local demo link journal.");
  }
  if (
    previous.apiUrl !== context.status.apiUrl ||
    typeof previous.generations !== "object" ||
    !previous.generations
  ) {
    throw new Error(
      "Local demo link journal belongs to another backend; move it aside before seeding this stack.",
    );
  }
  previous.generations[link.invitation_id] = {
    projectId,
    token: link.invite_token,
  };
  await writeFile(file, JSON.stringify(previous, null, 2), { mode: 0o600 });
}

async function generationHistory(context, projectId) {
  return context.sql`
    select id, revocation_reason, revoked_at from private.project_participant_invitations
    where project_id = ${projectId} order by created_at, id
  `;
}

async function membership(context, projectId, user, id = null) {
  const rows = await context.sql`
    select id, originating_request_id, originating_participant_invitation_id, left_at, removed_at
    from public.project_memberships where project_id = ${projectId}
      and participant_profile_id = ${user.id}
      and (${id}::uuid is null or id = ${id}) order by joined_at, id
  `;
  return id ? rows[0] : rows;
}

function current(rows) {
  const active = rows.filter((m) => !m.left_at && !m.removed_at);
  if (active.length > 1)
    throw new Error("Duplicate current demo membership episodes.");
  return active[0];
}

async function ensureAdmission(
  context,
  projectId,
  user,
  link,
  step,
  checkpoint,
) {
  const action = demoAdmissionActionId(
    projectId,
    user.id,
    link.invitation_id,
    step,
  );
  const [receipt] = await context.sql`
    select project_id, invitation_id, membership_id, outcome
    from private.project_participant_admissions
    where profile_id = ${user.id} and client_action_id = ${action}
  `;
  if (receipt) {
    if (
      receipt.project_id !== projectId ||
      receipt.invitation_id !== link.invitation_id
    ) {
      throw new Error(
        "Demo admission action is bound to unexpected canonical history.",
      );
    }
    return receipt;
  }
  const rows = await demoRpc(user, "accept_project_participant_invitation", {
    p_expected_profile_id: user.id,
    p_token: link.invite_token,
    p_client_action_id: action,
  });
  if (rows?.length !== 1 || rows[0].project_id !== projectId) {
    throw new Error("Demo admission returned unexpected canonical context.");
  }
  // Fault injection used only by the bounded integration verifier, after commit.
  await checkpoint?.("direct-admission");
  return rows[0];
}

async function ensurePendingOffers(context, projectId, kind) {
  const { alice, bob } = context.personas;
  const needs = await context.sql`
    select id from public.project_resource_needs
    where project_id = ${projectId} and title = ${NEED_TITLE}
  `;
  if (needs.length > 1)
    throw new Error("Duplicate demo invitation resource need.");
  const needId =
    needs[0]?.id ??
    (await demoRpc(alice, "create_project_resource_need", {
      p_expected_creator_profile_id: alice.id,
      p_project_id: projectId,
      p_title: NEED_TITLE,
      p_details: null,
    }));
  const requests = await context.sql`
    select id from public.project_join_requests
    where project_id = ${projectId} and requester_profile_id = ${bob.id}
      and request_message = ${REQUEST_MESSAGE}
  `;
  if (requests.length > 1)
    throw new Error("Duplicate demo invitation offer request.");
  let requestId = requests[0]?.id;
  if (!requestId) {
    const skills =
      kind === "one_time"
        ? await context.sql`select skill_id from public.proposal_skills where proposal_id = ${projectId}`
        : [];
    requestId = await demoRpc(bob, "request_to_join_project", {
      p_expected_requester_profile_id: bob.id,
      p_project_id: projectId,
      p_request_message: REQUEST_MESSAGE,
      p_skill_ids: skills.map((s) => s.skill_id),
      p_resource_need_ids: [needId],
    });
  }
  const chats = await demoRpc(bob, "get_own_project_join_request_chat", {
    p_expected_profile_id: bob.id,
    p_request_id: requestId,
  });
  if (chats?.length !== 1)
    throw new Error("The demo offer request chat is missing.");
  const chatId = chats[0].chat_id;
  const messages = await context.sql`
    select id from public.project_join_request_chat_messages where chat_id = ${chatId} and body = ${REQUEST_CHAT_BODY}
  `;
  if (messages.length > 1)
    throw new Error("Duplicate demo offer chat message.");
  if (messages.length === 0) {
    await demoRpc(bob, "send_project_join_request_chat_message", {
      p_expected_profile_id: bob.id,
      p_chat_id: chatId,
      p_body: REQUEST_CHAT_BODY,
    });
  }
}

export async function seedDemoParticipantInvitations(
  context,
  scenario,
  checkpoint,
) {
  const { alice, bob, carla, dario } = context.personas;
  for (const [kind, project] of activeCases(scenario)) {
    let history = await generationHistory(context, project.id);
    if (history.length === 0) {
      await ensureDemoInvitation(context, project.id);
      history = await generationHistory(context, project.id);
    }
    if (history.length === 1 && !history[0].revoked_at) {
      const link = await ensureDemoInvitation(context, project.id);
      await ensurePendingOffers(context, project.id, kind);
      await ensureAdmission(
        context,
        project.id,
        bob,
        link,
        "supersede-request",
        checkpoint,
      );
      await ensureAdmission(
        context,
        project.id,
        carla,
        link,
        "photo-participant",
        checkpoint,
      );
      for (const [step, terminal] of [
        ["first-leave", "left"],
        ["second-remove", "removed"],
        ["third-current", null],
      ]) {
        const receipt = await ensureAdmission(
          context,
          project.id,
          dario,
          link,
          step,
          checkpoint,
        );
        const episode = await membership(
          context,
          project.id,
          dario,
          receipt.membership_id,
        );
        if (terminal && !episode.left_at && !episode.removed_at) {
          await demoRpc(
            terminal === "left" ? dario : alice,
            terminal === "left"
              ? "leave_project"
              : "remove_project_member_as_manager",
            {
              [terminal === "left"
                ? "p_expected_participant_profile_id"
                : "p_expected_manager_profile_id"]:
                terminal === "left" ? dario.id : alice.id,
              p_membership_id: episode.id,
            },
          );
        }
        if (
          terminal &&
          Boolean(episode.left_at || episode.removed_at) &&
          !episode[terminal === "left" ? "left_at" : "removed_at"]
        ) {
          throw new Error(
            "A demo history step ended with the wrong departure reason.",
          );
        }
      }
      const next = requireLink(
        await demoRpc(alice, "regenerate_project_participant_invitation", {
          p_expected_profile_id: alice.id,
          p_project_id: project.id,
        }),
      );
      await rememberLocalLink(context, project.id, next);
      const preview = await demoRpc(
        { client: context.anonymous },
        "get_project_participant_invitation_preview",
        { p_token: link.invite_token },
      );
      if (preview[0]?.available !== false)
        throw new Error("A replaced demo link remained available.");
      history = await generationHistory(context, project.id);
    }
    if (history.length === 2 && !history[1].revoked_at) {
      const link = await ensureDemoInvitation(context, project.id);
      await demoRpc(alice, "revoke_project_participant_invitation", {
        p_expected_profile_id: alice.id,
        p_project_id: project.id,
        p_invitation_id: link.invitation_id,
      });
      const preview = await demoRpc(
        { client: context.anonymous },
        "get_project_participant_invitation_preview",
        { p_token: link.invite_token },
      );
      if (preview[0]?.available !== false)
        throw new Error("A revoked demo link remained available.");
      history = await generationHistory(context, project.id);
    }
    if (history.length === 2 && history[1].revoked_at) {
      await ensureDemoInvitation(context, project.id);
      history = await generationHistory(context, project.id);
    }
    if (
      history.length !== 3 ||
      history[0].revocation_reason !== "replaced" ||
      history[1].revocation_reason !== "revoked" ||
      history[2].revoked_at
    ) {
      throw new Error(
        "Demo invitation generations drifted; reset the local demo to rebuild deliberate rotation history.",
      );
    }
    const link = await ensureDemoInvitation(context, project.id);
    // Interactive leave/removal is restored only by this explicit seed action.
    // Its stable key includes the most recent ended episode, never an old receipt.
    for (const user of [bob, carla, dario]) {
      const episodes = await membership(context, project.id, user);
      if (!current(episodes)) {
        const ended = episodes.at(-1);
        if (!ended)
          throw new Error(
            "Demo admission history is missing before restoration.",
          );
        await ensureAdmission(
          context,
          project.id,
          user,
          link,
          `restore-after:${ended.id}`,
          checkpoint,
        );
      }
    }
    await ensureAdmission(
      context,
      project.id,
      alice,
      link,
      "creator",
      checkpoint,
    );
    await ensureAdmission(
      context,
      project.id,
      carla,
      link,
      "already-joined",
      checkpoint,
    );
    const chats = await demoRpc(dario, "get_own_project_group_chat", {
      p_expected_profile_id: dario.id,
      p_project_id: project.id,
    });
    if (chats?.length !== 1)
      throw new Error("Photo-free demo participant cannot open Project chat.");
    const messages = await context.sql`
      select id from public.project_chat_messages where chat_id = ${chats[0].chat_id} and body = ${GROUP_BODY}
    `;
    if (messages.length > 1)
      throw new Error("Duplicate photo-free demo chat message.");
    if (messages.length === 0) {
      await demoRpc(dario, "send_project_chat_message", {
        p_expected_profile_id: dario.id,
        p_chat_id: chats[0].chat_id,
        p_body: GROUP_BODY,
      });
    }
  }
}

function activeCases(scenario) {
  return [
    ["one_time", scenario.proposals.participantWorkshop],
    ["recurring", scenario.tavoli.participantTable],
  ];
}

export async function verifyDemoParticipantInvitations(context, scenario) {
  const { alice, bob, carla, dario, elena } = context.personas;
  for (const [kind, project] of activeCases(scenario)) {
    const history = await generationHistory(context, project.id);
    if (
      history.length !== 3 ||
      history[0].revocation_reason !== "replaced" ||
      history[1].revocation_reason !== "revoked" ||
      history[2].revoked_at
    ) {
      throw new Error(
        "Invitation demo history is missing or drifted; verification does not rotate or repair it.",
      );
    }
    const link = requireLink(
      await demoRpc(alice, "get_current_project_participant_invitation", {
        p_expected_profile_id: alice.id,
        p_project_id: project.id,
      }),
    );
    if (link.invitation_id !== history[2].id)
      throw new Error("Unexpected current demo generation.");
    await assertPreview(context, link, project.id, kind, true);
    const secrets = await context.sql`
      select invitation_id from private.project_participant_invitation_secrets
      where invitation_id = any(${history.map((h) => h.id)}::uuid[])
    `;
    if (secrets.length !== 1 || secrets[0].invitation_id !== link.invitation_id)
      throw new Error("Revoked demo secrets were not destroyed.");
    for (const user of [bob, carla, dario]) {
      const episodes = await membership(context, project.id, user);
      const active = current(episodes);
      if (
        !active ||
        episodes.some(
          (m) =>
            m.originating_request_id ||
            !m.originating_participant_invitation_id,
        )
      ) {
        throw new Error(
          "Invitation demo lacks canonical direct membership provenance.",
        );
      }
      if (
        user === dario &&
        (!episodes.some((m) => m.left_at) ||
          !episodes.some((m) => m.removed_at) ||
          episodes.length < 3)
      ) {
        throw new Error(
          "Photo-free demo lacks retained leave/removal/re-entry episodes.",
        );
      }
      const own = await demoRpc(user, "list_own_project_memberships", {
        p_expected_participant_profile_id: user.id,
      });
      if (
        !own.some(
          (m) =>
            m.project_id === project.id &&
            m.membership_id === active.id &&
            m.membership_status === "current",
        )
      ) {
        throw new Error(
          "Demo own participation cannot rediscover current membership.",
        );
      }
    }
    if (
      (await membership(context, project.id, alice)).length ||
      (await membership(context, project.id, elena)).length
    ) {
      throw new Error(
        "Creator must have no participant episode and Elena must remain unjoined; reset after interactive Elena Join.",
      );
    }
    const darioEpisodes = await membership(context, project.id, dario);
    const receipts = await context.sql`
      select profile_id, client_action_id, membership_id, outcome, invitation_id from private.project_participant_admissions where project_id = ${project.id}
    `;
    for (const [step, status] of [
      ["first-leave", "left_at"],
      ["second-remove", "removed_at"],
      ["third-current", null],
    ]) {
      const action = demoAdmissionActionId(
        project.id,
        dario.id,
        history[0].id,
        step,
      );
      const receipt = receipts.find(
        (r) => r.profile_id === dario.id && r.client_action_id === action,
      );
      const episode = darioEpisodes.find(
        (m) => m.id === receipt?.membership_id,
      );
      if (
        !episode ||
        receipt.outcome !== "joined" ||
        (status && !episode[status])
      )
        throw new Error(
          "Stable admission action lost its original demo episode.",
        );
    }
    if (
      !receipts.some(
        (r) =>
          r.profile_id === alice.id &&
          r.outcome === "creator" &&
          r.membership_id === null,
      ) ||
      !receipts.some(
        (r) => r.profile_id === carla.id && r.outcome === "already_joined",
      )
    ) {
      throw new Error("Creator/already-joined demo outcomes are missing.");
    }
    const requests = await context.sql`
      select id, status, resolution_reason, resolved_by_profile_id, superseded_by_membership_id
      from public.project_join_requests where project_id = ${project.id} and requester_profile_id = ${bob.id}
    `;
    const superseding = (await membership(context, project.id, bob))[0];
    if (
      requests.length !== 1 ||
      requests[0].status !== "withdrawn" ||
      requests[0].resolution_reason !== "direct_participant_invitation" ||
      requests[0].resolved_by_profile_id !== bob.id ||
      requests[0].superseded_by_membership_id !== superseding.id
    ) {
      throw new Error(
        "Demo offer request lacks reasoned, requester-owned supersession.",
      );
    }
    const request = requests[0];
    const [offers] = await context.sql`
      select (select count(*)::int from public.project_join_request_skill_selections where request_id = ${request.id}) as skills,
        (select count(*)::int from public.project_join_request_resource_selections where request_id = ${request.id}) as resources,
        (select count(*)::int from public.project_join_request_chat_messages message join public.project_join_request_chats chat on chat.id = message.chat_id where chat.request_id = ${request.id} and message.body = ${REQUEST_CHAT_BODY}) as messages
    `;
    if (
      offers.skills !== (kind === "one_time" ? 1 : 0) ||
      offers.resources !== 1 ||
      offers.messages !== 1
    ) {
      throw new Error(
        "Demo supersession lost its skill/resource offers or human request-chat history.",
      );
    }
    const [commitments] = await context.sql`
      select (select count(*) from public.project_membership_skill_commitments c join public.project_memberships m on m.id = c.membership_id where m.project_id = ${project.id})
        + (select count(*) from public.project_membership_resource_commitments c join public.project_memberships m on m.id = c.membership_id where m.project_id = ${project.id}) as total
    `;
    if (Number(commitments.total) !== 0)
      throw new Error("Direct demo admission inherited automatic commitments.");
    const chats = await demoRpc(dario, "get_own_project_group_chat", {
      p_expected_profile_id: dario.id,
      p_project_id: project.id,
    });
    if (chats?.length !== 1)
      throw new Error(
        "Photo-free demo participant has no canonical Project chat.",
      );
    const messages = await demoRpc(dario, "list_own_project_chat_messages", {
      p_expected_profile_id: dario.id,
      p_chat_id: chats[0].chat_id,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    });
    if (!messages.some((m) => m.body === GROUP_BODY))
      throw new Error("Photo-free demo chat history is unreadable.");
    const privateRead = await elena.client.rpc("get_own_project_group_chat", {
      p_expected_profile_id: elena.id,
      p_project_id: project.id,
    });
    if (privateRead.error?.code !== "42501")
      throw new Error("Unjoined demo recipient can read private Project chat.");
    const publicData = await demoRpc(
      { client: context.anonymous },
      kind === "one_time"
        ? "get_public_proposal"
        : "get_public_recurring_activity",
      kind === "one_time"
        ? { p_proposal_id: project.id }
        : {
            p_recurring_activity_id: project.id,
            p_occurrence_limit: 3,
            p_reference_time: new Date().toISOString(),
          },
    );
    if (publicData?.length !== 1 || publicData[0].exact_meeting_text !== null)
      throw new Error(
        "Invitation demo public detail exposed private meeting data.",
      );
    for (const table of [
      "project_memberships",
      "profile_photos",
      "project_chat_messages",
    ]) {
      const denied = await context.anonymous.from(table).select("*").limit(1);
      if (!denied.error && denied.data.length)
        throw new Error("Anonymous client obtained private demo records.");
    }
  }
  for (const [project, kind, available] of [
    [scenario.proposals.participantFull, "one_time", true],
    [scenario.proposals.concert, "one_time", false],
    [scenario.tavoli.paused, "recurring", false],
    [scenario.tavoli.participantEnded, "recurring", false],
  ]) {
    const history = await generationHistory(context, project.id);
    if (history.length !== 1 || history[0].revoked_at)
      throw new Error(
        "Lifecycle demo link was not issued before closure/pause.",
      );
    const link = requireLink(
      await demoRpc(alice, "get_current_project_participant_invitation", {
        p_expected_profile_id: alice.id,
        p_project_id: project.id,
      }),
    );
    await assertPreview(context, link, project.id, kind, available);
  }
}

async function assertPreview(context, link, projectId, kind, available) {
  const preview = await demoRpc(
    { client: context.anonymous },
    "get_project_participant_invitation_preview",
    { p_token: link.invite_token },
  );
  if (
    preview?.length !== 1 ||
    preview[0].available !== available ||
    preview[0].project_id !== (available ? projectId : null) ||
    preview[0].project_kind !== (available ? kind : null) ||
    (!available && preview[0].project_title !== null) ||
    Object.keys(preview[0]).length !== 4
  ) {
    throw new Error(
      "Demo participant preview violates availability/privacy contract.",
    );
  }
}

export async function exerciseDemoInvitationTransitions(context, scenario) {
  const { alice, dario, elena } = context.personas;
  const params = (projectId) => ({
    p_expected_profile_id: alice.id,
    p_project_id: projectId,
  });
  const currentLink = async (projectId) =>
    requireLink(
      await demoRpc(
        alice,
        "get_current_project_participant_invitation",
        params(projectId),
      ),
    );
  const accept = (user, link, step) =>
    user.client.rpc("accept_project_participant_invitation", {
      p_expected_profile_id: user.id,
      p_token: link.invite_token,
      p_client_action_id: demoAdmissionActionId(
        "integration",
        user.id,
        link.invitation_id,
        step,
      ),
    });
  const full = await currentLink(scenario.proposals.participantFull.id);
  const deniedFull = await accept(elena, full, "full");
  if (
    deniedFull.error?.code !== "PT409" ||
    deniedFull.error.message !== "This Project is full."
  ) {
    throw new Error("Full demo did not retain the canonical capacity failure.");
  }
  for (const project of [
    scenario.proposals.concert,
    scenario.tavoli.participantEnded,
    scenario.tavoli.paused,
  ]) {
    const result = await accept(
      elena,
      await currentLink(project.id),
      "unavailable",
    );
    if (
      result.error?.code !== "PT409" ||
      result.error.message !== "This participant invitation is unavailable."
    ) {
      throw new Error(
        "Ended/paused demo did not retain generic invitation unavailability.",
      );
    }
  }
  const pausedId = scenario.tavoli.paused.id;
  const beforeResume = await currentLink(pausedId);
  await demoRpc(alice, "resume_recurring_activity", {
    p_expected_creator_profile_id: alice.id,
    p_recurring_activity_id: pausedId,
  });
  await assertPreview(context, beforeResume, pausedId, "recurring", true);
  const resumed = await currentLink(pausedId);
  if (
    resumed.invitation_id !== beforeResume.invitation_id ||
    resumed.invite_token !== beforeResume.invite_token
  )
    throw new Error("Resume rotated the demo participant generation.");
  await demoRpc(alice, "pause_recurring_activity", {
    p_expected_creator_profile_id: alice.id,
    p_recurring_activity_id: pausedId,
  });
  await assertPreview(context, beforeResume, pausedId, "recurring", false);
  const journal = JSON.parse(
    await readFile(
      path.join(context.repositoryRoot, ".env.demo-participant-links.json"),
      "utf8",
    ),
  );
  if (journal.apiUrl !== context.status.apiUrl)
    throw new Error("Integration link journal has the wrong local backend.");
  const departed = [];
  for (const [kind, project] of activeCases(scenario)) {
    const history = await generationHistory(context, project.id);
    const old = journal.generations[history[0].id];
    if (!old || old.projectId !== project.id)
      throw new Error(
        "The explicit integration check lacks its archived local capability.",
      );
    await assertPreview(
      context,
      { invite_token: old.token },
      project.id,
      kind,
      false,
    );
    for (const [step, expected] of [
      ["first-leave", "left"],
      ["second-remove", "removed"],
    ]) {
      const replay = await demoRpc(
        dario,
        "accept_project_participant_invitation",
        {
          p_expected_profile_id: dario.id,
          p_token: old.token,
          p_client_action_id: demoAdmissionActionId(
            project.id,
            dario.id,
            history[0].id,
            step,
          ),
        },
      );
      if (
        replay[0]?.replayed !== true ||
        replay[0]?.membership_status !== expected
      )
        throw new Error("Old demo receipt resurrected an ended episode.");
    }
    const ordinary = await dario.client.rpc("request_to_join_project", {
      p_expected_requester_profile_id: dario.id,
      p_project_id: scenario.proposals.repairCafe.id,
      p_request_message: null,
    });
    const drafts =
      await context.sql`select id from public.proposals where creator_profile_id = ${dario.id} and title = 'Photo-free publication gate'`;
    if (drafts.length > 1)
      throw new Error("Duplicate private photo-gate integration draft.");
    const draftFields = {
      p_expected_creator_profile_id: dario.id,
      p_title: "Photo-free publication gate",
      p_skill_ids: [],
      p_skill_importances: [],
      p_summary: "Synthetic private photo-gate check",
      p_description:
        "Complete local fixture that must remain unpublished without a profile photo.",
      p_starts_at: new Date(Date.now() + 86400000).toISOString(),
      p_ends_at: new Date(Date.now() + 90000000).toISOString(),
      p_event_timezone: "Europe/Rome",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Synthetic Trento meeting",
      p_exact_meeting_text: "Synthetic private meeting point",
      p_exact_location_visibility: "participants",
      p_registration_capacity: 20,
      p_count_organizers_toward_capacity: false,
    };
    const draftId =
      drafts[0]?.id ??
      (await demoRpc(dario, "create_proposal_draft", draftFields));
    if (drafts.length === 1)
      await demoRpc(dario, "update_own_proposal", {
        ...draftFields,
        p_proposal_id: draftId,
      });
    const publication = await dario.client.rpc("publish_proposal", {
      p_expected_creator_profile_id: dario.id,
      p_proposal_id: draftId,
    });
    if (ordinary.error?.code !== "PT422" || publication.error?.code !== "PT422")
      throw new Error(
        `Invited photo-free demo participant lost later ordinary photo gates (request ${ordinary.error?.code ?? "succeeded"}; publication ${publication.error?.code ?? "succeeded"}).`,
      );
    const active = current(await membership(context, project.id, dario));
    const [activeReceipt] = await context.sql`
      select client_action_id, invitation_id from private.project_participant_admissions
      where membership_id = ${active.id} and profile_id = ${dario.id} and outcome = 'joined'
    `;
    if (!activeReceipt)
      throw new Error(
        "The current demo episode lacks its own admission receipt.",
      );
    const activeToken = journal.generations[activeReceipt.invitation_id]?.token;
    if (!activeToken)
      throw new Error(
        "Current demo receipt lacks its archived local integration capability.",
      );
    const operation =
      kind === "one_time"
        ? "leave_project"
        : "remove_project_member_as_manager";
    await demoRpc(kind === "one_time" ? dario : alice, operation, {
      [kind === "one_time"
        ? "p_expected_participant_profile_id"
        : "p_expected_manager_profile_id"]:
        kind === "one_time" ? dario.id : alice.id,
      p_membership_id: active.id,
    });
    // Original committed success is now historical even after both generations
    // were revoked. Recovery cannot perform deliberate restoration.
    const replay = await demoRpc(
      dario,
      "accept_project_participant_invitation",
      {
        p_expected_profile_id: dario.id,
        p_token: activeToken,
        p_client_action_id: activeReceipt.client_action_id,
      },
    );
    if (
      replay[0]?.membership_id !== active.id ||
      replay[0]?.membership_status !==
        (kind === "one_time" ? "left" : "removed") ||
      current(await membership(context, project.id, dario))
    ) {
      throw new Error(
        "Stale recorded demo success restored current membership.",
      );
    }
    departed.push({ projectId: project.id, membershipId: active.id });
  }
  return departed;
}

// Stable canonical identities/relations only; relative schedule timestamps and
// OTP/session state are intentionally excluded. No capability or digest leaves SQL.
export async function snapshotDemoDomain(
  sql,
  profileIds,
  projectIds,
  listingIds,
) {
  const rows = await sql`
    select 'membership' as kind, id::text as id, jsonb_build_array(project_id, participant_profile_id, originating_request_id, originating_participant_invitation_id, left_at is not null, removed_at is not null) as relation from public.project_memberships where project_id = any(${projectIds}::uuid[])
    union all select 'generation', id::text, jsonb_build_array(project_id, revocation_reason) from private.project_participant_invitations where project_id = any(${projectIds}::uuid[])
    union all select 'admission', profile_id::text || ':' || client_action_id::text, jsonb_build_array(project_id, invitation_id, membership_id, outcome) from private.project_participant_admissions where project_id = any(${projectIds}::uuid[])
    union all select 'request', id::text, jsonb_build_array(project_id, requester_profile_id, status, resolution_reason, superseded_by_membership_id) from public.project_join_requests where project_id = any(${projectIds}::uuid[])
    union all select 'skill-offer', request_id::text || ':' || skill_id::text, jsonb_build_array(request_id, skill_id) from public.project_join_request_skill_selections where request_id in (select id from public.project_join_requests where project_id = any(${projectIds}::uuid[]))
    union all select 'resource-offer', request_id::text || ':' || resource_need_id::text, jsonb_build_array(request_id, resource_need_id) from public.project_join_request_resource_selections where request_id in (select id from public.project_join_requests where project_id = any(${projectIds}::uuid[]))
    union all select 'request-chat', id::text, jsonb_build_array(request_id) from public.project_join_request_chats where request_id in (select id from public.project_join_requests where project_id = any(${projectIds}::uuid[]))
    union all select 'request-message', message.id::text, jsonb_build_array(message.chat_id, message.sender_profile_id) from public.project_join_request_chat_messages message join public.project_join_request_chats chat on chat.id = message.chat_id join public.project_join_requests request on request.id = chat.request_id where request.project_id = any(${projectIds}::uuid[])
    union all select 'chat', id::text, jsonb_build_array(project_id) from public.project_group_chats where project_id = any(${projectIds}::uuid[])
    union all select 'chat-message', message.id::text, jsonb_build_array(message.chat_id, message.sender_profile_id) from public.project_chat_messages message join public.project_group_chats chat on chat.id = message.chat_id where chat.project_id = any(${projectIds}::uuid[])
    union all select 'notification', id::text, jsonb_build_array(source_outbox_event_id, recipient_profile_id) from public.notifications where recipient_profile_id = any(${profileIds}::uuid[])
    union all select 'join-event', id::text, jsonb_build_array(event_type, payload->>'membership_id') from private.outbox_events where event_type = 'project.participant_invitation_joined' and payload->>'project_id' = any(${projectIds}::text[])
    union all select 'need', id::text, jsonb_build_array(project_id, state) from public.project_resource_needs where project_id = any(${projectIds}::uuid[])
    union all select 'skill-commitment', commitment.membership_id::text || ':' || commitment.skill_id::text, jsonb_build_array(commitment.membership_id, commitment.skill_id) from public.project_membership_skill_commitments commitment join public.project_memberships member on member.id = commitment.membership_id where member.project_id = any(${projectIds}::uuid[])
    union all select 'resource-commitment', commitment.membership_id::text || ':' || commitment.resource_need_id::text, jsonb_build_array(commitment.membership_id, commitment.resource_need_id) from public.project_membership_resource_commitments commitment join public.project_memberships member on member.id = commitment.membership_id where member.project_id = any(${projectIds}::uuid[])
    union all select 'project', id::text, jsonb_build_array(project_kind, creator_profile_id) from public.projects where id = any(${projectIds}::uuid[])
    union all select 'profile', id::text, jsonb_build_array(display_name, bio) from public.profiles where id = any(${profileIds}::uuid[])
    union all select 'photo', profile_id::text, jsonb_build_array(object_path, audience) from public.profile_photos where profile_id = any(${profileIds}::uuid[])
    union all select 'listing', id::text, jsonb_build_array(owner_profile_id, lifecycle_state) from public.resource_listings where id = any(${listingIds}::uuid[])
    order by kind, id
  `;
  return Array.from(rows);
}
