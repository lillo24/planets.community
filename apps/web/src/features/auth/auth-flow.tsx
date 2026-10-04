"use client";

import { REGEXP_ONLY_DIGITS } from "input-otp";
import { CircleAlertIcon } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";

import {
  authFailureMessage,
  isValidEmail,
  isValidOtp,
  mapAuthFailure,
  maskEmail,
  normalizeEmailInput,
  normalizeOtpInput,
  resendCooldownMilliseconds,
  type AuthFailureKind,
} from "@/features/auth/auth-models";
import {
  createWebAuthGateway,
  type WebAuthGateway,
} from "@/features/auth/auth-gateway";
import { participantCancelDestination } from "./return-destination";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "@/components/ui/input-otp";
import { Spinner } from "@/components/ui/spinner";

export type AuthNavigation = Readonly<{
  refresh(): void;
  replace(destination: string): void;
}>;

type AuthFlowProps = Readonly<{
  returnTo: string;
  gateway?: WebAuthGateway;
  navigation?: AuthNavigation;
  now?: () => number;
}>;

type FlowPhase = "request" | "verify" | "profileSetup";
type BusyAction = "request" | "verify" | "resend" | "profile" | "signOut";

const systemNow = () => Date.now();

export function AuthFlow({
  returnTo,
  gateway,
  navigation,
  now = systemNow,
}: AuthFlowProps) {
  const router = useRouter();
  const [authGateway] = useState(() => gateway ?? createWebAuthGateway());
  const authNavigation = navigation ?? router;
  const cancelTo = participantCancelDestination(returnTo);
  const lock = useRef(false);
  const [phase, setPhase] = useState<FlowPhase>("request");
  const [email, setEmail] = useState("");
  const [pendingEmail, setPendingEmail] = useState<string | null>(null);
  const [token, setToken] = useState("");
  const [failure, setFailure] = useState<AuthFailureKind | null>(null);
  const [busy, setBusy] = useState<BusyAction | null>(null);
  const [resendAvailableAt, setResendAvailableAt] = useState<number | null>(
    null,
  );
  const [currentTime, setCurrentTime] = useState(() => now());

  useEffect(() => {
    if (phase !== "verify" || resendAvailableAt === null) {
      return;
    }

    const timer = window.setInterval(() => {
      const tick = now();
      setCurrentTime(tick);
      if (tick >= resendAvailableAt) {
        window.clearInterval(timer);
      }
    }, 1_000);

    return () => window.clearInterval(timer);
  }, [now, phase, resendAvailableAt]);

  const secondsUntilResend =
    resendAvailableAt === null
      ? 0
      : Math.max(0, Math.ceil((resendAvailableAt - currentTime) / 1_000));

  async function requestCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (lock.current) {
      return;
    }

    const trimmedEmail = normalizeEmailInput(email);
    if (!isValidEmail(trimmedEmail)) {
      setFailure("invalidEmail");
      return;
    }

    lock.current = true;
    setBusy("request");
    setFailure(null);
    try {
      await authGateway.requestEmailOtp(trimmedEmail);
      const requestedAt = now();
      setCurrentTime(requestedAt);
      setResendAvailableAt(requestedAt + resendCooldownMilliseconds);
      setPendingEmail(trimmedEmail);
      setEmail("");
      setPhase("verify");
    } catch (error) {
      setFailure(mapAuthFailure(error));
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  async function resendCode() {
    if (lock.current || pendingEmail === null) {
      return;
    }

    const requestedAt = now();
    if (resendAvailableAt !== null && requestedAt < resendAvailableAt) {
      setCurrentTime(requestedAt);
      setFailure("rateLimited");
      return;
    }

    lock.current = true;
    setBusy("resend");
    setFailure(null);
    try {
      await authGateway.requestEmailOtp(pendingEmail);
      setCurrentTime(requestedAt);
      setResendAvailableAt(requestedAt + resendCooldownMilliseconds);
    } catch (error) {
      setFailure(mapAuthFailure(error));
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (lock.current || pendingEmail === null) {
      return;
    }

    const normalizedToken = normalizeOtpInput(token);
    if (!isValidOtp(normalizedToken)) {
      setFailure("invalidCode");
      return;
    }

    lock.current = true;
    setBusy("verify");
    setFailure(null);
    try {
      await authGateway.verifyEmailOtp(pendingEmail, normalizedToken);
      setPendingEmail(null);
      setToken("");
      setResendAvailableAt(null);
      setPhase("profileSetup");
      setBusy("profile");

      try {
        await authGateway.ensureCurrentProfileAnchor();
      } catch {
        setFailure("profileSetup");
        return;
      }

      authNavigation.replace(returnTo);
      authNavigation.refresh();
    } catch (error) {
      setFailure(mapAuthFailure(error));
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  async function retryProfileSetup() {
    if (lock.current) {
      return;
    }

    lock.current = true;
    setBusy("profile");
    setFailure(null);
    try {
      await authGateway.ensureCurrentProfileAnchor();
      authNavigation.replace(returnTo);
      authNavigation.refresh();
    } catch {
      setFailure("profileSetup");
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  async function signOut() {
    if (lock.current) {
      return;
    }

    lock.current = true;
    setBusy("signOut");
    setFailure(null);
    try {
      await authGateway.signOut();
      setPendingEmail(null);
      setToken("");
      authNavigation.replace(cancelTo);
      authNavigation.refresh();
    } catch (error) {
      setFailure(mapAuthFailure(error));
    } finally {
      lock.current = false;
      setBusy(null);
    }
  }

  function useDifferentEmail() {
    if (lock.current) {
      return;
    }
    setPendingEmail(null);
    setToken("");
    setFailure(null);
    setResendAvailableAt(null);
    setPhase("request");
  }

  if (phase === "profileSetup") {
    return (
      <Card className="w-full max-w-md" aria-labelledby="profile-setup-title">
        <CardHeader>
          <CardTitle id="profile-setup-title">Finish session setup</CardTitle>
          <CardDescription>
            Your sign-in is valid. Finish the application setup before
            continuing.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {failure ? <AuthFailureAlert failure={failure} /> : null}
        </CardContent>
        <CardFooter className="flex flex-wrap gap-2">
          <Button
            type="button"
            onClick={retryProfileSetup}
            disabled={busy !== null}
          >
            {busy === "profile" ? <Spinner data-icon="inline-start" /> : null}
            Try setup again
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={signOut}
            disabled={busy !== null}
          >
            {busy === "signOut" ? <Spinner data-icon="inline-start" /> : null}
            Sign out
          </Button>
          {cancelTo !== "/" ? (
            <Link href={cancelTo} prefetch={false}>
              Cancel sign-in
            </Link>
          ) : null}
        </CardFooter>
      </Card>
    );
  }

  if (phase === "verify" && pendingEmail !== null) {
    const codeInvalid = failure === "invalidCode" || failure === "expiredCode";

    return (
      <Card className="w-full max-w-md" aria-labelledby="verify-code-title">
        <CardHeader>
          <CardTitle id="verify-code-title">Enter your sign-in code</CardTitle>
          <CardDescription>
            We sent a six-digit code to {maskEmail(pendingEmail)}.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form id="verify-code-form" onSubmit={verifyCode}>
            <FieldGroup>
              <Field data-invalid={codeInvalid || undefined}>
                <FieldLabel htmlFor="auth-code">Six-digit code</FieldLabel>
                <InputOTP
                  id="auth-code"
                  value={token}
                  onChange={setToken}
                  maxLength={6}
                  pattern={REGEXP_ONLY_DIGITS}
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  aria-invalid={codeInvalid || undefined}
                  disabled={busy !== null}
                  containerClassName="justify-center"
                >
                  <InputOTPGroup>
                    {Array.from({ length: 6 }, (_, index) => (
                      <InputOTPSlot key={index} index={index} />
                    ))}
                  </InputOTPGroup>
                </InputOTP>
                {codeInvalid ? (
                  <FieldError>{authFailureMessage(failure)}</FieldError>
                ) : null}
              </Field>
              {failure && !codeInvalid ? (
                <AuthFailureAlert failure={failure} />
              ) : null}
            </FieldGroup>
          </form>
        </CardContent>
        <CardFooter className="flex flex-wrap gap-2">
          <Button
            type="submit"
            form="verify-code-form"
            disabled={busy !== null}
          >
            {busy === "verify" || busy === "profile" ? (
              <Spinner data-icon="inline-start" />
            ) : null}
            Verify code
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={resendCode}
            disabled={busy !== null || secondsUntilResend > 0}
          >
            {busy === "resend" ? <Spinner data-icon="inline-start" /> : null}
            {secondsUntilResend > 0
              ? `Resend in ${secondsUntilResend}s`
              : "Resend code"}
          </Button>
          <Button
            type="button"
            variant="ghost"
            onClick={useDifferentEmail}
            disabled={busy !== null}
          >
            Use another email
          </Button>
          {cancelTo !== "/" ? (
            <Link href={cancelTo} prefetch={false}>
              Cancel sign-in
            </Link>
          ) : null}
        </CardFooter>
      </Card>
    );
  }

  const emailInvalid = failure === "invalidEmail";

  return (
    <Card className="w-full max-w-md" aria-labelledby="request-code-title">
      <CardHeader>
        <CardTitle id="request-code-title">Sign in to PLANETS</CardTitle>
        <CardDescription>
          Enter your email and we will send a six-digit sign-in code.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form id="request-code-form" onSubmit={requestCode} noValidate>
          <FieldGroup>
            <Field data-invalid={emailInvalid || undefined}>
              <FieldLabel htmlFor="auth-email">Email</FieldLabel>
              <Input
                id="auth-email"
                name="email"
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                autoComplete="email"
                required
                aria-invalid={emailInvalid || undefined}
                disabled={busy !== null}
              />
              {emailInvalid ? (
                <FieldError>{authFailureMessage(failure)}</FieldError>
              ) : null}
            </Field>
            {failure && !emailInvalid ? (
              <AuthFailureAlert failure={failure} />
            ) : null}
          </FieldGroup>
        </form>
      </CardContent>
      <CardFooter className="flex justify-between gap-2">
        <Button
          variant="ghost"
          render={<Link href={cancelTo} prefetch={false} />}
          nativeButton={false}
        >
          {cancelTo === "/" ? "Back to home" : "Back to invitation"}
        </Button>
        <Button type="submit" form="request-code-form" disabled={busy !== null}>
          {busy === "request" ? <Spinner data-icon="inline-start" /> : null}
          Send code
        </Button>
      </CardFooter>
    </Card>
  );
}

function AuthFailureAlert({ failure }: Readonly<{ failure: AuthFailureKind }>) {
  return (
    <Alert variant="destructive" aria-live="polite">
      <CircleAlertIcon />
      <AlertTitle>Sign-in needs attention</AlertTitle>
      <AlertDescription>{authFailureMessage(failure)}</AlertDescription>
    </Alert>
  );
}
