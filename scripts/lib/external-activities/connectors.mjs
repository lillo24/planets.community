import { ActivityImportError } from "./transport.mjs";
import { radarSources, radarConnector } from "./radar-sources.mjs";
import {
  trentoFacilitiesConnector,
  trentoFacilitiesSource,
} from "./trento-facilities.mjs";

// Source identities/capabilities/transport and public link policies are code
// owned. Nothing here enables hosted publication or grants source configuration.
export const activityConnectorDirectory = Object.freeze([
  ...radarSources.map((source) =>
    Object.freeze({
      sourceId: source.sourceId,
      kinds: Object.freeze(["event"]),
      parserVersion: source.parserVersion,
      status: "collection_available_publication_held",
    }),
  ),
  Object.freeze({
    sourceId: "agenda-trento",
    kinds: Object.freeze(["event"]),
    status: "rights_checkpoint_blocked",
  }),
  Object.freeze({
    sourceId: trentoFacilitiesSource.sourceId,
    kinds: Object.freeze(["place"]),
    parserVersion: trentoFacilitiesSource.parserVersion,
    status: "available_disabled_by_default",
  }),
  // Bounded SPORTAPI02 assessment found no eligible local sports subset.
  // This is an explicit block, never an always-empty successful connector.
  Object.freeze({
    sourceId: "odh-trento-sports",
    kinds: Object.freeze([]),
    status: "coverage_checkpoint_blocked",
  }),
]);

export function resolveActivityConnector(sourceId) {
  if (radarSources.some((source) => source.sourceId === sourceId))
    return radarConnector(sourceId);
  if (sourceId === "odh-trento-sports")
    throw new ActivityImportError("source_coverage_checkpoint_blocked");
  if (sourceId === trentoFacilitiesSource.sourceId)
    return trentoFacilitiesConnector();
  if (sourceId === "agenda-trento") {
    throw new ActivityImportError("source_rights_checkpoint_blocked");
  }
  throw new ActivityImportError("unknown_source");
}
