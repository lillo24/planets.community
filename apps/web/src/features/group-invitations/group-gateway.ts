import "client-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";
import {
  groupId,
  GroupError,
  groupFailure,
  oneGroupRow,
  parseGroupCurrent,
  parseGroupPreview,
  parseGroupReceipt,
  parsePublicGroup,
  type GroupAuth,
  type GroupCurrent,
  type GroupPreview,
  type GroupReceipt,
  type PublicGroupContent,
} from "./group-models";

// Keep aligned with mobile policy_documents.dart and site policies/metadata.ts.
export const groupPolicyVersion = "POLICY01-2026-10-08-v1";
export interface GroupInvitationGateway {
  auth(): Promise<GroupAuth>;
  preview(token: string, authority: boolean): Promise<GroupPreview>;
  recover(actor: string, key: string): Promise<GroupReceipt | null>;
  accept(
    actor: string,
    key: string,
    token: string,
    authority: boolean,
  ): Promise<GroupReceipt>;
  current(actor: string, group: string): Promise<GroupCurrent>;
  publicGroup(group: string): Promise<PublicGroupContent | null>;
  policy(actor: string, accept?: boolean): Promise<boolean>;
  observeIdentity(callback: (actor: string | null) => void): () => void;
}
export class SupabaseGroupInvitationGateway implements GroupInvitationGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}
  async auth(): Promise<GroupAuth> {
    const { data, error } = await this.client.auth.getClaims();
    if (error) {
      if (error.name === "AuthSessionMissingError")
        return { account: null, phase: "signedOut" };
      throw new GroupError("network");
    }
    if (!data) return { account: null, phase: "signedOut" };
    const account = groupId(data.claims.sub);
    const profile = await this.client
      .from("profiles")
      .select("id, display_name")
      .eq("id", account)
      .maybeSingle();
    if (profile.error) throw new GroupError(groupFailure(profile.error));
    if (!profile.data) return { account, phase: "missingProfile" };
    if (
      profile.data.id !== account ||
      (profile.data.display_name !== null &&
        typeof profile.data.display_name !== "string")
    )
      throw new GroupError("malformed");
    return {
      account,
      phase: profile.data.display_name?.trim() ? "ready" : "incompleteProfile",
    };
  }
  async preview(token: string, authority: boolean) {
    const result = await this.client.rpc(
      authority
        ? "get_group_authority_invitation_preview"
        : "get_group_participant_invitation_preview",
      { p_token: token },
    );
    if (result.error) throw new GroupError(groupFailure(result.error));
    return parseGroupPreview(result.data, authority);
  }
  async recover(actor: string, key: string) {
    const result = await this.client.rpc("recover_group_relationship_command", {
      p_expected_profile_id: groupId(actor),
      p_client_request_id: groupId(key),
    });
    if (result.error) throw new GroupError(groupFailure(result.error));
    return oneGroupRow(result.data, true)
      ? parseGroupReceipt(result.data)
      : null;
  }
  async accept(actor: string, key: string, token: string, authority: boolean) {
    const result = await this.client.rpc(
      authority
        ? "accept_group_authority_invitation"
        : "accept_group_participant_invitation",
      {
        p_expected_profile_id: groupId(actor),
        p_client_request_id: groupId(key),
        p_token: token,
      },
    );
    if (result.error) throw new GroupError(groupFailure(result.error));
    return parseGroupReceipt(result.data);
  }
  async current(actor: string, group: string) {
    const result = await this.client.rpc("get_own_group_role", {
      p_expected_profile_id: groupId(actor),
      p_group_id: groupId(group),
    });
    if (result.error) throw new GroupError(groupFailure(result.error));
    return parseGroupCurrent(result.data);
  }
  async publicGroup(group: string) {
    const result = await this.client.rpc("get_public_group", {
      p_group_id: groupId(group),
    });
    if (result.error) throw new GroupError(groupFailure(result.error));
    return parsePublicGroup(result.data);
  }
  async policy(actor: string, accept = false) {
    const result = await this.client.rpc(
      accept ? "accept_policy_bundle" : "get_policy_acceptance",
      {
        p_expected_account_id: groupId(actor),
        p_bundle_version: groupPolicyVersion,
      },
    );
    if (result.error) throw new GroupError(groupFailure(result.error));
    const row = oneGroupRow(result.data, !accept);
    if (!row) return false;
    if (
      row.account_id !== actor ||
      row.bundle_version !== groupPolicyVersion ||
      typeof row.accepted_at !== "string" ||
      !Number.isFinite(Date.parse(row.accepted_at))
    )
      throw new GroupError("malformed");
    return true;
  }
  observeIdentity(callback: (actor: string | null) => void) {
    const { data } = this.client.auth.onAuthStateChange((_event, session) =>
      callback(session?.user.id ?? null),
    );
    return () => data.subscription.unsubscribe();
  }
}
export function createGroupInvitationGateway(): GroupInvitationGateway {
  return new SupabaseGroupInvitationGateway(createSupabaseBrowserClient());
}
