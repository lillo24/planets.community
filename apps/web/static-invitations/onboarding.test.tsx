import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from "@testing-library/react";
import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";
import type { ParticipantAuth } from "../src/features/project-participant-invites/participant-models";
import type { App as TrialApp } from "./main";
import {
  account,
  project,
  receipt,
  token,
} from "../src/features/project-participant-invites/participant-test-fixtures";

const fake = vi.hoisted(() => {
  const state = {
    account: null as string | null,
    displayName: "",
    current: false,
    kind: "one_time" as "one_time" | "recurring",
  };
  const observers = new Set<
    (event: string, session: { user: { id: string } } | null) => void
  >();
  function identify(id: string | null) {
    state.account = id;
    observers.forEach((callback) =>
      callback("SIGNED_IN", id ? { user: { id } } : null),
    );
  }
  const readAuth = vi.fn(async (): Promise<ParticipantAuth> => ({
    account: state.account,
    phase: !state.account
      ? "signedOut"
      : state.displayName
        ? "ready"
        : "incompleteProfile",
  }));
  const accept = vi.fn();
  const participation = vi.fn();
  const verifyOtp = vi.fn();
  const rpc = vi.fn();
  const client = {
    auth: {
      onAuthStateChange(
        callback: (
          event: string,
          session: { user: { id: string } } | null,
        ) => void,
      ) {
        observers.add(callback);
        callback(
          "INITIAL_SESSION",
          state.account ? { user: { id: state.account } } : null,
        );
        return {
          data: {
            subscription: { unsubscribe: () => observers.delete(callback) },
          },
        };
      },
      signInWithOtp: vi.fn(async () => ({ data: {}, error: null })),
      verifyOtp,
      getClaims: vi.fn(async () => ({
        data: { claims: { sub: state.account } },
        error: null,
      })),
      signOut: vi.fn(async () => {
        identify(null);
        return { error: null };
      }),
    },
    from: vi.fn(() => ({ insert: vi.fn(async () => ({ error: null })) })),
    rpc,
  };
  return {
    state,
    identify,
    readAuth,
    accept,
    participation,
    verifyOtp,
    rpc,
    client,
  };
});

vi.mock("client-only", () => ({}));
// The entry point has no #root in this test. Keep Testing Library's real roots.
vi.mock("react-dom/client", async (importOriginal) => {
  const original = await importOriginal<typeof import("react-dom/client")>();
  return {
    ...original,
    createRoot: ((container, options) =>
      container
        ? original.createRoot(container, options)
        : { render() {} }) as typeof original.createRoot,
  };
});
vi.mock("../src/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => fake.client,
}));
vi.mock("../src/features/project-participant-invites/participant-rpc", () => ({
  readParticipantAuth: fake.readAuth,
}));
vi.mock(
  "../src/features/project-participant-invites/participant-project-gateway",
  () => ({
    SupabaseInvitationProjectGateway: class {
      read = async () => ({
        title: "Community mural",
        description: "Paint a mural with people in your city.",
        coverObjectPath: null,
      });
      cover = vi.fn();
    },
  }),
);
vi.mock(
  "../src/features/project-participant-invites/participant-gateway",
  () => ({
    SupabaseParticipantGateway: class {
      auth = fake.readAuth;
      preview = async () => ({
        available: true,
        project: { ...project, kind: fake.state.kind },
        title: "Community mural",
      });
      accept = fake.accept;
      participation = fake.participation;
      observeIdentity(listener: (id: string | null) => void) {
        return fake.client.auth.onAuthStateChange((_event, session) =>
          listener(session?.user.id ?? null),
        ).data.subscription.unsubscribe;
      }
    },
  }),
);
vi.mock("../src/features/profile/profile-read", () => ({
  readProfilePageData: async () => ({
    status: "ready",
    data: {
      profile: {
        id: fake.state.account,
        displayName: fake.state.displayName,
        bio: null,
        selectedSkillIds: [],
        visibility: {
          display_name: "public",
          bio: "private",
          skills: "private",
        },
      },
      categories: [],
    },
  }),
}));

let App: typeof TrialApp;
const invitationPath = `/join/project/${token}`;
beforeAll(async () => {
  vi.stubGlobal("STATIC_INVITATION_CONFIG", { config: {}, handoff: {} });
  ({ App } = await import("./main"));
});
beforeEach(() => {
  vi.clearAllMocks();
  fake.identify(null);
  fake.state.displayName = "";
  fake.state.current = false;
  fake.state.kind = "one_time";
  fake.verifyOtp.mockImplementation(async () => {
    fake.identify(account);
    return {
      data: { user: { id: account }, session: { user: { id: account } } },
      error: null,
    };
  });
  fake.participation.mockImplementation(async () => ({
    current: fake.state.current,
    creator: false,
  }));
  fake.accept.mockImplementation(async () => {
    fake.state.current = true;
    return receipt;
  });
  fake.rpc.mockImplementation(
    async (_name: string, args: { p_display_name: string }) => {
      fake.state.displayName = args.p_display_name;
      return { error: null };
    },
  );
  history.replaceState(null, "", invitationPath);
});
afterEach(cleanup);

async function requestCode() {
  fireEvent.change(await screen.findByLabelText("Email"), {
    target: { value: "journey@planets.invalid" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Send code" }));
  await screen.findByLabelText("Six-digit code");
}
async function verifyCode() {
  fireEvent.change(screen.getByLabelText("Six-digit code"), {
    target: { value: "123456" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Verify code" }));
  await screen.findByRole("textbox", { name: "Name" });
}
async function saveName() {
  fireEvent.change(await screen.findByRole("textbox", { name: "Name" }), {
    target: { value: "Casey" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Continue" }));
}

describe("actual static host onboarding with canonical Auth/profile and admission UI", () => {
  it.each(["one_time", "recurring"] as const)(
    "completes %s after one Join, OTP and name, then reloads without admission",
    async (kind) => {
      fake.state.kind = kind;
      const page = render(<App />);
      const join = await screen.findByRole("link", { name: "Join Project" });
      expect(fake.accept).not.toHaveBeenCalled();
      expect(
        screen.queryByRole("button", { name: /refresh/i }),
      ).not.toBeInTheDocument();
      fireEvent.click(join);
      await requestCode();
      await verifyCode();
      expect(fake.accept).not.toHaveBeenCalled();
      await saveName();
      expect(await screen.findByText("You joined the project.")).toBeVisible();
      expect(location.pathname).toBe(
        `/joined/${kind === "one_time" ? "proposals" : "tavoli"}/${project.id}`,
      );
      expect(fake.accept).toHaveBeenCalledOnce();
      expect(
        screen.queryByRole("button", { name: /join|refresh/i }),
      ).not.toBeInTheDocument();
      page.unmount();
      render(<App />);
      expect(await screen.findByText("You joined the project.")).toBeVisible();
      expect(fake.accept).toHaveBeenCalledOnce();
    },
  );

  it("does not join on a restored session or a different tab's login", async () => {
    render(<App />);
    fireEvent.click(await screen.findByRole("link", { name: "Join Project" }));
    await requestCode();
    fake.state.displayName = "Existing name";
    await act(async () => fake.identify(account));
    expect(
      await screen.findByRole("button", { name: "Join Project" }),
    ).toBeVisible();
    expect(fake.accept).not.toHaveBeenCalled();
    cleanup();
    render(<App />);
    expect(
      await screen.findByRole("button", { name: "Join Project" }),
    ).toBeVisible();
    expect(fake.accept).not.toHaveBeenCalled();
  });

  it("continues a returning user's Join after local OTP without asking for their name again", async () => {
    fake.state.displayName = "Existing name";
    render(<App />);
    fireEvent.click(await screen.findByRole("link", { name: "Join Project" }));
    await requestCode();
    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "123456" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));
    expect(await screen.findByText("You joined the project.")).toBeVisible();
    expect(
      screen.queryByRole("textbox", { name: "Name" }),
    ).not.toBeInTheDocument();
    expect(fake.rpc).not.toHaveBeenCalled();
    expect(fake.accept).toHaveBeenCalledOnce();
  });

  it("continues a signed-in Join through name setup without an OTP or second Join", async () => {
    fake.identify(account);
    render(<App />);
    fireEvent.click(await screen.findByRole("link", { name: "Join Project" }));
    await saveName();
    expect(await screen.findByText("You joined the project.")).toBeVisible();
    expect(fake.verifyOtp).not.toHaveBeenCalled();
    expect(fake.accept).toHaveBeenCalledOnce();
  });

  it("clears a pending Join on cancellation and browser Back", async () => {
    render(<App />);
    fireEvent.click(await screen.findByRole("link", { name: "Join Project" }));
    await requestCode();
    expect(
      screen.queryByRole("link", { name: "Cancel sign-in" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("link", { name: "Back to project" }));
    expect(
      await screen.findByRole("link", { name: "Join Project" }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("link", { name: "Join Project" }));
    await requestCode();
    await verifyCode();
    fake.state.displayName = "Saved elsewhere";
    await act(async () => {
      history.replaceState(null, "", invitationPath);
      window.dispatchEvent(new PopStateEvent("popstate"));
    });
    expect(
      await screen.findByRole("button", { name: "Join Project" }),
    ).toBeVisible();
    expect(fake.accept).not.toHaveBeenCalled();
  });

  it("makes a failed participation check read-only to retry, requiring a fresh Join", async () => {
    render(<App />);
    fireEvent.click(await screen.findByRole("link", { name: "Join Project" }));
    await requestCode();
    await verifyCode();
    fake.participation.mockRejectedValueOnce(new Error("offline"));
    await saveName();
    fireEvent.click(
      await screen.findByRole("button", { name: "Retry status check" }),
    );
    expect(
      await screen.findByRole("button", { name: "Join Project" }),
    ).toBeVisible();
    expect(fake.accept).not.toHaveBeenCalled();
  });
});
