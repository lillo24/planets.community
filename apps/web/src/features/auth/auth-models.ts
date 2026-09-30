export const resendCooldownMilliseconds = 30_000;

export type AuthFailureKind =
  | "invalidEmail"
  | "invalidCode"
  | "expiredCode"
  | "rateLimited"
  | "networkUnavailable"
  | "serviceUnavailable"
  | "profileSetup"
  | "unexpected";

export type CurrentAuthState =
  | Readonly<{ status: "signedOut" }>
  | Readonly<{ status: "ready"; profileId: string }>
  | Readonly<{
      status: "profileSetupRequired";
      reason: "missing" | "incomplete";
    }>;

type AuthFailureLike = Readonly<{
  code?: unknown;
  name?: unknown;
  status?: unknown;
}>;

type DatabaseFailureLike = Readonly<{
  code?: unknown;
  details?: unknown;
  message?: unknown;
}>;

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/u;
const tokenPattern = /^\d{6}$/u;

export function normalizeEmailInput(value: string): string {
  return value.trim();
}

export function isValidEmail(value: string): boolean {
  return value.length <= 254 && emailPattern.test(value);
}

export function normalizeOtpInput(value: string): string {
  return value.trim();
}

export function isValidOtp(value: string): boolean {
  return tokenPattern.test(value);
}

export function maskEmail(email: string): string {
  const separator = email.indexOf("@");
  if (separator <= 0 || separator === email.length - 1) {
    return "•••";
  }

  return `${email.slice(0, 1)}•••${email.slice(separator)}`;
}

export function mapAuthFailure(error: unknown): AuthFailureKind {
  const failure = asFailure(error);
  const code =
    typeof failure.code === "string" ? failure.code.toLowerCase() : "";
  const status =
    typeof failure.status === "number" ? failure.status : undefined;

  if (failure.name === "AuthRetryableFetchError") {
    return "networkUnavailable";
  }
  if (code === "email_address_invalid") {
    return "invalidEmail";
  }
  if (code === "otp_expired") {
    return "expiredCode";
  }
  if (code === "invalid_otp" || code === "otp_disabled") {
    return "invalidCode";
  }
  if (status === 429 || code.includes("rate_limit")) {
    return "rateLimited";
  }
  if (status !== undefined && status >= 500) {
    return "serviceUnavailable";
  }

  return "unexpected";
}

export function authFailureMessage(failure: AuthFailureKind): string {
  switch (failure) {
    case "invalidEmail":
      return "Enter a valid email address.";
    case "invalidCode":
      return "Enter the six-digit code from the email.";
    case "expiredCode":
      return "That code has expired. Request a new one.";
    case "rateLimited":
      return "Please wait before requesting another code.";
    case "networkUnavailable":
      return "Check your connection and try again.";
    case "serviceUnavailable":
      return "Sign-in is temporarily unavailable. Please try again.";
    case "profileSetup":
      return "Your session is active, but setup could not finish. Try again.";
    case "unexpected":
      return "We couldn't complete sign-in. Please try again.";
  }
}

export function isExpectedProfileAnchorDuplicate(error: unknown): boolean {
  const failure = asDatabaseFailure(error);
  const diagnostic = `${stringValue(failure.message)} ${stringValue(
    failure.details,
  )}`.toLowerCase();

  return failure.code === "23505" && diagnostic.includes("profiles_pkey");
}

export function handleProfileAnchorInsertFailure(error: unknown): void {
  if (!isExpectedProfileAnchorDuplicate(error)) {
    throw error;
  }
}

function asFailure(error: unknown): AuthFailureLike {
  return typeof error === "object" && error !== null
    ? (error as AuthFailureLike)
    : {};
}

function asDatabaseFailure(error: unknown): DatabaseFailureLike {
  return typeof error === "object" && error !== null
    ? (error as DatabaseFailureLike)
    : {};
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}
