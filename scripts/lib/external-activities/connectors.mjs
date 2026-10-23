import { ActivityImportError } from "./transport.mjs";
import {
  trentoFacilitiesConnector,
  trentoFacilitiesSource,
} from "./trento-facilities.mjs";

// Source identities/capabilities/transport and public link policies are code
// owned. Nothing here enables hosted publication or grants source configuration.
export const activityConnectorDirectory = Object.freeze([
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
]);

export function resolveActivityConnector(sourceId) {
  if (sourceId === trentoFacilitiesSource.sourceId)
    return trentoFacilitiesConnector();
  if (sourceId === "agenda-trento") {
    throw new ActivityImportError("source_rights_checkpoint_blocked");
  }
  throw new ActivityImportError("unknown_source");
}
