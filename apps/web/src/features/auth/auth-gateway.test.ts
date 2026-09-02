import { beforeEach, describe, expect, it, vi } from "vitest";

import { SupabaseWebAuthGateway } from "@/features/auth/auth-gateway";

const signInWithOtp = vi.fn();
const verifyOtp = vi.fn();
const getClaims = vi.fn();
const signOut = vi.fn();
const insert = vi.fn();
const from = vi.fn(() => ({ insert }));

const client = {
  auth: { signInWithOtp, verifyOtp, getClaims, signOut },
  from,
};

describe("SupabaseWebAuthGateway", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    signInWithOtp.mockResolvedValue({ data: {}, error: null });
    verifyOtp.mockResolvedValue({
      data: { user: { id: "user-1" }, session: null },
      error: null,
    });
    getClaims.mockResolvedValue({
      data: { claims: { sub: "user-1" } },
      error: null,
    });
    signOut.mockResolvedValue({ error: null });
    insert.mockResolvedValue({ error: null });
  });

  it("requests a create-if-needed email OTP without a redirect", async () => {
    const gateway = new SupabaseWebAuthGateway(client as never);

    await gateway.requestEmailOtp("Person@Example.COM");

    expect(signInWithOtp).toHaveBeenCalledWith({
      email: "Person@Example.COM",
      options: { shouldCreateUser: true },
    });
  });

  it("verifies the numeric token using the email OTP type", async () => {
    const gateway = new SupabaseWebAuthGateway(client as never);

    await gateway.verifyEmailOtp("Person@Example.COM", "123456");

    expect(verifyOtp).toHaveBeenCalledWith({
      email: "Person@Example.COM",
      token: "123456",
      type: "email",
    });
  });

  it("inserts only the verified current identity profile anchor", async () => {
    const gateway = new SupabaseWebAuthGateway(client as never);

    await gateway.ensureCurrentProfileAnchor();

    expect(getClaims).toHaveBeenCalledOnce();
    expect(from).toHaveBeenCalledWith("profiles");
    expect(insert).toHaveBeenCalledWith({ id: "user-1" });
  });

  it("accepts the profile primary-key duplicate and propagates other failures", async () => {
    const gateway = new SupabaseWebAuthGateway(client as never);
    insert.mockResolvedValueOnce({
      error: {
        code: "23505",
        message: 'duplicate key violates constraint "profiles_pkey"',
      },
    });
    await expect(gateway.ensureCurrentProfileAnchor()).resolves.toBeUndefined();

    const unrelated = { code: "42501", message: "permission denied" };
    insert.mockResolvedValueOnce({ error: unrelated });
    await expect(gateway.ensureCurrentProfileAnchor()).rejects.toBe(unrelated);
  });

  it("signs out through Supabase without deleting application data", async () => {
    const gateway = new SupabaseWebAuthGateway(client as never);

    await gateway.signOut();

    expect(signOut).toHaveBeenCalledOnce();
    expect(from).not.toHaveBeenCalled();
  });
});
