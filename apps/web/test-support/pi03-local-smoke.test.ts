// @vitest-environment node
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { createServerClient, serializeCookieHeader } from "@supabase/ssr";
import { expect, it, vi } from "vitest";
import type { Database } from "@/types/database.generated";
import { SupabaseParticipantGateway } from "@/features/project-participant-invites/participant-gateway";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
vi.mock("client-only", () => ({}));

const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const webRoot = fileURLToPath(new URL("../", import.meta.url));
const appUrl = "http://127.0.0.1:3153";
const pause = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Explicit opt-in; never contacts a backend during ordinary unit tests or hosted Web CI.
it.skipIf(process.env.PI03_LOCAL_SMOKE !== "1")(
  "production HTTP and production gateway: photo-free admission, history, recovery and headers",
  async () => {
    const config = readFileSync(
      new URL("../../../supabase/config.toml", import.meta.url),
      "utf8",
    );
    if (!config.includes('project_id = "planets-community-pi03"'))
      throw new Error(
        "This verifier requires its own disposable planets-community-pi03 backend.",
      );
    const { apiUrl, publishableKey, databaseUrl } =
      readLocalSupabaseStatus(repositoryRoot);
    if (
      !databaseUrl ||
      new URL(apiUrl).hostname !== "127.0.0.1" ||
      new URL(apiUrl).port !== "58621"
    )
      throw new Error("PI03 verifier requires local ports 58620–58629.");
    const sql = postgres(databaseUrl, {
      max: 2,
      connection: { statement_timeout: 15000 },
    });
    const server = spawn(
      process.execPath,
      [
        fileURLToPath(
          new URL("../../../node_modules/next/dist/bin/next", import.meta.url),
        ),
        "start",
        "--hostname",
        "127.0.0.1",
        "--port",
        "3153",
      ],
      { cwd: webRoot, stdio: ["ignore", "pipe", "pipe"], windowsHide: true },
    );
    // Keep runtime logs private: Next may log a requested secret-bearing URL on error.
    server.stdout?.resume();
    server.stderr?.resume();
    try {
      for (let retry = 0; ; retry++) {
        try {
          if ((await fetch(appUrl)).ok) break;
        } catch {
          /* server startup boundary */
        }
        if (server.exitCode !== null || retry > 120)
          throw new Error(
            "PI03 production Next server did not start on port 3153.",
          );
        await pause(250);
      }
      const jar = new Map<string, string>();
      const client = createServerClient<Database>(apiUrl, publishableKey, {
        cookies: {
          getAll: () => [...jar].map(([name, value]) => ({ name, value })),
          setAll: (cookies) =>
            cookies.forEach(({ name, value }) => {
              if (value) jar.set(name, value);
              else jar.delete(name);
            }),
        },
      });
      const gateway = new SupabaseParticipantGateway(client);
      const email = "pi03-photo-free@planets.invalid";
      async function signIn() {
        const messages = await fetch(
          "http://127.0.0.1:58624/api/v1/messages",
        ).then((r) => r.json());
        const before = new Set(
          messages.messages.map((m: { ID: string }) => m.ID),
        );
        const request = await client.auth.signInWithOtp({
          email,
          options: { shouldCreateUser: true },
        });
        if (request.error) throw new Error("PI03 local OTP request failed.");
        let code: string | undefined;
        for (let retry = 0; retry < 120 && !code; retry++) {
          const mailbox = await fetch(
            "http://127.0.0.1:58624/api/v1/messages",
          ).then((r) => r.json());
          const message = mailbox.messages.find(
            (m: { ID: string; To: { Address: string }[] }) =>
              !before.has(m.ID) && m.To.some((to) => to.Address === email),
          );
          if (message) {
            const body = await fetch(
              `http://127.0.0.1:58624/api/v1/message/${message.ID}`,
            ).then((r) => r.json());
            code = `${body.Text} ${body.HTML}`.match(
              /(?:^|\D)(\d{6})(?:\D|$)/,
            )?.[1];
          }
          if (!code) await pause(250);
        }
        if (!code) throw new Error("PI03 local numeric OTP was not delivered.");
        const verification = await client.auth.verifyOtp({
          email,
          token: code,
          type: "email",
        });
        if (verification.error || !verification.data.user)
          throw new Error("PI03 local numeric OTP verification failed.");
        return verification.data.user.id;
      }
      const recipient = await signIn();
      expect((await gateway.auth()).phase).toBe("missingProfile");
      const anchor = await client.from("profiles").insert({ id: recipient });
      if (anchor.error) throw new Error("PI03 own-profile anchor failed.");
      expect((await gateway.auth()).phase).toBe("incompleteProfile");
      const owner = "fb030000-0000-4000-8000-000000000001";
      const proposal = "fb030000-0000-4000-8000-000000000002";
      const tavolo = "fb030000-0000-4000-8000-000000000003";
      const requestId = "fb030000-0000-4000-8000-000000000004";
      const resource = "fb030000-0000-4000-8000-000000000005";
      await sql.begin(async (tx) => {
        await tx`insert into auth.users(id,email) values (${owner},'pi03-owner@planets.invalid')`;
        await tx`insert into public.profiles(id,display_name) values (${owner},'Synthetic PI03 organizer')`;
        await tx`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,starts_at,ends_at,published_at,country_code,locality,public_location_label) values (${proposal},${owner},'published','PI03 public mural','Synthetic public summary','Synthetic public description',now()+interval '1 day',now()+interval '2 days',now(),'IT','Trento','Trento')`;
        await tx`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,summary,description,published_at,country_code,locality,public_location_label) values (${tavolo},${owner},'published','PI03 public Tavolo','Synthetic public summary','Synthetic public description',now(),'IT','Trento','Trento')`;
        await tx`update public.projects set registration_capacity=10 where id in (${proposal},${tavolo})`;
        await tx`update public.proposals set event_timezone='Europe/Rome' where id=${proposal}`;
        await tx`insert into public.proposal_meeting_details(proposal_id,exact_meeting_text) values (${proposal},'Synthetic protected mural room')`;
        await tx`update public.recurring_activities set topic='Gardening' where id=${tavolo}`;
        await tx`insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text) values (${tavolo},'Synthetic protected Tavolo room')`;
        await tx`insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from) values (${tavolo},'weekly',1,'18:00:00',60,'Europe/Rome',current_date)`;
        await tx`insert into public.project_join_requests(id,project_id,requester_profile_id,request_message) values (${requestId},${proposal},${recipient},'Keep this synthetic offer')`;
        await tx`insert into public.project_join_request_skill_selections(request_id,skill_id) select ${requestId},id from public.skills order by id limit 1`;
        await tx`insert into public.project_resource_needs(id,project_id,title) values (${resource},${proposal},'Synthetic tools')`;
        await tx`insert into public.project_join_request_resource_selections(request_id,resource_need_id) values (${requestId},${resource})`;
        await tx`insert into public.project_join_request_chat_messages(chat_id,sender_profile_id,body) select id,${recipient},'Keep this synthetic message' from public.project_join_request_chats where request_id=${requestId}`;
      });
      async function asOwner(
        operation: (tx: postgres.TransactionSql) => Promise<unknown>,
      ) {
        return sql.begin(async (tx) => {
          await tx`select set_config('request.jwt.claim.sub',${owner},true)`;
          await tx.unsafe("set local role authenticated");
          return operation(tx);
        });
      }
      async function link(id: string) {
        const rows = (await asOwner(
          (tx) =>
            tx`select * from public.create_project_participant_invitation(${owner},${id})`,
        )) as { invitation_id: string; invite_token: string }[];
        return rows[0];
      }
      const proposalLink = await link(proposal);
      const tavoloLink = await link(tavolo);
      const special = `/join/project/${proposalLink.invite_token}`;
      const cookie = () =>
        [...jar]
          .map(([name, value]) => serializeCookieHeader(name, value, {}))
          .join("; ");
      async function page(
        path: string,
        authenticated = false,
        prefetch = false,
      ) {
        const response = await fetch(`${appUrl}${path}`, {
          redirect: "manual",
          headers: {
            ...(authenticated ? { Cookie: cookie() } : {}),
            ...(prefetch ? { "Next-Router-Prefetch": "1" } : {}),
          },
        });
        expect(response.headers.get("cache-control")).toContain("no-store");
        expect(response.headers.get("referrer-policy")).toBe("no-referrer");
        expect(response.headers.get("x-robots-tag")).toContain("noindex");
        return { response, body: await response.text() };
      }
      expect((await gateway.preview(proposalLink.invite_token)).available).toBe(
        true,
      );
      expect((await gateway.preview(tavoloLink.invite_token)).available).toBe(
        true,
      );
      expect((await page(special)).body).toContain("PI03 public mural");
      await page(special, false, true);
      expect(
        (await page(`/auth?returnTo=${encodeURIComponent(special)}`)).body,
      ).toContain("Send code");
      expect(
        (await page(`/auth?returnTo=${encodeURIComponent(special)}`, true))
          .body,
      ).toContain("Complete your profile");
      expect(
        (await page(`/profile?returnTo=${encodeURIComponent(special)}`, true))
          .body,
      ).toContain("Display name");
      expect((await page(`/invite/project/${"a".repeat(43)}`)).body).toContain(
        "Invitation unavailable",
      );
      const [before] =
        await sql`select count(*)::integer as n from public.project_memberships where participant_profile_id=${recipient}`;
      expect(before.n).toBe(0);
      const completion = await client.rpc("update_own_profile", {
        p_expected_profile_id: recipient,
        p_display_name: "Synthetic PI03 participant",
        p_bio: "",
        p_skill_ids: [],
        p_display_name_audience: "public",
        p_bio_audience: "public",
        p_skills_audience: "public",
      });
      if (completion.error)
        throw new Error("PI03 photo-free profile completion failed.");
      expect((await gateway.auth()).phase).toBe("ready");
      for (const [kind, id] of [
        ["proposals", proposal],
        ["tavoli", tavolo],
      ]) {
        const ordinary = await fetch(`${appUrl}/${kind}/${id}?intent=join`);
        expect(ordinary.status).toBe(200);
        const body = await ordinary.text();
        expect(body.includes("Want to join?")).toBe(true);
        expect(body.includes("Synthetic protected")).toBe(false);
        const duplicate = await fetch(
          `${appUrl}/${kind}/${id}?intent=join&intent=join`,
        );
        expect((await duplicate.text()).includes("Want to join?")).toBe(false);
      }
      const action = randomUUID();
      const joined = await gateway.accept(
        recipient,
        proposalLink.invite_token,
        action,
      );
      expect(joined.outcome).toBe("joined");
      expect(joined.membershipStatus).toBe("current");
      await gateway.accept(recipient, tavoloLink.invite_token, randomUUID());
      const [counts] =
        await sql`select (select count(*) from public.profile_photos where profile_id=${recipient})::integer as photos,(select count(*) from public.project_membership_skill_commitments c join public.project_memberships m on m.id=c.membership_id where m.participant_profile_id=${recipient})::integer as skills,(select count(*) from public.project_membership_resource_commitments c join public.project_memberships m on m.id=c.membership_id where m.participant_profile_id=${recipient})::integer as resources`;
      expect(counts).toEqual({ photos: 0, skills: 0, resources: 0 });
      const [history] =
        await sql`select r.status,r.resolution_reason,r.request_message,(select count(*) from public.project_join_request_skill_selections where request_id=r.id)::integer as skills,(select count(*) from public.project_join_request_resource_selections where request_id=r.id)::integer as resources,(select count(*) from public.project_join_request_chat_messages m join public.project_join_request_chats c on c.id=m.chat_id where c.request_id=r.id)::integer as messages from public.project_join_requests r where r.id=${requestId}`;
      expect(history).toEqual({
        status: "withdrawn",
        resolution_reason: "direct_participant_invitation",
        request_message: "Keep this synthetic offer",
        skills: 1,
        resources: 1,
        messages: 1,
      });
      await asOwner(
        (tx) =>
          tx`select public.revoke_project_participant_invitation(${owner},${proposal},${proposalLink.invitation_id})`,
      );
      expect((await gateway.preview(proposalLink.invite_token)).available).toBe(
        false,
      );
      expect(
        (await gateway.accept(recipient, proposalLink.invite_token, action))
          .replayed,
      ).toBe(true);
      expect(
        await gateway.participation(recipient, {
          id: proposal,
          kind: "one_time",
        }),
      ).toEqual({ current: true, creator: false });
      const confirmation = `/joined/proposals/${proposal}`;
      expect((await page(confirmation, true)).body).toContain(
        "You currently participate",
      );
      expect((await page(confirmation, true)).body).toContain(
        "You currently participate",
      );
      expect((await page(confirmation)).body).not.toContain(
        "You currently participate",
      );
      const left = await client.rpc("leave_project", {
        p_expected_participant_profile_id: recipient,
        p_membership_id: joined.membershipId!,
      });
      if (left.error) throw new Error("PI03 canonical leave failed.");
      expect(
        (await gateway.accept(recipient, proposalLink.invite_token, action))
          .membershipStatus,
      ).toBe("left");
      expect((await page(confirmation, true)).body).not.toContain(
        "You currently participate",
      );
      expect(
        (
          await gateway.participation(recipient, {
            id: proposal,
            kind: "one_time",
          })
        ).current,
      ).toBe(false);
      const rotated = await link(proposal);
      const fresh = await gateway.accept(
        recipient,
        rotated.invite_token,
        randomUUID(),
      );
      expect(fresh.membershipId).not.toBe(joined.membershipId);
      expect(
        (await gateway.accept(recipient, proposalLink.invite_token, action))
          .membershipStatus,
      ).toBe("left");
      expect(
        (
          await gateway.participation(recipient, {
            id: proposal,
            kind: "one_time",
          })
        ).current,
      ).toBe(true);
      console.log(
        "PI03 production HTTP/security headers and real gateway checks passed; no tokens or credentials logged.",
      );
    } finally {
      server.kill();
      await sql.end();
    }
  },
  120000,
);
