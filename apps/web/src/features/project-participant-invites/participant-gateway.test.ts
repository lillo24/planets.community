import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import type { Database } from "@/types/database.generated";
import { SupabaseParticipantGateway } from "./participant-gateway";
import { account, project, token } from "./participant-test-fixtures";
vi.mock("client-only", () => ({}));
vi.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: vi.fn(),
}));
function setup() {
  const maybeSingle = vi.fn().mockResolvedValue({
    data: { id: account, display_name: "Casey" },
    error: null,
  });
  const rpc = vi.fn().mockResolvedValue({ data: [], error: null });
  const getClaims = vi
    .fn()
    .mockResolvedValue({ data: { claims: { sub: account } }, error: null });
  const unsubscribe = vi.fn();
  const onAuthStateChange = vi
    .fn()
    .mockReturnValue({ data: { subscription: { unsubscribe } } });
  const from = vi.fn().mockReturnValue({
    select: vi
      .fn()
      .mockReturnValue({ eq: vi.fn().mockReturnValue({ maybeSingle }) }),
  });
  const gateway = new SupabaseParticipantGateway({
    rpc,
    from,
    auth: { getClaims, onAuthStateChange },
  } as unknown as SupabaseClient<Database>);
  return {
    gateway,
    rpc,
    from,
    getClaims,
    maybeSingle,
    unsubscribe,
    onAuthStateChange,
  };
}
describe("production participant gateway", () => {
  it("reads verified claims and only non-photo own profile prerequisites", async () => {
    const { gateway, from, maybeSingle, getClaims } = setup();
    expect(await gateway.auth()).toEqual({ account, phase: "ready" });
    expect(getClaims).toHaveBeenCalledOnce();
    expect(from).toHaveBeenCalledWith("profiles");
    maybeSingle.mockResolvedValue({ data: null, error: null });
    expect(await gateway.auth()).toEqual({ account, phase: "missingProfile" });
    maybeSingle.mockResolvedValue({
      data: { id: account, display_name: " " },
      error: null,
    });
    expect(await gateway.auth()).toEqual({
      account,
      phase: "incompleteProfile",
    });
    getClaims.mockResolvedValue({ data: null, error: null });
    expect(await gateway.auth()).toEqual({ account: null, phase: "signedOut" });
  });
  it("does not collapse failed auth/profile reads into a valid signed-out or ready state", async () => {
    const { gateway, maybeSingle, getClaims } = setup();
    maybeSingle.mockResolvedValue({ data: null, error: { code: "42501" } });
    await expect(gateway.auth()).rejects.toMatchObject({ failure: "identity" });
    getClaims.mockResolvedValue({
      data: null,
      error: { name: "AuthSessionMissingError" },
    });
    expect((await gateway.auth()).phase).toBe("signedOut");
    getClaims.mockResolvedValue({
      data: null,
      error: { name: "AuthRetryableFetchError" },
    });
    await expect(gateway.auth()).rejects.toMatchObject({ failure: "network" });
  });
  it("uses only preview RPC for valid tokens and canonical generic unavailable for invalid syntax", async () => {
    const { gateway, rpc } = setup();
    expect(await gateway.preview("bad")).toEqual({ available: false });
    expect(rpc).not.toHaveBeenCalled();
    rpc.mockResolvedValue({
      data: [
        {
          available: false,
          project_id: null,
          project_kind: null,
          project_title: null,
        },
      ],
      error: null,
    });
    await gateway.preview(token);
    expect(rpc).toHaveBeenCalledWith(
      "get_project_participant_invitation_preview",
      { p_token: token },
    );
    rpc.mockResolvedValue({ data: [], error: null });
    await expect(gateway.preview(token)).rejects.toMatchObject({
      failure: "malformed",
    });
    rpc.mockResolvedValue({
      data: null,
      error: { code: "XX000", message: token },
    });
    await expect(gateway.preview(token)).rejects.toMatchObject({
      failure: "network",
    });
  });
  it("binds exact verified account/token/action arguments and never writes requests or contributions", async () => {
    const { gateway, rpc, from } = setup();
    rpc.mockResolvedValue({
      data: [
        {
          project_id: project.id,
          membership_id: null,
          membership_status: null,
          outcome: "creator",
          replayed: false,
        },
      ],
      error: null,
    });
    await gateway.accept(account, token, account);
    expect(rpc).toHaveBeenCalledExactlyOnceWith(
      "accept_project_participant_invitation",
      {
        p_expected_profile_id: account,
        p_token: token,
        p_client_action_id: account,
      },
    );
    expect(from).not.toHaveBeenCalled();
    rpc.mockResolvedValue({
      data: null,
      error: { code: "PT409", message: "This Project is full." },
    });
    await expect(gateway.accept(account, token, account)).rejects.toMatchObject(
      { failure: "full" },
    );
  });
  it("reads exact-account memberships and exact-project Creator context", async () => {
    const { gateway, rpc } = setup();
    rpc
      .mockResolvedValueOnce({ data: [], error: null })
      .mockResolvedValueOnce({ data: "creator", error: null });
    expect(await gateway.participation(account, project)).toEqual({
      current: false,
      creator: true,
    });
    expect(rpc.mock.calls).toEqual([
      [
        "list_own_project_memberships",
        { p_expected_participant_profile_id: account },
      ],
      [
        "get_own_project_management_role",
        { p_expected_profile_id: account, p_project_id: project.id },
      ],
    ]);
  });
  it("observes signout/cross-tab changes and unsubscribes without trusting session hints for mutation", () => {
    const { gateway, onAuthStateChange, unsubscribe, rpc } = setup();
    const callback = vi.fn();
    const stop = gateway.observeIdentity(callback);
    onAuthStateChange.mock.calls[0][0]("SIGNED_OUT", null);
    onAuthStateChange.mock.calls[0][0]("SIGNED_IN", { user: { id: account } });
    expect(callback.mock.calls).toEqual([[null], [account]]);
    expect(rpc).not.toHaveBeenCalled();
    stop();
    expect(unsubscribe).toHaveBeenCalledOnce();
  });
});
