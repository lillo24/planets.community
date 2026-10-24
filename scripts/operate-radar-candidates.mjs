import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { radarSources } from "./lib/external-activities/radar-sources.mjs";
import { ActivityImportError } from "./lib/external-activities/transport.mjs";
import { activityOperationTarget } from "./lib/external-activities/operations.mjs";

// Explicit operator commands, never a client feature or a source-controlled
// approval. Owner qualification still leaves rights and public enablement OFF.
try {
  const args = process.argv.slice(2),
    options = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (
      ["--inspect", "--reject", "--maintain", "--qualify", "--alias"].includes(
        arg,
      )
    ) {
      if (options.mode) throw new ActivityImportError("invalid_arguments");
      options.mode = arg.slice(2);
    } else if (
      [
        "--source",
        "--target",
        "--upstream",
        "--revision",
        "--parser-version",
        "--policy-url",
        "--policy-sha256",
        "--canonical-upstream",
      ].includes(arg)
    ) {
      if (options[arg] || !args[i + 1] || args[i + 1].startsWith("--"))
        throw new ActivityImportError("invalid_arguments");
      options[arg] = args[++i];
    } else throw new ActivityImportError("invalid_arguments");
  }
  const source = radarSources.find((s) => s.sourceId === options["--source"]);
  if (
    !source ||
    !options.mode ||
    !/^[a-z][a-z0-9-]{0,63}$/.test(options["--target"] ?? "") ||
    options["--target"] !== process.env.ACTIVITIES_TARGET
  )
    throw new ActivityImportError("missing_explicit_target");
  let result;
  if (options.mode === "alias") {
    if (
      !process.env.ACTIVITIES_OWNER_DATABASE_URL ||
      !options["--upstream"] ||
      !options["--canonical-upstream"] ||
      options["--upstream"] === options["--canonical-upstream"]
    )
      throw new ActivityImportError("owner_correction_inputs_required");
    const sql = postgres(process.env.ACTIVITIES_OWNER_DATABASE_URL, {
      max: 1,
      onnotice: () => {},
    });
    try {
      await sql.begin(async (transaction) => {
        await transaction`select source_id from private.external_activity_sources where source_id=${source.sourceId} for update`;
        const rows =
          await transaction`insert into private.external_activity_aliases(alias_id,canonical_id,evidence_url,source_correction)
          select old.activity_id,current.activity_id,current.content->>'canonical_url',true
          from private.external_activities old join private.external_activities current on current.source_id=old.source_id
          where old.source_id=${source.sourceId} and old.upstream_id=${options["--upstream"]} and current.upstream_id=${options["--canonical-upstream"]}
           and not exists(select 1 from private.external_activity_aliases x where x.alias_id=current.activity_id or x.canonical_id=old.activity_id)
          on conflict(alias_id) do update set canonical_id=excluded.canonical_id,evidence_url=excluded.evidence_url,source_correction=true returning alias_id,canonical_id`;
        if (rows.length !== 1)
          throw new ActivityImportError(
            "correction_requires_existing_primary_records_without_alias_chains",
          );
        await transaction`update private.external_activity_sources set catalogue_version=catalogue_version+1 where source_id=${source.sourceId}`;
        result = {
          scope: "external_radar_owner_correction",
          source_id: source.sourceId,
          ...rows[0],
        };
      });
    } finally {
      await sql.end();
    }
  } else if (options.mode === "qualify") {
    if (
      options["--parser-version"] !== source.parserVersion ||
      !options["--policy-url"] ||
      !/^[a-f0-9]{64}$/.test(options["--policy-sha256"] ?? "") ||
      !process.env.ACTIVITIES_OWNER_DATABASE_URL
    )
      throw new ActivityImportError("owner_qualification_inputs_required");
    const policy = new URL(options["--policy-url"]),
      database = new URL(process.env.ACTIVITIES_OWNER_DATABASE_URL);
    if (
      policy.protocol !== "https:" ||
      policy.username ||
      policy.password ||
      !["postgres:", "postgresql:"].includes(database.protocol)
    )
      throw new ActivityImportError("invalid_arguments");
    const sql = postgres(process.env.ACTIVITIES_OWNER_DATABASE_URL, {
      max: 1,
      onnotice: () => {},
    });
    try {
      const rows =
        await sql`update private.external_activity_sources set radar_parser_version=${source.parserVersion},radar_qualified_parser_version=${source.parserVersion},radar_parser_qualified=true,radar_facts_reuse=true,radar_policy_url=${policy.href},radar_policy_revision=${options["--policy-sha256"]},radar_qualified_policy_revision=${options["--policy-sha256"]}
        where source_id=${source.sourceId} and radar_collection_enabled returning source_id,enabled,rights_confirmed,radar_parser_version`;
      if (rows.length !== 1)
        throw new ActivityImportError("source_collection_not_configured");
      result = { scope: "external_radar_owner_qualification", source: rows[0] };
    } finally {
      await sql.end();
    }
  } else {
    const { apiUrl, key } = activityOperationTarget(
      { target: options["--target"] },
      process.env,
    );
    const client = createClient(apiUrl, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let name,
      params = { p_source_id: source.sourceId };
    if (options.mode === "inspect") name = "inspect_external_radar_candidates";
    else if (options.mode === "maintain")
      name = "maintain_external_radar_evidence";
    else {
      if (
        !options["--upstream"] ||
        !/^[a-f0-9]{64}$/.test(options["--revision"] ?? "")
      )
        throw new ActivityImportError("exact_revision_required");
      name = "reject_external_radar_candidate";
      params = {
        ...params,
        p_upstream_id: options["--upstream"],
        p_revision_digest: options["--revision"],
      };
    }
    const { data, error } = await client
      .rpc(name, params)
      .abortSignal(AbortSignal.timeout(15000));
    if (error) throw new ActivityImportError("persistence_error");
    result = data;
  }
  process.stdout.write(JSON.stringify(result) + "\n");
} catch (error) {
  process.stderr.write(
    `Radar operator: ${error instanceof ActivityImportError ? error.code : "operation_failed"}.\n`,
  );
  process.exitCode = 1;
}
