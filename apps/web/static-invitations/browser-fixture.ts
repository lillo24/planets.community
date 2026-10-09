// Disposable local fixture only. Production client never imports this module.
import { createServer } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";

const backend = fileURLToPath(
  new URL("../.wrangler/link-host03/backend/", import.meta.url),
);
if (
  process.env.LINK_HOST03_LOCAL !== "1" ||
  !readFileSync(`${backend}/supabase/config.toml`, "utf8").includes(
    'project_id = "planets-community-link-host03"',
  )
)
  throw new Error("Owned LINK-HOST-03 opt-in required.");
const status = readLocalSupabaseStatus(backend);
if (
  status.apiUrl !== "http://127.0.0.1:59121" ||
  !status.databaseUrl ||
  new URL(status.databaseUrl).port !== "59122"
)
  throw new Error("Refusing another backend.");
const mailpit = "http://127.0.0.1:59124";
const sql = postgres(status.databaseUrl, {
  max: 2,
  onnotice: () => {},
  connection: { statement_timeout: 15000 },
});
const journal = fileURLToPath(
  new URL("../.wrangler/link-host03/fixture.json", import.meta.url),
);
const owner = "fb030300-0000-4000-8000-000000000001";
const ids = {
  proposal: "fb030300-0000-4000-8000-000000000002",
  tavolo: "fb030300-0000-4000-8000-000000000003",
  full: "fb030300-0000-4000-8000-000000000004",
  revoked: "fb030300-0000-4000-8000-000000000005",
  blocked: "fb030300-0000-4000-8000-000000000006",
};
type Kind = keyof typeof ids;
const emails = {
  proposal: "linkhost03-new@planets.invalid",
  tavolo: "linkhost03-existing@planets.invalid",
  other: "linkhost03-other@planets.invalid",
};
let links: Record<Kind, { token: string; invitationId: string }>;
async function asOwner(
  operation: (tx: postgres.TransactionSql) => Promise<unknown>,
) {
  return sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub',${owner},true)`;
    await tx.unsafe("set local role authenticated");
    return operation(tx);
  });
}
if (process.argv.includes("--seed")) {
  if ((await sql`select id from public.profiles where id=${owner}`).length)
    throw new Error("Fixture already exists; never silently reseed/reset.");
  await sql.begin(async (tx) => {
    await tx`insert into auth.users(id,email) values (${owner},'linkhost03-owner@planets.invalid')`;
    await tx`insert into public.profiles(id,display_name) values (${owner},'Synthetic LINK-HOST-03 organizer')`;
    for (const kind of ["proposal", "full", "revoked", "blocked"] as const) {
      await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,starts_at,ends_at,published_at,country_code,locality,public_location_label,event_timezone) values (${ids[kind]},${owner},'published',${`Static trial ${kind}`},'Synthetic summary','Synthetic description',now()+interval '1 day',now()+interval '2 days',now(),'IT','Trento','Trento','Europe/Rome')`;
      await tx`insert into public.proposal_meeting_details(proposal_id,exact_meeting_text) values (${ids[kind]},'Synthetic protected meeting')`;
    }
    await tx`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,summary,description,published_at,country_code,locality,public_location_label,topic) values (${ids.tavolo},${owner},'published','Static trial Tavolo','Synthetic summary','Synthetic description',now(),'IT','Trento','Trento','Gardening')`;
    await tx`insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text) values (${ids.tavolo},'Synthetic protected room')`;
    await tx`insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from) values (${ids.tavolo},'weekly',1,'18:00:00',60,'Europe/Rome',current_date)`;
    await tx`update public.projects set registration_capacity=10 where id=any(${Object.values(ids)}::uuid[])`;
    await tx`update public.projects set registration_capacity=1 where id=${ids.full}`;
  });
  links = {} as typeof links;
  for (const kind of Object.keys(ids) as Kind[]) {
    const rows = (await asOwner(
      (tx) =>
        tx`select * from public.create_project_participant_invitation(${owner},${ids[kind]})`,
    )) as { invite_token: string; invitation_id: string }[];
    links[kind] = {
      token: rows[0].invite_token,
      invitationId: rows[0].invitation_id,
    };
  }
  await asOwner(
    (tx) =>
      tx`select public.revoke_project_participant_invitation(${owner},${ids.revoked},${links.revoked.invitationId})`,
  );
  // The Creator is excluded by the canonical default capacity policy. Fill the
  // single participant slot through Auth/profile/admission APIs explicitly.
  const filler = await signInLocalOtpUser({
    ...status,
    mailpitUrl: mailpit,
    email: "linkhost03-full-fixture@planets.invalid",
    verifierName: "LINK-HOST-03 capacity fixture",
  });
  const anchor = await filler.client.from("profiles").insert({ id: filler.id });
  if (anchor.error) throw new Error("Capacity fixture profile anchor failed.");
  const profile = await filler.client.rpc("update_own_profile", {
    p_expected_profile_id: filler.id,
    p_display_name: "Synthetic capacity filler",
    p_bio: "",
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (profile.error) throw new Error("Capacity fixture profile failed.");
  const admitted = await filler.client.rpc(
    "accept_project_participant_invitation",
    {
      p_expected_profile_id: filler.id,
      p_token: links.full.token,
      p_client_action_id: crypto.randomUUID(),
    },
  );
  if (admitted.error) throw new Error("Capacity fixture admission failed.");
  // Existing account is created with canonical local OTP, not an injected UI session.
  const existing = await signInLocalOtpUser({
    ...status,
    mailpitUrl: mailpit,
    email: emails.tavolo,
    verifierName: "LINK-HOST-03 existing fixture",
  });
  await sql`insert into public.profiles(id) values (${existing.id})`;
  writeFileSync(journal, JSON.stringify({ links, apiUrl: status.apiUrl }));
  writeFileSync(
    fileURLToPath(new URL("./.env.trial-local", import.meta.url)),
    `NEXT_PUBLIC_APP_ENV=local\nNEXT_PUBLIC_SUPABASE_URL=${status.apiUrl}\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${status.publishableKey}\n`,
  );
  console.log(
    "Disposable projects and existing account prepared; capabilities stay private.",
  );
  await sql.end();
} else {
  const saved = JSON.parse(readFileSync(journal, "utf8"));
  if (saved.apiUrl !== status.apiUrl)
    throw new Error("Fixture/backend mismatch.");
  links = saved.links;
  createServer(async (request, response) => {
    try {
      const url = new URL(request.url!, "http://127.0.0.1:3193");
      response.setHeader("Cache-Control", "no-store");
      response.setHeader("Referrer-Policy", "no-referrer");
      response.setHeader("X-Robots-Tag", "noindex,nofollow,noarchive");
      const kind = url.pathname.split("/").at(-1) as Kind;
      if (url.pathname.startsWith("/start/") && kind in ids) {
        response.writeHead(302, {
          Location: `http://127.0.0.1:8797/join/project/${links[kind].token}`,
        });
        response.end();
      } else if (url.pathname.startsWith("/otp/") && kind in emails) {
        const email = emails[kind as keyof typeof emails];
        const inbox = await fetch(
          `${mailpit}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=1`,
        ).then((r) => r.json());
        if (!inbox.messages?.[0]) throw new Error("No local OTP.");
        const message = await fetch(
          `${mailpit}/api/v1/message/${inbox.messages[0].ID}`,
        ).then((r) => r.json());
        const code = `${message.Text} ${message.HTML}`.match(
          /(?:^|\D)(\d{6})(?:\D|$)/u,
        )?.[1];
        if (!code) throw new Error("No numeric OTP.");
        response.writeHead(200, { "Content-Type": "text/html" });
        response.end(`<main><output>${code}</output></main>`);
      } else if (url.pathname === "/status") {
        const rows =
          await sql`select p.display_name, count(m.id)::int as episodes, count(m.id) filter (where m.left_at is null and m.removed_at is null)::int as current_memberships, (select count(*)::int from public.profile_photos where profile_id=p.id) as photos from public.profiles p join auth.users u on u.id=p.id left join public.project_memberships m on m.participant_profile_id=p.id and m.project_id=any(${Object.values(ids)}::uuid[]) where u.email=any(${Object.values(emails)}::text[]) group by p.id order by p.display_name nulls last`;
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify(rows));
      } else if (url.pathname === "/") {
        response.writeHead(200, { "Content-Type": "text/html" });
        response.end(
          `<main><h1>Disposable static browser trial</h1><p>New: ${emails.proposal}; existing: ${emails.tavolo}; switch: ${emails.other}</p>${Object.keys(
            ids,
          )
            .map((k) => `<p><a href="/start/${k}">Open ${k}</a></p>`)
            .join("")}</main>`,
        );
      } else {
        response.writeHead(404);
        response.end("Not found");
      }
    } catch {
      response.writeHead(500);
      response.end("Local fixture failed.");
    }
  }).listen(3193, "127.0.0.1");
  console.log(
    "Private loopback launch/OTP/status helper on 3193; no access logging.",
  );
  process.once("SIGINT", () => {
    void sql.end().then(() => process.exit());
  });
}
