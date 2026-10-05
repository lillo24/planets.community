// Explicit disposable rehearsal only. No token, OTP, session or request logging.
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { createPublicHostHarness } from "./public-host-harness.ts";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const config = readFileSync(
  new URL("../../../supabase/config.toml", import.meta.url),
  "utf8",
);
if (
  process.env.PI04_LOCAL_REHEARSAL !== "1" ||
  !config.includes('project_id = "planets-community-pi04"')
) {
  throw new Error(
    "Explicit PI04_LOCAL_REHEARSAL=1 and disposable planets-community-pi04 stack required.",
  );
}
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(root);
if (
  !databaseUrl ||
  new URL(apiUrl).hostname !== "127.0.0.1" ||
  new URL(apiUrl).port !== "58721"
) {
  throw new Error("PI04 requires disposable loopback ports 58720–58729.");
}
const sql = postgres(databaseUrl, {
  max: 2,
  connection: { statement_timeout: 15000 },
});
const origin = "http://127.0.0.1:3154";
const mail = "http://127.0.0.1:58724";
const fixturePath = new URL("../../../.env.pi04-browser.json", import.meta.url);
const email = "pi04-browser@planets.invalid";
const owner = "fb040000-0000-4000-8000-000000000001";
const proposal = "fb040000-0000-4000-8000-000000000002";
const tavolo = "fb040000-0000-4000-8000-000000000003";

async function latestCode(): Promise<string> {
  const mailbox = await fetch(`${mail}/api/v1/messages`).then((r) => r.json());
  const message = mailbox.messages.find((m: { To: { Address: string }[] }) =>
    m.To.some((to) => to.Address === email),
  );
  if (!message) throw new Error("Synthetic PI04 OTP has not arrived.");
  const body = await fetch(`${mail}/api/v1/message/${message.ID}`).then((r) =>
    r.json(),
  );
  const code = `${body.Text} ${body.HTML}`.match(
    /(?:^|\D)(\d{6})(?:\D|$)/,
  )?.[1];
  if (!code)
    throw new Error("Synthetic PI04 email did not contain numeric OTP.");
  return code;
}

if (process.argv.includes("--capture-mobile")) {
  const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
  const client = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const sent = await client.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: false },
  });
  if (sent.error) throw new Error("PI04 same-account OTP request failed.");
  const verified = await client.auth.verifyOtp({
    email,
    token: await latestCode(),
    type: "email",
  });
  if (verified.error || !verified.data.session)
    throw new Error("PI04 same-account OTP verification failed.");
  const participant = verified.data.session.user.id;
  const [row] =
    await sql`select count(*)::int as count from public.project_memberships where participant_profile_id=${participant} and project_id=${proposal} and left_at is null and removed_at is null`;
  if (row.count !== 1)
    throw new Error(
      "Browser must explicitly join the Proposal before mobile capture.",
    );
  await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub',${owner},true)`;
    await tx.unsafe("set local role authenticated");
    for (const link of [fixture.proposalLink, fixture.tavoloLink]) {
      await tx`select public.revoke_project_participant_invitation(${owner},${link.project},${link.id})`;
    }
  });
  writeFileSync(
    new URL("../../../apps/mobile/config/local.json", import.meta.url),
    JSON.stringify({
      APP_ENV: "local",
      SUPABASE_URL: apiUrl,
      SUPABASE_PUBLISHABLE_KEY: publishableKey,
      PI04_PARTICIPANT: participant,
      PI04_ACCESS_TOKEN: verified.data.session.access_token,
      PI04_PROPOSAL: proposal,
      PI04_TAVOLO: tavolo,
      PI04_PROPOSAL_TOKEN: fixture.proposalLink.token,
      PI04_TAVOLO_TOKEN: fixture.tavoloLink.token,
    }),
  );
  await sql.end();
  console.log(
    "PI04 same-account mobile fixture captured; both original links revoked.",
  );
} else {
  if (!process.argv.includes("--reuse")) {
    await sql.begin(async (tx) => {
      await tx`insert into auth.users(id,email) values (${owner},'pi04-owner@planets.invalid')`;
      await tx`insert into public.profiles(id,display_name) values (${owner},'Synthetic PI04 organizer')`;
      await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,starts_at,ends_at,published_at,country_code,locality,public_location_label) values (${proposal},${owner},'published','PI04 public mural','Synthetic public summary','Synthetic public description',now()+interval '1 day',now()+interval '2 days',now(),'IT','Trento','Trento')`;
      await tx`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,summary,description,published_at,country_code,locality,public_location_label) values (${tavolo},${owner},'published','PI04 public Tavolo','Synthetic public summary','Synthetic public description',now(),'IT','Trento','Trento')`;
      await tx`update public.projects set registration_capacity=10 where id in (${proposal},${tavolo})`;
      await tx`update public.proposals set event_timezone='Europe/Rome' where id=${proposal}`;
      await tx`insert into public.proposal_meeting_details(proposal_id,exact_meeting_text) values (${proposal},'Synthetic protected mural room')`;
      await tx`update public.recurring_activities set topic='Gardening' where id=${tavolo}`;
      await tx`insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text) values (${tavolo},'Synthetic protected Tavolo room')`;
      await tx`insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from) values (${tavolo},'weekly',1,'18:00:00',60,'Europe/Rome',current_date)`;
    });
    const links = await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub',${owner},true)`;
      await tx.unsafe("set local role authenticated");
      const result = [];
      for (const project of [proposal, tavolo]) {
        const [link] =
          await tx`select * from public.create_project_participant_invitation(${owner},${project})`;
        result.push({
          project,
          id: link.invitation_id,
          token: link.invite_token,
        });
      }
      return result;
    });
    writeFileSync(
      fixturePath,
      JSON.stringify({ proposalLink: links[0], tavoloLink: links[1] }),
    );
  }
  const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
  await sql.end();
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
      "3155",
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
      if (
        req.url === "/__pi04/start/proposal" ||
        req.url === "/__pi04/start/tavolo"
      ) {
        const link = req.url.endsWith("proposal")
          ? fixture.proposalLink
          : fixture.tavoloLink;
        res.writeHead(302, {
          Location: `${origin}/join/project/${link.token}`,
          "Cache-Control": "no-store",
          "Referrer-Policy": "no-referrer",
        });
        res.end();
      } else if (req.url === "/__pi04/otp") {
        res.writeHead(200, {
          "Content-Type": "text/html",
          "Cache-Control": "no-store",
        });
        res.end(`<main><output>${await latestCode()}</output></main>`);
      } else if (req.url === "/") {
        res.writeHead(200, {
          "Content-Type": "text/html",
          "Cache-Control": "no-store",
        });
        res.end(
          `<main><h1>Disposable PI04 browser rehearsal</h1><a href="/__pi04/start/proposal">Start Proposal preview</a><a href="/__pi04/start/tavolo">Start Tavolo preview</a><a href="/proposals/${proposal}?intent=join">Ordinary share</a></main>`,
        );
      } else {
        res.writeHead(404, { "Cache-Control": "no-store" });
        res.end("Disposable Site fixture 404");
      }
    } catch {
      res.writeHead(500, { "Cache-Control": "no-store" });
      res.end("PI04 fixture operation failed.");
    }
  }).listen(3156, "127.0.0.1");
  const harness = createPublicHostHarness({
    publicOrigin: origin,
    webOrigin: "http://127.0.0.1:3155",
    siteOrigin: "http://127.0.0.1:3156",
  }).listen(3154, "127.0.0.1");
  function close() {
    harness.close();
    site.close();
    next.kill();
  }
  process.once("SIGINT", close);
  process.once("SIGTERM", close);
  next.once("exit", () => {
    harness.close();
    site.close();
  });
  console.log(
    "PI04 production Next and disposable Site harness started on loopback ports 3154–3156; request logging disabled.",
  );
}
