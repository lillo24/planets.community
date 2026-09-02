import { describe, expect, it } from "vitest";

import {
  authFailureMessage,
  handleProfileAnchorInsertFailure,
  isExpectedProfileAnchorDuplicate,
  isValidEmail,
  isValidOtp,
  mapAuthFailure,
  maskEmail,
  normalizeEmailInput,
} from "@/features/auth/auth-models";

describe("web auth models", () => {
  it("trims surrounding email whitespace without changing casing", () => {
    expect(normalizeEmailInput("  Person@Example.COM \n")).toBe(
      "Person@Example.COM",
    );
    expect(isValidEmail("Person@Example.COM")).toBe(true);
    expect(isValidEmail("not-an-email")).toBe(false);
  });

  it("accepts only exactly six ASCII digits", () => {
    expect(isValidOtp("123456")).toBe(true);
    expect(isValidOtp("12345")).toBe(false);
    expect(isValidOtp("12345a")).toBe(false);
    expect(isValidOtp("１２３４５６")).toBe(false);
  });

  it("masks the local part while preserving casing", () => {
    expect(maskEmail("Person@Example.COM")).toBe("P•••@Example.COM");
    expect(maskEmail("invalid")).toBe("•••");
  });

  it("maps provider metadata to safe application failures", () => {
    expect(mapAuthFailure({ code: "email_address_invalid", status: 400 })).toBe(
      "invalidEmail",
    );
    expect(mapAuthFailure({ code: "invalid_otp", status: 403 })).toBe(
      "invalidCode",
    );
    expect(mapAuthFailure({ code: "otp_expired", status: 403 })).toBe(
      "expiredCode",
    );
    expect(
      mapAuthFailure({ code: "over_email_send_rate_limit", status: 429 }),
    ).toBe("rateLimited");
    expect(
      mapAuthFailure({ name: "AuthRetryableFetchError", status: 503 }),
    ).toBe("networkUnavailable");
    expect(mapAuthFailure({ status: 503 })).toBe("serviceUnavailable");
    expect(mapAuthFailure(new Error("private provider detail"))).toBe(
      "unexpected",
    );
    expect(authFailureMessage("unexpected")).not.toContain("private");
  });

  it("accepts only the expected profile primary-key duplicate", () => {
    const expected = {
      code: "23505",
      message: 'duplicate key violates constraint "profiles_pkey"',
    };
    const unrelated = {
      code: "23505",
      message: 'duplicate key violates constraint "other_key"',
    };

    expect(isExpectedProfileAnchorDuplicate(expected)).toBe(true);
    expect(() => handleProfileAnchorInsertFailure(expected)).not.toThrow();
    expect(isExpectedProfileAnchorDuplicate(unrelated)).toBe(false);
    expect(() => handleProfileAnchorInsertFailure(unrelated)).toThrow(
      unrelated,
    );
  });
});
