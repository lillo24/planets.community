import "client-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";
import type {
  AdmissionReceipt,
  CurrentParticipation,
  ParticipantAuth,
  ParticipantPreview,
  ProjectContext,
} from "./participant-models";
import {
  acceptParticipant,
  previewParticipant,
  readCurrentParticipation,
  readParticipantAuth,
} from "./participant-rpc";

export interface ParticipantGateway {
  auth(): Promise<ParticipantAuth>;
  preview(token: string): Promise<ParticipantPreview>;
  accept(
    account: string,
    token: string,
    action: string,
  ): Promise<AdmissionReceipt>;
  participation(
    account: string,
    project: ProjectContext,
  ): Promise<CurrentParticipation>;
  observeIdentity(callback: (account: string | null) => void): () => void;
}
export class SupabaseParticipantGateway implements ParticipantGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}
  auth() {
    return readParticipantAuth(this.client);
  }
  preview(token: string) {
    return previewParticipant(this.client, token);
  }
  accept(account: string, token: string, action: string) {
    return acceptParticipant(this.client, account, token, action);
  }
  participation(account: string, project: ProjectContext) {
    return readCurrentParticipation(this.client, account, project);
  }
  observeIdentity(callback: (account: string | null) => void) {
    const { data } = this.client.auth.onAuthStateChange((_event, session) =>
      callback(session?.user.id ?? null),
    );
    return () => data.subscription.unsubscribe();
  }
}
export function createParticipantGateway(): ParticipantGateway {
  return new SupabaseParticipantGateway(createSupabaseBrowserClient());
}
