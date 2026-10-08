import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import {
  asConsequenceActor,
  createConsequenceFixture,
} from "./lib/moderation-consequence-fixtures.mjs";
import { normalizeResults } from "../supabase/functions/location-search/provider.mjs";

assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "Location suspension requires disposable QA",
);
const { apiUrl, databaseUrl, publishableKey, serviceRoleKey } =
  readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL;
for (const url of [apiUrl, databaseUrl, mailpitUrl])
  assert.ok(
    url && ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
    "Explicit loopback location QA target required",
  );
const sql = postgres(databaseUrl, { max: 6, onnotice: () => {} });
const service = createClient(apiUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const original = (
  await sql`select * from private.location_search_config where singleton`
)[0];
const places = normalizeResults(
  {
    results: [
      {
        country_code: "it",
        city: "Synthetic area",
        result_type: "city",
        formatted: "Synthetic area",
        lat: 45,
        lon: 12,
        datasource: { sourcename: "openstreetmap" },
      },
    ],
  },
  "en",
);
let checks = 0,
  races = 0;
const check = (value, message) => {
  assert.ok(value, message);
  checks++;
};
async function rpc(client, name, args) {
  const result = await client.rpc(name, args);
  if (result.error)
    throw new Error(`Location QA ${name} (${result.error.code})`);
  return result.data;
}
async function denied(client, name, args, code = "PT403") {
  const { error } = await client.rpc(name, args);
  check(error?.code === code, `${name}: canonical ${code} denial required`);
  if (code === "PT403")
    check(
      error.message === "Account access is suspended.",
      "Denial contains no subject/staff detail",
    );
}
async function counts() {
  const [row] =
    await sql`select (select coalesce(sum(used),0)::int from private.location_search_budgets) budgets,
    (select count(*)::int from private.location_search_batches) batches,
    (select count(*)::int from private.location_selection_receipts) receipts`;
  return row;
}
try {
  const users = {};
  for (const role of ["admin", "owner", "cocreator"]) {
    users[role] = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `modint-location-${role}-${randomUUID()}@planets.invalid`,
      verifierName: `MODINT location ${role}`,
    });
    await sql`insert into public.profiles(id,display_name) values(${users[role].id},'Synthetic location QA')`;
  }
  const actors = Object.fromEntries(
    [
      "admin",
      "owner",
      "cocreator",
      "moderator",
      "coorganizer",
      "requester",
      "unrelated",
    ].map((role) => [role, users[role]?.id ?? randomUUID()]),
  );
  for (const role of ["moderator", "coorganizer", "requester", "unrelated"]) {
    await sql`insert into auth.users(id,email) values(${actors[role]},${`modint-location-fixture-${actors[role]}@planets.invalid`})`;
    await sql`insert into public.profiles(id,display_name) values(${actors[role]},'Synthetic location fixture')`;
  }
  const fixture = await createConsequenceFixture(sql, actors);
  const table = randomUUID();
  await sql`insert into public.recurring_activities(id,creator_profile_id,country_code,locality,public_location_label)
    values(${table},${actors.owner},'IT','Synthetic','Synthetic')`;
  await sql`insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text,exact_location_visibility)
    values(${table},'Synthetic private meeting','participants')`;
  const ownerCase = (
    await sql`insert into private.moderation_cases(state,subject_profile_id,target_kind,target_profile_id)
    values('under_review',${actors.owner},'profile',${actors.owner}) returning id`
  )[0].id;
  const caseFor = {
    [actors.owner]: ownerCase,
    [actors.cocreator]: (
      await sql`insert into private.moderation_cases(state,subject_profile_id,target_kind,target_profile_id)
    values('under_review',${actors.cocreator},'profile',${actors.cocreator}) returning id`
    )[0].id,
  };
  await sql`update private.location_search_config set enabled=true where singleton`;
  const scopes = [];
  for (const [kind, item, actor] of [
    ["one_time", fixture.projectId, actors.owner],
    ["recurring", table, actors.owner],
    ["resource", fixture.listingId, actors.owner],
    ["one_time", fixture.projectId, actors.cocreator],
  ]) {
    const saved = await rpc(
      users[actor === actors.cocreator ? "cocreator" : "owner"].client,
      "get_authorized_item_location_v1",
      { p_expected_profile_id: actor, p_kind: kind, p_item: item },
    );
    const scope = {
      p_actor: actor,
      p_kind: kind,
      p_item: item,
      p_revision: saved.revision,
      p_slot: kind === "resource" ? "public" : "area",
      p_session: randomUUID(),
      p_query_hash: randomUUID().replaceAll("-", "").repeat(2),
    };
    const batch = await rpc(service, "reserve_location_search_v1", scope);
    const issued = await rpc(service, "issue_location_selections_v1", {
      p_batch: batch.batch_id,
      p_places: places,
    });
    check(
      issued.suggestions.length === 1,
      "Active Creator/Co-creator/Resource owner service access",
    );
    const pending = await rpc(service, "reserve_location_search_v1", {
      ...scope,
      p_session: randomUUID(),
      p_query_hash: randomUUID().replaceAll("-", "").repeat(2),
    });
    scopes.push({
      scope,
      receipt: issued.suggestions[0].id,
      pending: pending.batch_id,
    });
  }
  for (const actor of [actors.owner, actors.cocreator]) {
    const episode = await rpc(users.admin.client, "apply_account_suspension", {
      p_expected_staff_profile_id: actors.admin,
      p_case_id: caseFor[actor],
      p_user_reason: "Synthetic access reason",
      p_internal_note: "Synthetic private note",
    });
    const before = await counts();
    for (const { scope, receipt, pending } of scopes.filter(
      (x) => x.scope.p_actor === actor,
    )) {
      await denied(service, "reserve_location_search_v1", {
        ...scope,
        p_session: randomUUID(),
      });
      await denied(service, "reserve_location_search_v1", scope);
      await denied(service, "issue_location_selections_v1", {
        p_batch: pending,
        p_places: places,
      });
      const { p_query_hash, ...resolve } = scope;
      await denied(service, "resolve_location_selection_v1", {
        ...resolve,
        p_receipt: receipt,
      });
      const client =
        users[actor === actors.owner ? "owner" : "cocreator"].client;
      await denied(client, "get_authorized_item_location_v1", {
        p_expected_profile_id: actor,
        p_kind: scope.p_kind,
        p_item: scope.p_item,
      });
      await denied(client, "apply_item_location_v1", {
        p_expected_profile_id: actor,
        p_kind: scope.p_kind,
        p_item: scope.p_item,
        p_expected_revision: scope.p_revision,
        p_request_id: randomUUID(),
        p_public_action: "clear",
        p_public_receipt: null,
        p_exact_action: "unchanged",
        p_exact_receipt: null,
      });
      await denied(
        client,
        "get_authorized_item_location_v1",
        {
          p_expected_profile_id: actors.unrelated,
          p_kind: scope.p_kind,
          p_item: scope.p_item,
        },
        "42501",
      );
    }
    assert.deepEqual(
      await counts(),
      before,
      "Denial does not allocate new budget/batches/receipts",
    );
    checks++;
    check(
      (
        await rpc(
          users[actor === actors.owner ? "owner" : "cocreator"].client,
          "get_own_account_suspension_status",
          { p_expected_profile_id: actor },
        )
      )[0].is_suspended,
      "Pre-existing valid Auth session reads only own status exception",
    );
    await rpc(users.admin.client, "revoke_account_suspension", {
      p_expected_staff_profile_id: actors.admin,
      p_consequence_id: episode,
      p_user_reason: "Synthetic restored",
      p_internal_note: "Synthetic private note",
    });
  }
  await denied(
    users.owner.client,
    "reserve_location_search_v1",
    scopes[0].scope,
    "42501",
  );
  await denied(
    anonymous,
    "resolve_location_selection_v1",
    {
      ...Object.fromEntries(
        Object.entries(scopes[0].scope).filter(
          ([key]) => key !== "p_query_hash",
        ),
      ),
      p_receipt: scopes[0].receipt,
    },
    "42501",
  );
  check(
    (
      await sql`select count(*)::int n from public.project_delegates where project_id=${fixture.projectId} and revoked_at is null`
    )[0].n === 2,
    "Suspension preserves organizer relationships",
  );

  // Observe exact pg_blocking_pids edges, not merely pending promises. Both
  // winner orders prove the actor -> item composition against canonical apply.
  for (const kind of ["one_time", "recurring", "resource"])
    for (const operation of ["reserve", "issue", "resolve"])
      for (const suspensionFirst of [true, false]) {
        await sql`delete from private.location_search_budgets where scope like ${`%${actors.owner}%`}`;
        const base = scopes.find(
          (x) => x.scope.p_kind === kind && x.scope.p_actor === actors.owner,
        ).scope;
        const scope = {
          ...base,
          p_session: randomUUID(),
          p_query_hash: randomUUID().replaceAll("-", "").repeat(2),
        };
        const reserved =
          operation === "reserve"
            ? null
            : await rpc(service, "reserve_location_search_v1", scope);
        const issued =
          operation === "resolve"
            ? await rpc(service, "issue_location_selections_v1", {
                p_batch: reserved.batch_id,
                p_places: places,
              })
            : null;
        const beforeRace = await counts();
        const execute = async (tx) => {
          await tx`set local role service_role`;
          if (operation === "reserve")
            return (
              await tx`select public.reserve_location_search_v1(${actors.owner}::uuid,${kind},${scope.p_item}::uuid,${scope.p_revision},${scope.p_slot},${scope.p_session}::uuid,${scope.p_query_hash}) result`
            )[0].result;
          if (operation === "issue")
            return (
              await tx`select public.issue_location_selections_v1(${reserved.batch_id}::uuid,${tx.json(places)}::jsonb) result`
            )[0].result;
          return (
            await tx`select public.resolve_location_selection_v1(${actors.owner}::uuid,${kind},${scope.p_item}::uuid,${scope.p_revision},${scope.p_slot},${scope.p_session}::uuid,${issued.suggestions[0].id}::uuid) result`
          )[0].result;
        };
        const suspend = async (tx) => {
          await tx`set local role authenticated`;
          await tx`select set_config('request.jwt.claim.sub',${actors.admin},true)`;
          return (
            await tx`select public.apply_account_suspension(${actors.admin}::uuid,${ownerCase}::uuid,'Synthetic race reason','Synthetic private note') id`
          )[0].id;
        };
        let signal, release, winnerPid, loserPid, episode;
        const acquired = new Promise((resolve) => (signal = resolve)),
          held = new Promise((resolve) => (release = resolve));
        const first = sql.begin(async (tx) => {
          winnerPid = (await tx`select pg_backend_pid() pid`)[0].pid;
          const result = await (suspensionFirst ? suspend(tx) : execute(tx));
          if (suspensionFirst) episode = result;
          else
            check(
              result.status === "ok",
              "Service-first operation legitimately started before suspension",
            );
          signal();
          await held;
        });
        await Promise.race([
          acquired,
          first.then(() => {
            throw new Error("Location race winner never acquired locks");
          }),
        ]);
        const second = sql
          .begin(async (tx) => {
            loserPid = (await tx`select pg_backend_pid() pid`)[0].pid;
            const result = await (suspensionFirst ? execute(tx) : suspend(tx));
            if (!suspensionFirst) episode = result;
          })
          .then(
            () => ({ code: null }),
            (error) => ({ code: error.code }),
          );
        try {
          const deadline = Date.now() + 10000;
          let waiting = false;
          while (Date.now() < deadline) {
            if (loserPid) {
              const [row] =
                await sql`select ${winnerPid}::int=any(pg_blocking_pids(${loserPid}::int)) blocked`;
              if (row.blocked) {
                waiting = true;
                break;
              }
            }
            await new Promise((resolve) => setTimeout(resolve, 20));
          }
          check(waiting, "Exact location/suspension winner lock edge observed");
        } finally {
          release();
        }
        await first;
        assert.equal(
          (await second).code,
          suspensionFirst ? "PT403" : null,
          `${kind}/${operation}: serialized account outcome`,
        );
        checks++;
        races++;
        assert.deepEqual(
          await counts(),
          {
            budgets:
              beforeRace.budgets +
              (!suspensionFirst && operation === "reserve" ? 3 : 0),
            batches:
              beforeRace.batches +
              (!suspensionFirst && operation === "reserve" ? 1 : 0),
            receipts:
              beforeRace.receipts +
              (!suspensionFirst && operation === "issue" ? 1 : 0),
          },
          "Only work serialized before suspension is durably accounted; losing operations publish nothing",
        );
        checks++;
        await denied(service, "reserve_location_search_v1", scope);
        await rpc(users.admin.client, "revoke_account_suspension", {
          p_expected_staff_profile_id: actors.admin,
          p_consequence_id: episode,
          p_user_reason: "Synthetic restored",
          p_internal_note: "Synthetic private note",
        });
      }
  console.log(
    `MODINT location: ${checks} real-auth/service checks and ${races} exact-lock-observed winner races passed; fake normalized provider only.`,
  );
} finally {
  await sql`update private.location_search_config set enabled=${original.enabled},global_daily=${original.global_daily},actor_daily=${original.actor_daily},actor_minute=${original.actor_minute} where singleton`;
  await sql.end({ timeout: 5 });
}
