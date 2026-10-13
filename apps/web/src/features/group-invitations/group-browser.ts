import "client-only";
import { GroupInvitationController } from "./group-controller";
import { createGroupInvitationGateway } from "./group-gateway";
let controller: GroupInvitationController | undefined;
export function browserGroupController() {
  if (typeof window === "undefined")
    throw new Error("Group controller requires a browser.");
  return (controller ??= new GroupInvitationController(
    createGroupInvitationGateway(),
    undefined,
    () => window.location.hash === "",
  ));
}
