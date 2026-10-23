import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import {
  activityOperationStore,
  runActivityOperations,
} from "./external-activities/operations.mjs";

// Existing guarded disposable-local runner is the only entry point.
export async function verifyExternalOperations(sql, service, guest) {
  const prefix = `actops01-${randomUUID().slice(0, 8)}`;
  const sources = [`${prefix}-a`, `${prefix}-b`];
  const store = activityOperationStore(service);
  const origin = "https://synthetic.example.org";
  const record = {
    upstream_id: "same",
    title: "Synthetic operations journey",
    description: null,
    kind: "place",
    category: "sports",
    source_categories: [],
    canonical_url: origin + "/place",
    status: "scheduled",
    publishable: true,
    occurrences: [],
  };
  const resolve = (sourceId) => ({
    sourceId,
    origins: [origin],
    officialOrigin: origin,
    apiPathPrefix: "/api/",
    kinds: ["place"],
    collect: async () => ({ complete: true, entries: [{ record }] }),
  });
  try {
    for (const id of sources)
      await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
      values(${id},'Synthetic operations source',${origin},true,true,'Synthetic attribution','https://example.org/license')`;
    for (const name of [
      "inspect_external_activity_sources",
      "maintain_external_activity_imports",
    ]) {
      assert.equal(
        (await guest.rpc(name, { p_source_ids: sources })).error?.code,
        "42501",
      );
    }
    assert.equal(
      (
        await runActivityOperations({
          sources,
          store,
          resolve,
          mode: "dry-run",
        })
      ).status,
      "success",
    );
    assert.equal(
      (
        await sql`select count(*)::int n from private.external_activity_runs where source_id=any(${sources})`
      )[0].n,
      0,
      "Real dry-run zero receipts/writes",
    );
    const applied = await runActivityOperations({
      sources,
      store,
      resolve,
      mode: "apply",
    });
    assert.equal(applied.status, "success");
    const before =
      await sql`select activity_id,content_hash,revision,last_observed_at from private.external_activities where source_id=any(${sources}) order by source_id`;
    assert.equal(before.length, 2);
    const due = await runActivityOperations({
      sources,
      store,
      resolve,
      mode: "apply",
      dueOnly: true,
      policy: Object.fromEntries(sources.map((id) => [id, 24])),
    });
    assert.ok(due.sources.every((x) => x.state === "not_due"));
    const lease = await store.begin(sources[0], AbortSignal.timeout(5000));
    await sql`update private.external_activity_sources set lease_expires_at=clock_timestamp()-interval '1 second' where source_id=${sources[0]}`;
    // A source lock must make maintenance skip it; never steal an active holder.
    await sql.begin(async (tx) => {
      await tx`select source_id from private.external_activity_sources where source_id=${sources[0]} for update`;
      assert.equal(
        (await store.maintain(sources, AbortSignal.timeout(5000)))
          .expired_leases,
        0,
      );
    });
    assert.equal(
      (await store.maintain(sources, AbortSignal.timeout(5000))).expired_leases,
      1,
    );
    const late = await service.rpc("finish_external_activity_import", {
      p_run_id: lease.run_id,
      p_state: "success",
      p_records: [record],
      p_fetched: 1,
    });
    assert.equal(late.error?.code, "40001");
    const inspection = await store.inspect(sources, AbortSignal.timeout(5000));
    assert.equal(inspection.sources[0].last_run.error_code, "lease_expired");
    assert.equal(inspection.sources[0].observations.total, 1);
    assert.ok(!JSON.stringify(inspection).includes(origin));
    assert.deepEqual(
      await sql`select activity_id,content_hash,revision,last_observed_at from private.external_activities where source_id=any(${sources}) order by source_id`,
      before,
    );
    await sql`update private.external_activity_sources set enabled=false where source_id=any(${sources})`;
    const disabled = await runActivityOperations({
      sources,
      store,
      resolve,
      mode: "apply",
    });
    assert.equal(disabled.status, "failure");
    assert.ok(disabled.sources.every((x) => x.state === "disabled"));
    console.log(
      "ACTOPS01: real service/private inspection, anonymous denial, dry-run zero writes, two-source apply/due skip, locked-source skip, expired lease/late finish fencing and canonical preservation PASS.",
    );
  } finally {
    await sql`delete from private.external_activities where source_id=any(${sources})`;
    await sql`delete from private.external_activity_runs where source_id=any(${sources})`;
    await sql`delete from private.external_activity_sources where source_id=any(${sources})`;
  }
}
