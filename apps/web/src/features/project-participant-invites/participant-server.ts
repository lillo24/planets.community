import "server-only";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  mapParticipantFailure,
  type CurrentParticipation,
  type ParticipantAuth,
  type ParticipantFailure,
  type ParticipantPreview,
  type ProjectContext,
} from "./participant-models";
import {
  previewParticipant,
  readCurrentParticipation,
  readParticipantAuth,
} from "./participant-rpc";

export type PreviewRead =
  | { preview: ParticipantPreview; failure?: never }
  | { failure: ParticipantFailure; preview?: never };
export async function readParticipantPreview(
  token: string,
): Promise<PreviewRead> {
  try {
    return {
      preview: await previewParticipant(
        await createSupabaseServerClient(),
        token,
      ),
    };
  } catch (error) {
    return { failure: mapParticipantFailure(error) };
  }
}
export type ConfirmationRead =
  | {
      auth: ParticipantAuth;
      participation?: CurrentParticipation;
      failure?: never;
    }
  | { failure: ParticipantFailure; auth?: never; participation?: never };
export async function readParticipantConfirmation(
  project: ProjectContext,
): Promise<ConfirmationRead> {
  try {
    const client = await createSupabaseServerClient();
    const auth = await readParticipantAuth(client);
    return {
      auth,
      ...(auth.account
        ? {
            participation: await readCurrentParticipation(
              client,
              auth.account,
              project,
            ),
          }
        : {}),
    };
  } catch (error) {
    return { failure: mapParticipantFailure(error) };
  }
}
