import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AuthFlow, type AuthNavigation } from "@/features/auth/auth-flow";
import { AuthSessionActions } from "@/features/auth/auth-session-actions";
import type { WebAuthGateway } from "@/features/auth/auth-gateway";

const routerReplace = vi.fn();
const routerRefresh = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: routerReplace, refresh: routerRefresh }),
}));

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe("AuthFlow", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("validates email before making a request", () => {
    const gateway = createGateway();
    render(<AuthFlow returnTo="/" gateway={gateway} />);

    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "not-an-email" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Send code" }));

    expect(screen.getByText("Enter a valid email address.")).toBeVisible();
    expect(gateway.requestEmailOtp).not.toHaveBeenCalled();
  });

  it("trims without lowercasing and transitions to a masked code form", async () => {
    const gateway = createGateway();
    render(<AuthFlow returnTo="/" gateway={gateway} />);

    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "  Person@Example.COM  " },
    });
    fireEvent.click(screen.getByRole("button", { name: "Send code" }));

    expect(await screen.findByLabelText("Six-digit code")).toBeVisible();
    expect(gateway.requestEmailOtp).toHaveBeenCalledWith("Person@Example.COM");
    expect(screen.getByText(/P•••@Example\.COM/u)).toBeVisible();
    expect(screen.queryByText(/Person@Example\.COM/u)).not.toBeInTheDocument();
  });

  it("prevents duplicate requests while one is active", async () => {
    const deferred = createDeferred<void>();
    const gateway = createGateway();
    vi.mocked(gateway.requestEmailOtp).mockReturnValueOnce(deferred.promise);
    render(<AuthFlow returnTo="/" gateway={gateway} />);
    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "person@example.com" },
    });
    const form = screen.getByLabelText("Email").closest("form");
    expect(form).not.toBeNull();

    fireEvent.submit(form!);
    fireEvent.submit(form!);

    expect(gateway.requestEmailOtp).toHaveBeenCalledOnce();
    await act(async () => deferred.resolve());
    expect(screen.getByLabelText("Six-digit code")).toBeVisible();
  });

  it("keeps verification active for an invalid token", async () => {
    const gateway = createGateway();
    render(<AuthFlow returnTo="/" gateway={gateway} />);
    await requestCode("person@example.com");

    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "12345" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));

    expect(
      screen.getByText("Enter the six-digit code from the email."),
    ).toBeVisible();
    expect(screen.getByLabelText("Six-digit code")).toBeVisible();
    expect(gateway.verifyEmailOtp).not.toHaveBeenCalled();
  });

  it("enforces a 30-second UI resend cooldown", async () => {
    vi.useFakeTimers();
    let currentTime = 1_000;
    const now = () => currentTime;
    const gateway = createGateway();
    render(<AuthFlow returnTo="/" gateway={gateway} now={now} />);

    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "person@example.com" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Send code" }));
    await act(async () => Promise.resolve());

    expect(
      screen.getByRole("button", { name: "Resend in 30s" }),
    ).toBeDisabled();
    currentTime += 30_000;
    act(() => vi.advanceTimersByTime(30_000));
    const resend = screen.getByRole("button", { name: "Resend code" });
    expect(resend).toBeEnabled();

    fireEvent.click(resend);
    await act(async () => Promise.resolve());
    expect(gateway.requestEmailOtp).toHaveBeenCalledTimes(2);
  });

  it("verifies, ensures the anchor, and refreshes the safe destination", async () => {
    const gateway = createGateway();
    const navigation = createNavigation();
    render(
      <AuthFlow
        returnTo="/proposals?nearby=true"
        gateway={gateway}
        navigation={navigation}
      />,
    );
    await requestCode("Person@Example.COM");

    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "123456" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));

    await waitFor(() => {
      expect(gateway.verifyEmailOtp).toHaveBeenCalledWith(
        "Person@Example.COM",
        "123456",
      );
      expect(gateway.ensureCurrentProfileAnchor).toHaveBeenCalledOnce();
      expect(navigation.replace).toHaveBeenCalledWith("/proposals?nearby=true");
      expect(navigation.refresh).toHaveBeenCalledOnce();
    });
  });

  it("keeps the valid session and exposes retry after profile setup fails", async () => {
    const gateway = createGateway();
    const navigation = createNavigation();
    const rawFailure = "private database diagnostics";
    vi.mocked(gateway.ensureCurrentProfileAnchor).mockRejectedValueOnce(
      new Error(rawFailure),
    );
    render(<AuthFlow returnTo="/" gateway={gateway} navigation={navigation} />);
    await requestCode("Person@Example.COM");
    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "123456" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));

    expect(await screen.findByText("Finish session setup")).toBeVisible();
    expect(screen.getByText(/session is active/u)).toBeVisible();
    expect(document.body).not.toHaveTextContent(rawFailure);
    expect(document.body).not.toHaveTextContent("Person@Example.COM");
    expect(document.body).not.toHaveTextContent("123456");
    expect(navigation.replace).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Try setup again" }));
    await waitFor(() => {
      expect(gateway.ensureCurrentProfileAnchor).toHaveBeenCalledTimes(2);
      expect(navigation.replace).toHaveBeenCalledWith("/");
      expect(navigation.refresh).toHaveBeenCalledOnce();
    });
  });

  it("renders safe verification failures without raw provider detail", async () => {
    const gateway = createGateway();
    const rawFailure = "raw OTP backend stack for Person@Example.COM";
    vi.mocked(gateway.verifyEmailOtp).mockRejectedValueOnce({
      code: "invalid_otp",
      message: rawFailure,
      status: 403,
    });
    render(<AuthFlow returnTo="/" gateway={gateway} />);
    await requestCode("Person@Example.COM");
    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "123456" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));

    expect(
      await screen.findByText("Enter the six-digit code from the email."),
    ).toBeVisible();
    expect(document.body).not.toHaveTextContent(rawFailure);
    expect(document.body).not.toHaveTextContent("Person@Example.COM");
  });
});

describe("AuthSessionActions", () => {
  it("returns participant cancellation to the preview and preserves authority/Home defaults", async () => {
    const gateway = createGateway();
    const navigation = createNavigation();
    const returnTo = `/join/project/${"a".repeat(43)}`;
    render(
      <AuthSessionActions
        profileSetupRequired
        returnTo={returnTo}
        gateway={gateway}
        navigation={navigation}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));
    await waitFor(() =>
      expect(navigation.replace).toHaveBeenCalledWith(returnTo),
    );
  });
  it("retries restored profile setup without another OTP", async () => {
    const gateway = createGateway();
    const navigation = createNavigation();
    render(
      <AuthSessionActions
        profileSetupRequired
        returnTo="/proposals"
        gateway={gateway}
        navigation={navigation}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "Try setup again" }));

    await waitFor(() => {
      expect(gateway.ensureCurrentProfileAnchor).toHaveBeenCalledOnce();
      expect(gateway.verifyEmailOtp).not.toHaveBeenCalled();
      expect(navigation.replace).toHaveBeenCalledWith("/proposals");
      expect(navigation.refresh).toHaveBeenCalledOnce();
    });
  });

  it("signs out and refreshes the public root", async () => {
    const gateway = createGateway();
    const navigation = createNavigation();
    render(
      <AuthSessionActions
        profileSetupRequired={false}
        returnTo="/"
        gateway={gateway}
        navigation={navigation}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));

    await waitFor(() => {
      expect(gateway.signOut).toHaveBeenCalledOnce();
      expect(navigation.replace).toHaveBeenCalledWith("/");
      expect(navigation.refresh).toHaveBeenCalledOnce();
    });
  });
});

async function requestCode(email: string): Promise<void> {
  fireEvent.change(screen.getByLabelText("Email"), {
    target: { value: email },
  });
  fireEvent.click(screen.getByRole("button", { name: "Send code" }));
  await screen.findByLabelText("Six-digit code");
}

function createGateway(): WebAuthGateway {
  return {
    requestEmailOtp: vi.fn().mockResolvedValue(undefined),
    verifyEmailOtp: vi.fn().mockResolvedValue(undefined),
    ensureCurrentProfileAnchor: vi.fn().mockResolvedValue(undefined),
    signOut: vi.fn().mockResolvedValue(undefined),
  };
}

describe("participant OTP continuity", () => {
  it("ignores verification completion after leaving the flow", async () => {
    const gateway = createGateway();
    const pending = createDeferred<void>();
    vi.mocked(gateway.verifyEmailOtp).mockReturnValue(pending.promise);
    const navigation = createNavigation();
    const view = render(
      <AuthFlow
        returnTo="/profile"
        gateway={gateway}
        navigation={navigation}
      />,
    );
    await requestCode("stale-flow@planets.invalid");
    fireEvent.change(screen.getByLabelText("Six-digit code"), {
      target: { value: "123456" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Verify code" }));
    view.unmount();
    await act(async () => pending.resolve());
    expect(gateway.ensureCurrentProfileAnchor).not.toHaveBeenCalled();
    expect(navigation.replace).not.toHaveBeenCalled();
  });
  it.each(["new-user@planets.invalid", "existing-user@planets.invalid"])(
    "returns %s to explicit invitation after OTP/anchor only",
    async (email) => {
      const gateway = createGateway();
      const navigation = createNavigation();
      const returnTo = `/join/project/${"a".repeat(43)}`;
      render(
        <AuthFlow
          returnTo={returnTo}
          gateway={gateway}
          navigation={navigation}
        />,
      );
      expect(
        screen.getByRole("button", { name: "Back to invitation" }),
      ).toHaveAttribute("href", returnTo);
      await requestCode(email);
      expect(
        screen.getByRole("link", { name: "Cancel sign-in" }),
      ).toHaveAttribute("href", returnTo);
      fireEvent.change(screen.getByLabelText("Six-digit code"), {
        target: { value: "123456" },
      });
      fireEvent.click(screen.getByRole("button", { name: "Verify code" }));
      await waitFor(() =>
        expect(navigation.replace).toHaveBeenCalledWith(returnTo),
      );
      expect(gateway.ensureCurrentProfileAnchor).toHaveBeenCalledOnce();
    },
  );
});

function createNavigation(): AuthNavigation {
  return { replace: vi.fn(), refresh: vi.fn() };
}

function createDeferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}
