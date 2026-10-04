import "client-only";
import { ParticipantController } from "./participant-controller";
import { createParticipantGateway } from "./participant-gateway";

let controller: ParticipantController | undefined;
// Called only in a Client Component effect, never while rendering on the server.
export function browserParticipantController(): ParticipantController {
  if (typeof window === "undefined")
    throw new Error("Participant controller requires a browser.");
  return (controller ??= new ParticipantController(createParticipantGateway()));
}
