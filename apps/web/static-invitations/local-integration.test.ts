// @vitest-environment node
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { expect, it, vi } from "vitest";
import { readLocalSupabaseStatus } from "../../../scripts/lib/local-supabase-status.mjs";
import { SupabaseWebAuthGateway } from "../src/features/auth/auth-gateway";
import { SupabaseWebProfileGateway } from "../src/features/profile/profile-gateway";
import { SupabaseParticipantGateway } from "../src/features/project-participant-invites/participant-gateway";
import { ParticipantController } from "../src/features/project-participant-invites/participant-controller";
vi.mock("client-only", () => ({}));
it.skipIf(process.env.LINK_HOST03_LOCAL !== "1")(
  "uses real local OTP/profile/admission/replay/departure contracts (not real-browser proof)",
  async () => {
    const backend = fileURLToPath(
      new URL("../.wrangler/link-host03/backend/", import.meta.url),
    );
    expect(readFileSync(`${backend}/supabase/config.toml`, "utf8")).toContain(
      'project_id = "planets-community-link-host03"',
    );
    const status = readLocalSupabaseStatus(backend);
    expect(status.apiUrl).toBe("http://127.0.0.1:59121");
    expect(new URL(status.databaseUrl!).port).toBe("59122");
    const fixture = JSON.parse(
      readFileSync(
        new URL("../.wrangler/link-host03/fixture.json", import.meta.url),
        "utf8",
      ),
    );
    expect(fixture.apiUrl).toBe(status.apiUrl);
    const sql = postgres(status.databaseUrl!, { max: 1, onnotice: () => {} });
    const owner = "fb030300-0000-4000-8000-000000000001";
    const client = createClient(status.apiUrl, status.publishableKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    });
    const gateway = new SupabaseParticipantGateway(client);
    let actions = 0;
    let loseResponse = true;
    const originalAccept = gateway.accept.bind(gateway);
    gateway.accept = async (...args) => {
      actions++;
      const result = await originalAccept(...args);
      if (loseResponse) {
        loseResponse = false;
        throw new Error("Synthetic lost response after committed admission.");
      }
      return result;
    };
    const controller = new ParticipantController(gateway);
    const auth = new SupabaseWebAuthGateway(client);
    const profiles = new SupabaseWebProfileGateway(client);
    async function count(id: string) {
      const [row] =
        await sql`select count(*)::int as episodes, count(*) filter (where left_at is null and removed_at is null)::int as current from public.project_memberships where participant_profile_id=${id} and project_id=any(${["fb030300-0000-4000-8000-000000000002", "fb030300-0000-4000-8000-000000000003"]}::uuid[])`;
      return row;
    }
    async function otp(email: string) {
      await auth.requestEmailOtp(email);
      const inbox = await fetch(
        `http://127.0.0.1:59124/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=1`,
      ).then((r) => r.json());
      const body = await fetch(
        `http://127.0.0.1:59124/api/v1/message/${inbox.messages[0].ID}`,
      ).then((r) => r.json());
      const code = `${body.Text} ${body.HTML}`.match(
        /(?:^|\D)(\d{6})(?:\D|$)/u,
      )?.[1];
      expect(typeof code).toBe("string");
      await auth.verifyEmailOtp(email, code!);
      await auth.ensureCurrentProfileAnchor();
      const { data } = await client.auth.getClaims();
      return data!.claims.sub;
    }
    try {
      const [backendVersion] =
        await sql`select current_setting('server_version') as version, (select count(*)::int from supabase_migrations.schema_migrations) as migrations`;
      console.info(
        JSON.stringify({ backend: "owned-local", ...backendVersion }),
      );
      for (const kind of ["proposal", "tavolo"] as const) {
        const before = actions;
        await controller.openInvite(fixture.links[kind].token);
        expect(controller.snapshot().auth?.phase).toBe("signedOut");
        expect(actions).toBe(before);
        const id = await otp(
          `linkhost03-adapter-${kind}-${crypto.randomUUID().slice(0, 8)}@planets.invalid`,
        );
        await controller.refresh();
        expect(controller.snapshot().auth?.phase).toBe("incompleteProfile");
        expect((await count(id)).episodes).toBe(0);
        await profiles.updateOwnProfile({
          expectedProfileId: id,
          displayName: `Adapter ${kind}`,
          bio: "",
          selectedSkillIds: [],
          visibility: {
            display_name: "private",
            bio: "private",
            skills: "private",
          },
        });
        await controller.refresh();
        expect(controller.snapshot().auth?.phase).toBe("ready");
        expect((await count(id)).episodes).toBe(0);
        const refreshed = await client.auth.refreshSession();
        expect(refreshed.error).toBeNull();
        await controller.refresh();
        expect(controller.snapshot().auth?.phase).toBe("ready");
        expect((await count(id)).episodes).toBe(0);
        await Promise.all([controller.join(), controller.join()]);
        if (kind === "proposal") {
          expect(controller.snapshot().failure).toBeDefined();
          expect((await count(id)).episodes).toBe(1);
          await controller.join();
          expect(controller.snapshot().receipt?.replayed).toBe(true);
        }
        expect(controller.snapshot().participation?.current).toBe(true);
        expect((await count(id)).episodes).toBe(1);
        // A new SDK/controller process restores Auth, not an admission attempt.
        // This is adapter proof, not browser cookie/reload/cross-tab proof.
        const restoredClient = createClient(
          status.apiUrl,
          status.publishableKey,
          {
            auth: {
              persistSession: false,
              autoRefreshToken: false,
              detectSessionInUrl: false,
            },
          },
        );
        const session = (await client.auth.getSession()).data.session!;
        const restored = await restoredClient.auth.setSession({
          access_token: session.access_token,
          refresh_token: session.refresh_token,
        });
        expect(restored.error).toBeNull();
        const restoredController = new ParticipantController(
          new SupabaseParticipantGateway(restoredClient),
        );
        try {
          await restoredController.openInvite(fixture.links[kind].token);
          // INITIAL_SESSION can invalidate the first read and schedule its
          // canonical replacement outside the SDK's locked callback.
          await vi.waitFor(() => {
            expect(restoredController.snapshot().participation?.current).toBe(
              true,
            );
          });
          expect(restoredController.snapshot().participation?.current).toBe(
            true,
          );
          expect(restoredController.snapshot().receipt).toBeUndefined();
          expect((await count(id)).episodes).toBe(1);
        } finally {
          restoredController.dispose();
        }
        // Confirmation is a fresh current-membership read, never a trusted URL flag.
        const project = controller.snapshot().project!;
        await controller.openConfirmation(project);
        expect(controller.snapshot().participation?.current).toBe(true);
        const [membership] =
          await sql`select id from public.project_memberships where participant_profile_id=${id} and project_id=${project.id} and left_at is null and removed_at is null`;
        const departure = await client.rpc("leave_project", {
          p_expected_participant_profile_id: id,
          p_membership_id: membership.id,
        });
        expect(departure.error).toBeNull();
        await controller.retryReads();
        expect(controller.snapshot().participation?.current).toBe(false);
        expect((await count(id)).episodes).toBe(1);
        await controller.openInvite(fixture.links[kind].token);
        await controller.join(true);
        expect(controller.snapshot().participation?.current).toBe(true);
        expect((await count(id)).episodes).toBe(2);
        const [photo] =
          await sql`select count(*)::int as n from public.profile_photos where profile_id=${id}`;
        expect(photo.n).toBe(0);
        await controller.openInvite(fixture.links.revoked.token);
        expect(controller.snapshot().preview?.available).toBe(false);
        await controller.openInvite(fixture.links.full.token);
        await controller.join();
        expect(controller.snapshot().failure).toBe("full");
        const block = await client.rpc("block_user", {
          p_expected_blocker_profile_id: id,
          p_blocked_profile_id: owner,
        });
        expect(block.error).toBeNull();
        await controller.openInvite(fixture.links.blocked.token);
        await controller.join();
        expect(controller.snapshot().failure).toBe("unavailable");
        const unblock = await client.rpc("unblock_user", {
          p_expected_blocker_profile_id: id,
          p_blocked_profile_id: owner,
        });
        expect(unblock.error).toBeNull();
        const [reentered] =
          await sql`select id from public.project_memberships where participant_profile_id=${id} and project_id=${project.id} and left_at is null and removed_at is null`;
        const cleanup = await client.rpc("leave_project", {
          p_expected_participant_profile_id: id,
          p_membership_id: reentered.id,
        });
        expect(cleanup.error).toBeNull();
        await auth.signOut();
        await new Promise((resolve) => setTimeout(resolve, 25));
        await controller.refresh();
        expect(controller.snapshot().auth?.phase).toBe("signedOut");
        expect(controller.snapshot().receipt).toBeUndefined();
      }
      // Assert the fixture owner remains separate from real verified recipients.
      expect(
        (await sql`select id from public.profiles where id=${owner}`).length,
      ).toBe(1);
    } finally {
      controller.dispose();
      await client.auth.signOut();
      await sql.end();
    }
  },
  60000,
);
