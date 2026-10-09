import { createRoot } from "react-dom/client";
import { useEffect, useState, useSyncExternalStore } from "react";
import type { trialPublicConfig } from "./public-config";
import { trialRoute, trialReturn } from "./routes";
import { createSupabaseBrowserClient } from "../src/lib/supabase/browser";
import {
  ClientNavigationProvider,
  type ClientLinkProps,
} from "../src/lib/navigation/client-navigation";
import { SupabaseWebAuthGateway } from "../src/features/auth/auth-gateway";
import { AuthFlowView } from "../src/features/auth/auth-flow-view";
import { participantCancelDestination } from "../src/features/auth/return-destination";
import { ProfileFormView } from "../src/features/profile/profile-form-view";
import { readProfilePageData } from "../src/features/profile/profile-read";
import type { ProfileEditorData } from "../src/features/profile/profile-models";
import { SupabaseWebProfileGateway } from "../src/features/profile/profile-gateway";
import { ParticipantController } from "../src/features/project-participant-invites/participant-controller";
import { SupabaseParticipantGateway } from "../src/features/project-participant-invites/participant-gateway";
import { ParticipantInviteFlowView } from "../src/features/project-participant-invites/participant-invite-flow-view";
import { ParticipantConfirmationView } from "../src/features/project-participant-invites/participant-confirmation-view";
import { readParticipantAuth } from "../src/features/project-participant-invites/participant-rpc";
import type { ParticipantAuth } from "../src/features/project-participant-invites/participant-models";
import { planetsPublicOrigin } from "../src/features/project-app-handoff/project-links";
import "../src/app/globals.css";
import "./trial.css";

declare const STATIC_INVITATION_CONFIG: ReturnType<typeof trialPublicConfig>;
const { config, handoff } = STATIC_INVITATION_CONFIG;
const client = createSupabaseBrowserClient(config, true);
const authGateway = new SupabaseWebAuthGateway(client);
const profileGateway = new SupabaseWebProfileGateway(client);
// Exactly one controller per tab/process. Only the SDK session uses cookies;
// invitation capabilities and action UUIDs never enter browser storage.
const controller = new ParticipantController(
  new SupabaseParticipantGateway(client),
);
let identity: string | null | undefined;
let identityEpoch = 0;
const identityListeners = new Set<() => void>();
client.auth.onAuthStateChange((_event, session) => {
  const next = session?.user.id ?? null;
  if (next === identity) return;
  identity = next;
  identityEpoch++;
  identityListeners.forEach((listener) => listener());
});
const identitySubscribe = (listener: () => void) => {
  identityListeners.add(listener);
  return () => {
    identityListeners.delete(listener);
  };
};
const epochSnapshot = () => identityEpoch;
let routeRevision = 0;
const routeListeners = new Set<() => void>();
const routeSnapshot = () =>
  `${routeRevision}:${location.pathname}${location.search}${location.hash}`;
const routeSubscribe = (listener: () => void) => {
  routeListeners.add(listener);
  return () => {
    routeListeners.delete(listener);
  };
};
function publishRoute() {
  routeRevision++;
  routeListeners.forEach((listener) => listener());
}
window.addEventListener("popstate", publishRoute);
window.addEventListener("pageshow", (event) => {
  if (event.persisted) publishRoute();
});
function navigate(destination: string, replace = false) {
  const url = new URL(destination, location.origin);
  if (url.origin !== location.origin || !trialRoute(url.pathname))
    throw new Error("Navigation is outside the static trial.");
  if (replace) history.replaceState(null, "", url);
  else history.pushState(null, "", url);
  publishRoute();
}
function TrialLink({
  href,
  prefetch: _prefetch,
  onClick,
  ...props
}: ClientLinkProps) {
  void _prefetch;
  // Public Project viewing belongs to the canonical owner, not this trial shell.
  const publicProject = /^\/(proposals|tavoli)\//u.test(href);
  const destination = publicProject ? `${planetsPublicOrigin}${href}` : href;
  return (
    <a
      {...props}
      href={destination}
      referrerPolicy="no-referrer"
      onClick={(event) => {
        onClick?.(event);
        if (
          event.defaultPrevented ||
          event.button !== 0 ||
          event.metaKey ||
          event.ctrlKey ||
          event.shiftKey ||
          event.altKey ||
          props.target ||
          publicProject
        )
          return;
        const url = new URL(destination, location.origin);
        if (url.origin === location.origin && trialRoute(url.pathname)) {
          event.preventDefault();
          navigate(destination);
        }
      }}
    />
  );
}
const emptyRead = {};
function useIdentityEpoch() {
  return useSyncExternalStore(identitySubscribe, epochSnapshot);
}
function RetryError({ retry }: { retry(): void }) {
  return (
    <div role="alert">
      <p>This read could not be completed. No join was submitted.</p>
      <button onClick={retry}>Retry read</button>
    </div>
  );
}
function AuthPage({ returnTo }: { returnTo: string }) {
  const epoch = useIdentityEpoch();
  const [attempt, setAttempt] = useState(0);
  const [state, setState] = useState<ParticipantAuth | "error" | null>(null);
  useEffect(() => {
    let live = true;
    async function readAndRoute() {
      try {
        let auth = await readParticipantAuth(client);
        if (!live || epoch !== identityEpoch) return;
        // Same minimal canonical anchor used after OTP. Auth/profile restoration
        // never admits; failures retain the explicit session-setup retry below.
        if (auth.phase === "missingProfile") {
          try {
            await authGateway.ensureCurrentProfileAnchor();
            if (!live || epoch !== identityEpoch) return;
            auth = await readParticipantAuth(client);
          } catch {
            if (live && epoch === identityEpoch) setState(auth);
            return;
          }
        }
        if (!live || epoch !== identityEpoch) return;
        if (auth.phase === "ready") navigate(returnTo, true);
        else if (auth.phase === "incompleteProfile")
          navigate(
            `/profile?returnTo=${encodeURIComponent(participantCancelDestination(returnTo).startsWith("/join/project/") ? participantCancelDestination(returnTo) : returnTo)}`,
            true,
          );
        else setState(auth);
      } catch {
        if (live && epoch === identityEpoch) setState("error");
      }
    }
    void readAndRoute();
    return () => {
      live = false;
    };
  }, [epoch, attempt, returnTo]);
  if (state === "error")
    return <RetryError retry={() => setAttempt((n) => n + 1)} />;
  if (!state) return <p role="status">Checking your account…</p>;
  if (state.phase === "missingProfile")
    return (
      <div>
        <p>Finish session setup before continuing.</p>
        <button
          onClick={() => {
            void authGateway.ensureCurrentProfileAnchor().then(
              () => {
                if (epoch === identityEpoch) setAttempt((n) => n + 1);
              },
              () => setState("error"),
            );
          }}
        >
          Try setup again
        </button>
        <TrialLink href={participantCancelDestination(returnTo)}>
          Back to invitation
        </TrialLink>
      </div>
    );
  return <AuthFlowView returnTo={returnTo} gateway={authGateway} />;
}
function ProfilePage({ returnTo }: { returnTo: string }) {
  const epoch = useIdentityEpoch();
  const [attempt, setAttempt] = useState(0);
  const [data, setData] = useState<ProfileEditorData | "error" | null>(null);
  useEffect(() => {
    let live = true;
    void readProfilePageData(async () => client).then(
      (result) => {
        if (!live || epoch !== identityEpoch) return;
        if (result.status !== "ready")
          navigate(
            `/auth?returnTo=${encodeURIComponent(`/profile?returnTo=${encodeURIComponent(returnTo)}`)}`,
            true,
          );
        else setData(result.data);
      },
      () => {
        if (live && epoch === identityEpoch) setData("error");
      },
    );
    return () => {
      live = false;
    };
  }, [epoch, attempt, returnTo]);
  return (
    <>
      <TrialLink href={participantCancelDestination(returnTo)}>
        Cancel profile setup
      </TrialLink>
      {data === "error" ? (
        <RetryError retry={() => setAttempt((n) => n + 1)} />
      ) : data ? (
        <ProfileFormView
          key={data.profile.id}
          initialData={data}
          nameOnly
          returnTo={returnTo}
          gateway={profileGateway}
        />
      ) : (
        <p role="status">Loading your basic profile…</p>
      )}
    </>
  );
}
function App() {
  const routeKey = useSyncExternalStore(routeSubscribe, routeSnapshot);
  const epoch = useIdentityEpoch();
  const [logoutFailure, setLogoutFailure] = useState(false);
  const route = trialRoute(location.pathname);
  const returns = new URLSearchParams(location.search).getAll("returnTo");
  const returnTo = trialReturn(returns.length === 1 ? returns[0] : undefined);
  const adapter = {
    Link: TrialLink,
    replace(destination: string) {
      if (routeKey === routeSnapshot() && epoch === identityEpoch)
        navigate(trialReturn(destination), true);
    },
    refresh() {
      if (routeKey === routeSnapshot() && epoch === identityEpoch)
        publishRoute();
    },
  };
  return (
    <ClientNavigationProvider adapter={adapter}>
      <header>
        <strong>PLANETS</strong>
        {identity ? (
          <button
            onClick={() => {
              setLogoutFailure(false);
              void authGateway.signOut().catch(() => setLogoutFailure(true));
            }}
          >
            Sign out
          </button>
        ) : null}
      </header>
      {logoutFailure ? <p role="alert">Sign-out failed. Try again.</p> : null}
      <main
        key={`${routeKey}:${route?.kind === "profile" || route?.kind === "auth" ? epoch : ""}`}
        className="mx-auto grid w-full max-w-3xl gap-6 p-6"
      >
        {route?.kind === "invite" ? (
          <ParticipantInviteFlowView
            token={route.token}
            initialRead={emptyRead}
            config={handoff}
            controller={controller}
          />
        ) : route?.kind === "confirmation" ? (
          <ParticipantConfirmationView
            project={route.project}
            config={handoff}
            controller={controller}
          />
        ) : route?.kind === "auth" ? (
          <AuthPage returnTo={returnTo} />
        ) : route?.kind === "profile" ? (
          <ProfilePage returnTo={returnTo} />
        ) : route?.kind === "home" ? (
          <>
            <h1>PLANETS invitation trial</h1>
            <p>
              Open a participant invitation to preview it. Joining always needs
              your explicit confirmation.
            </p>
            <a href={planetsPublicOrigin} referrerPolicy="no-referrer">
              Visit PLANETS
            </a>
          </>
        ) : (
          <h1>Page not found</h1>
        )}
      </main>
    </ClientNavigationProvider>
  );
}
createRoot(document.getElementById("root")!).render(<App />);
