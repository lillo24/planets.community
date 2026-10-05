// Owned local rehearsal only; no request/OTP/capability/session logging.
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import {
  DEMO_PERSONAS,
  DEMO_SCENARIOS,
  assertSafeLocalDemoTarget,
} from "../../../scripts/lib/demo-world.mjs";
import { demoRpc } from "../../../scripts/lib/demo-participant-invitations.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { createPublicHostHarness } from "./public-host-harness.ts";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const config = readFileSync(
  new URL("../../../supabase/config.toml", import.meta.url),
  "utf8",
);
if (
  process.env.PI05_LOCAL_REHEARSAL !== "1" ||
  !config.includes('project_id = "planets-community-pi05"')
) {
  throw new Error(
    "Explicit PI05_LOCAL_REHEARSAL=1 and owned planets-community-pi05 stack required.",
  );
}
const status = readLocalSupabaseStatus(root);
const mailpitUrl = "http://127.0.0.1:58924";
if (!status.databaseUrl)
  throw new Error("PI05 local database URL is required.");
assertSafeLocalDemoTarget({
  ...status,
  databaseUrl: status.databaseUrl,
  mailpitUrl,
  environment: "local",
});
if (
  new URL(status.apiUrl).hostname !== "127.0.0.1" ||
  new URL(status.apiUrl).port !== "58921"
) {
  throw new Error("PI05 requires owned disposable ports 58920–58929.");
}
const sql = postgres(status.databaseUrl!, {
  max: 2,
  onnotice: () => {},
  connection: { statement_timeout: 15000 },
});
const origin = "http://127.0.0.1:3174";
const fixturePath = new URL("../../../.env.pi05-browser.json", import.meta.url);
const emails = {
  proposal: "pi05-browser-proposal@planets.invalid",
  tavolo: "pi05-browser-tavolo@planets.invalid",
  mobile: "pi05-mobile@planets.invalid",
};
type Kind = "proposal" | "tavolo";
type Link = { projectId: string; invitationId: string; token: string };
type Fixture = { apiUrl: string; links: Record<Kind, Link> };
const owner = await signInLocalOtpUser({
  ...status,
  mailpitUrl,
  email: DEMO_PERSONAS.alice.email,
  verifierName: "PI05 manager",
});
const projects = {
  proposal: DEMO_SCENARIOS.proposals.participantWorkshop.title,
  tavolo: DEMO_SCENARIOS.tavoli.participantTable.title,
};
async function resolveProject(kind: Kind) {
  const rows =
    kind === "proposal"
      ? await sql`select id from public.proposals where creator_profile_id=${owner.id} and title=${projects[kind]}`
      : await sql`select id from public.recurring_activities where creator_profile_id=${owner.id} and title=${projects[kind]}`;
  if (rows.length !== 1)
    throw new Error(
      "Seed and verify the PI05 demo world before browser rehearsal.",
    );
  return rows[0].id as string;
}
async function canonicalStatus() {
  const ids = [
    await resolveProject("proposal"),
    await resolveProject("tavolo"),
  ];
  const accounts = Array.from(
    await sql`
    select identity.email, profile.display_name, count(distinct photo.profile_id)::int as photos,
      count(distinct member.id) filter (where member.left_at is null and member.removed_at is null)::int as current_memberships,
      count(distinct member.id)::int as episodes
    from auth.users identity left join public.profiles profile on profile.id=identity.id
    left join public.profile_photos photo on photo.profile_id=identity.id
    left join public.project_memberships member on member.participant_profile_id=identity.id and member.project_id=any(${ids}::uuid[])
    where identity.email=any(${Object.values(emails)}::text[])
    group by identity.email, profile.display_name order by identity.email
  `,
  );
  const projectStates = [];
  for (const projectId of ids) {
    const [capacity] = await sql`
      select registration_capacity, count_organizers_toward_capacity, capacity_used_count
      from private.project_registration_capacity_snapshot(${projectId}::uuid)
    `;
    const [history] = await sql`
      select count(*)::int as current_participants from public.project_memberships
      where project_id=${projectId} and left_at is null and removed_at is null
    `;
    const [receipts] = await sql`
      select count(*)::int as interactive_receipts from private.project_participant_admissions
      where project_id=${projectId} and profile_id in (select id from auth.users where email=any(${Object.values(emails)}::text[]))
    `;
    projectStates.push({ projectId, ...capacity, ...history, ...receipts });
  }
  return { accounts, projects: projectStates };
}
const command = process.argv.find((arg) =>
  /^--(?:(?:revoke|leave|remove)=(?:proposal|tavolo)|status|mobile-config)$/u.test(
    arg,
  ),
);
if (command) {
  if (command === "--status") {
    console.log(JSON.stringify(await canonicalStatus()));
  } else if (command === "--mobile-config") {
    const fixture: Fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
    if (fixture.apiUrl !== status.apiUrl)
      throw new Error("PI05 mobile fixture has another backend.");
    writeFileSync(
      new URL("../../../apps/mobile/config/local.json", import.meta.url),
      JSON.stringify({
        APP_ENV: "local",
        SUPABASE_URL: status.apiUrl,
        SUPABASE_PUBLISHABLE_KEY: status.publishableKey,
        PI05_LOCAL_REHEARSAL: true,
        PI05_PROPOSAL_TOKEN: fixture.links.proposal.token,
        PI05_TAVOLO_TOKEN: fixture.links.tavolo.token,
      }),
    );
    console.log(
      "PI05 local driver configuration written; use UI OTP sign-in, no session injected.",
    );
  } else {
    const [operation, kind] = command.slice(2).split("=") as [string, Kind];
    if (!Object.keys(projects).includes(kind))
      throw new Error(
        "Specify proposal or tavolo for the owned PI05 operation.",
      );
    const projectId = await resolveProject(kind);
    if (operation === "revoke") {
      const links = await demoRpc(
        owner,
        "get_current_project_participant_invitation",
        { p_expected_profile_id: owner.id, p_project_id: projectId },
      );
      if (links.length === 1)
        await demoRpc(owner, "revoke_project_participant_invitation", {
          p_expected_profile_id: owner.id,
          p_project_id: projectId,
          p_invitation_id: links[0].invitation_id,
        });
    } else {
      const user = await signInLocalOtpUser({
        ...status,
        mailpitUrl,
        email: emails[kind],
        verifierName: "PI05 browser participant",
      });
      const rows =
        await sql`select id from public.project_memberships where project_id=${projectId} and participant_profile_id=${user.id} and left_at is null and removed_at is null`;
      if (rows.length !== 1)
        throw new Error(
          "PI05 browser account must have one current membership before departure.",
        );
      await demoRpc(
        operation === "leave" ? user : owner,
        operation === "leave"
          ? "leave_project"
          : "remove_project_member_as_manager",
        {
          [operation === "leave"
            ? "p_expected_participant_profile_id"
            : "p_expected_manager_profile_id"]:
            operation === "leave" ? user.id : owner.id,
          p_membership_id: rows[0].id,
        },
      );
    }
    console.log(
      `PI05 canonical ${operation} completed for ${kind}; no capability disclosed.`,
    );
  }
  await sql.end();
} else {
  let fixture: Fixture;
  if (process.argv.includes("--reuse")) {
    fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
    if (fixture.apiUrl !== status.apiUrl)
      throw new Error("PI05 browser fixture belongs to another backend.");
  } else {
    const links = {} as Record<Kind, Link>;
    for (const kind of ["proposal", "tavolo"] as const) {
      const projectId = await resolveProject(kind);
      const [link] = await demoRpc(
        owner,
        "get_current_project_participant_invitation",
        { p_expected_profile_id: owner.id, p_project_id: projectId },
      );
      if (!link)
        throw new Error(
          "PI05 demo current generation is missing; fixture never silently rotates it.",
        );
      links[kind] = {
        projectId,
        invitationId: link.invitation_id,
        token: link.invite_token,
      };
    }
    fixture = { apiUrl: status.apiUrl, links };
    writeFileSync(fixturePath, JSON.stringify(fixture), { mode: 0o600 });
    // Proposal recipient is left untouched for actual first-time UI onboarding.
    // Tavolo recipient starts with only a canonical non-photo basic profile.
    for (const key of ["tavolo", "mobile"] as const) {
      const user = await signInLocalOtpUser({
        ...status,
        mailpitUrl,
        email: emails[key],
        verifierName: `PI05 ${key}`,
      });
      const existing = await user.client
        .from("profiles")
        .select("id")
        .eq("id", user.id);
      if (existing.error) throw new Error("PI05 basic profile lookup failed.");
      if (existing.data.length === 0) {
        const anchor = await user.client
          .from("profiles")
          .insert({ id: user.id });
        if (anchor.error) throw new Error("PI05 basic profile anchor failed.");
      }
      await demoRpc(user, "update_own_profile", {
        p_expected_profile_id: user.id,
        p_display_name: `PI05 ${key}`,
        p_bio: null,
        p_skill_ids: [],
        p_display_name_audience: "public",
        p_bio_audience: "public",
        p_skills_audience: "public",
      });
    }
  }
  const association = process.argv.includes("--enabled-associations")
    ? {
        PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "invalid.planets.synthetic",
        PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: Array(32)
          .fill("AB")
          .join(":"),
        PLANETS_IOS_TEAM_ID: "ABCDE12345",
        PLANETS_IOS_BUNDLE_ID: "invalid.planets.synthetic",
      }
    : {
        PLANETS_ANDROID_APP_LINK_PACKAGE_ID: "",
        PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS: "",
        PLANETS_IOS_TEAM_ID: "",
        PLANETS_IOS_BUNDLE_ID: "",
      };
  const next = spawn(
    process.execPath,
    [
      fileURLToPath(
        new URL("../../../node_modules/next/dist/bin/next", import.meta.url),
      ),
      "start",
      "--hostname",
      "127.0.0.1",
      "--port",
      "3175",
    ],
    {
      cwd: fileURLToPath(new URL("../", import.meta.url)),
      env: { ...process.env, ...association },
      stdio: "ignore",
      windowsHide: true,
    },
  );
  const site = createServer(async (req, res) => {
    try {
      const url = new URL(req.url!, origin);
      res.setHeader("Cache-Control", "no-store");
      res.setHeader("Referrer-Policy", "no-referrer");
      if (url.pathname.startsWith("/__pi05/start/")) {
        const kind = url.pathname.split("/").at(-1) as Kind;
        if (!Object.keys(projects).includes(kind))
          throw new Error("Unknown PI05 case.");
        res.writeHead(302, {
          Location: `${origin}/join/project/${fixture.links[kind].token}`,
        });
        res.end();
      } else if (url.pathname.startsWith("/__pi05/otp/")) {
        const key = url.pathname.split("/").at(-1) as keyof typeof emails;
        if (!(key in emails)) throw new Error("Unknown synthetic mailbox.");
        const mailbox = await fetch(
          `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${emails[key]}`)}&limit=1`,
        ).then((r) => r.json());
        const message = mailbox.messages?.[0];
        if (!message) throw new Error("No synthetic PI05 OTP received.");
        const body = await fetch(
          `${mailpitUrl}/api/v1/message/${message.ID}`,
        ).then((r) => r.json());
        const code = `${body.Text} ${body.HTML}`.match(
          /(?:^|\D)(\d{6})(?:\D|$)/u,
        )?.[1];
        if (!code) throw new Error("Synthetic PI05 email lacks numeric OTP.");
        res.writeHead(200, { "Content-Type": "text/html" });
        res.end(`<main><output>${code}</output></main>`);
      } else if (url.pathname === "/__pi05/status") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(await canonicalStatus()));
      } else if (url.pathname === "/") {
        res.writeHead(200, { "Content-Type": "text/html" });
        res.end(
          `<main><h1>Disposable PI05 browser rehearsal</h1><p>Proposal: ${emails.proposal}; Tavolo: ${emails.tavolo}</p><a href="/__pi05/start/proposal">Start Proposal preview</a><br><a href="/__pi05/start/tavolo">Start Tavolo preview</a><br><a href="/proposals/${fixture.links.proposal.projectId}?intent=join">Ordinary Proposal share</a><br><a href="/tavoli/${fixture.links.tavolo.projectId}?intent=join">Ordinary Tavolo share</a></main>`,
        );
      } else {
        res.writeHead(404);
        res.end("Disposable Site fixture 404");
      }
    } catch {
      res.writeHead(500, { "Cache-Control": "no-store" });
      res.end("PI05 fixture operation failed.");
    }
  }).listen(3176, "127.0.0.1");
  const harness = createPublicHostHarness({
    publicOrigin: origin,
    webOrigin: "http://127.0.0.1:3175",
    siteOrigin: "http://127.0.0.1:3176",
  }).listen(3174, "127.0.0.1");
  function close() {
    harness.close();
    site.close();
    next.kill();
    void sql.end({ timeout: 5 });
  }
  process.once("SIGINT", close);
  process.once("SIGTERM", close);
  next.once("exit", close);
  console.log(
    "PI05 production Next and disposable Site harness started on loopback 3174–3176; logging disabled.",
  );
}
