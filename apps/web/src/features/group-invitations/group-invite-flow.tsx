"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { UsersRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { browserGroupController } from "./group-browser";
import type { GroupInvitationController } from "./group-controller";
import { consentVersion, groupFailureMessage } from "./group-models";
const publicPolicies =
  "https://planets-public-site.developer-planets-community.workers.dev";
export const coCreatorExplanation =
  "Co-creators can edit published pages, archive and restore groups, manage requests, participants and links, and invite, change or revoke organizers. This grants no Creator identity, private draft access, legal verification or authority in Projects.";
export function GroupInviteFlow({
  token,
  authority = false,
  controller,
}: Readonly<{
  token: string;
  authority?: boolean;
  controller?: GroupInvitationController;
}>) {
  const [active, setActive] = useState<GroupInvitationController | null>(null);
  useEffect(() => {
    const c = controller ?? browserGroupController();
    let live = true;
    void c.open(token, authority).then(() => {
      if (live) setActive(c);
    });
    return () => {
      live = false;
      c.deactivate(token);
    };
  }, [token, authority, controller]);
  return active ? (
    <GroupInviteControls
      token={token}
      authority={authority}
      controller={active}
    />
  ) : (
    <p role="status">Checking invitation…</p>
  );
}
function GroupInviteControls({
  token,
  authority,
  controller,
}: Readonly<{
  token: string;
  authority: boolean;
  controller: GroupInvitationController;
}>) {
  const state = useSyncExternalStore(
      controller.subscribe,
      controller.snapshot,
      controller.snapshot,
    ),
    router = useRouter();
  const [policyAccount, setPolicyAccount] = useState<string | null>(null),
    [consent, setConsent] = useState<string | null>(null);
  const version = state.preview ? consentVersion(state.preview) : null,
    blocked = state.loading || state.busy;
  const policy =
    !!state.auth?.account &&
    policyAccount === `${state.auth.account}/${controller.consentEpoch}`;
  const consentKey =
    state.auth?.account && version
      ? `${state.auth.account}/${controller.consentEpoch}/${version}`
      : null;
  const current = controller.confirmed();
  useEffect(() => {
    if (current && state.receipt)
      router.replace(`/joined/groups/${state.receipt.group}`);
  }, [current, state.receipt, router]);
  const returnTo = `/${authority ? "invite" : "join"}/group/${token}`;
  const ready = state.auth?.phase === "ready";
  return (
    <div className="grid gap-5">
      <div
        className="mx-auto flex size-16 items-center justify-center rounded-2xl bg-violet-100 text-3xl"
        aria-hidden="true"
      >
        <UsersRound className="size-8" />
      </div>
      {state.preview?.available ? (
        <>
          <h1 className="text-center text-2xl font-semibold tracking-tight">
            {state.content?.name ?? state.preview.name}
          </h1>
          <p className="text-center text-sm text-muted-foreground">
            {state.preview.kind === "informal"
              ? "Community group"
              : "Organization"}
            {state.content?.locality ? ` · ${state.content.locality}` : ""}
          </p>
          {state.content ? (
            <p className="whitespace-pre-wrap leading-relaxed">
              {state.content.description}
            </p>
          ) : null}
          <p>
            {authority
              ? "A single-use organizer invitation, valid for seven days."
              : "Join this group directly. This invitation grants participation only."}
          </p>
          {authority ? (
            <div className="grid gap-3 rounded-xl bg-muted p-4">
              <strong>
                {state.preview.role === "co_creator"
                  ? "Co-creator"
                  : "Co-organizer"}
              </strong>
              <p>
                {state.preview.role === "co_creator"
                  ? coCreatorExplanation
                  : "Review requests, manage participants and participant links. Participation stays separate from this organizer role."}
              </p>
              <label className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={consent === consentKey && consentKey !== null}
                  disabled={blocked}
                  onChange={(e) =>
                    setConsent(e.target.checked ? consentKey : null)
                  }
                />
                <span>I understand and accept this organizer role.</span>
              </label>
            </div>
          ) : null}
        </>
      ) : !state.loading && !state.failure ? (
        <p>This invitation is unavailable.</p>
      ) : null}
      {state.failure ? (
        <Alert variant="destructive">
          <AlertDescription>
            {groupFailureMessage(state.failure)}
          </AlertDescription>
        </Alert>
      ) : null}
      {state.contentFailure ? (
        <p>Group details could not be loaded. Use Retry to check again.</p>
      ) : null}
      {state.readFailure ? (
        <Alert variant="destructive">
          <AlertDescription>
            {state.receipt
              ? "Your action was recorded, but current status could not be checked."
              : "Your account or status could not be checked."}
          </AlertDescription>
        </Alert>
      ) : null}
      {blocked ? (
        <p role="status">
          {state.busy ? "Saving your choice…" : "Checking invitation…"}
        </p>
      ) : null}
      {state.receipt ? (
        <>
          <p role="status">
            {current
              ? "Confirmed. Opening your group…"
              : state.current
                ? "The earlier action was recorded, but the membership or role is no longer current."
                : "Your action was recorded. Check current status to continue."}
          </p>
          <Button
            variant="outline"
            disabled={blocked}
            onClick={() => void controller.retryStatus()}
          >
            Retry status check
          </Button>
          {!authority &&
          !current &&
          state.current &&
          state.preview?.available ? (
            <Button
              disabled={blocked}
              onClick={() => void controller.accept(version, policy, true)}
            >
              Join again
            </Button>
          ) : null}
        </>
      ) : (
        <>
          {ready && !state.policyAccepted ? (
            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                checked={policy}
                disabled={blocked}
                onChange={(e) =>
                  setPolicyAccount(
                    e.target.checked
                      ? state.auth?.account
                        ? `${state.auth.account}/${controller.consentEpoch}`
                        : null
                      : null,
                  )
                }
              />
              <span>
                I accept the{" "}
                <a
                  className="underline"
                  href={`${publicPolicies}/terms`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Terms
                </a>{" "}
                and{" "}
                <a
                  className="underline"
                  href={`${publicPolicies}/community-rules`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Community Rules
                </a>
                .
              </span>
            </label>
          ) : null}
          {state.preview?.available && !ready ? (
            <Button
              render={
                <Link
                  prefetch={false}
                  href={`${state.auth?.phase === "incompleteProfile" ? "/profile" : "/auth"}?returnTo=${encodeURIComponent(returnTo)}`}
                />
              }
              nativeButton={false}
            >
              {" "}
              {state.auth?.phase === "incompleteProfile"
                ? "Complete profile"
                : "Sign in to continue"}
            </Button>
          ) : null}
          {ready && (state.preview?.available || state.hasAttempt) ? (
            <Button
              className="h-auto min-h-12 whitespace-normal rounded-full bg-violet-600 text-base text-white hover:bg-violet-500"
              disabled={
                blocked ||
                !!state.readFailure ||
                (!state.policyAccepted && !policy) ||
                (authority &&
                  !state.hasAttempt &&
                  (consentKey === null || consent !== consentKey))
              }
              onClick={() => void controller.accept(version, policy)}
            >
              {state.hasAttempt
                ? "Retry original action"
                : authority
                  ? "Accept organizer role"
                  : "Join group"}
            </Button>
          ) : null}
        </>
      )}
      <Button
        variant="outline"
        disabled={blocked}
        onClick={() => void controller.open(token, authority)}
      >
        Retry
      </Button>
      <Link
        className="text-center text-sm underline"
        href={state.preview?.available ? `/groups/${state.preview.id}` : "/"}
      >
        Close
      </Link>
    </div>
  );
}
