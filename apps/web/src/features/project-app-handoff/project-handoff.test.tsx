import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { parseHandoffConfig } from "./handoff-config";
import { OrdinaryProjectHandoff } from "./ordinary-project-handoff";
import { ProjectAppHandoff } from "./project-app-handoff";
import {
  confirmationPath,
  hasOrdinaryIntent,
  projectAppUrl,
} from "./project-links";
import { project } from "../project-participant-invites/participant-test-fixtures";
const replace = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
describe("ordinary and confirmed app handoff", () => {
  it.each(
    [undefined, "Join", "other", ["join"], ["join", "join"]].map((value) => ({
      value,
    })),
  )("does not activate ambiguous ordinary intent $value", ({ value }) =>
    expect(hasOrdinaryIntent(value)).toBe(false),
  );
  it("activates only exact single intent", () =>
    expect(hasOrdinaryIntent("join")).toBe(true));
  it.each(["one_time", "recurring"] as const)(
    "builds %s token-free public and confirmation targets",
    (kind) => {
      const context = { ...project, kind };
      const path = `/${kind === "one_time" ? "proposals" : "tavoli"}/${project.id}`;
      expect(projectAppUrl(context, true)).toBe(
        `https://planets.community${path}?intent=join`,
      );
      expect(projectAppUrl(context)).toBe(`https://planets.community${path}`);
      expect(confirmationPath(context)).toBe(`/joined${path}`);
    },
  );
  it.each(["one_time", "recurring"] as const)(
    "dismisses %s joining intent while retaining public detail without auth",
    (kind) => {
      const context = { ...project, kind };
      render(
        <OrdinaryProjectHandoff
          project={context}
          config={{}}
          intent
          joinable
        />,
      );
      expect(screen.getByText("Want to join?")).toBeVisible();
      expect(screen.queryByText("Sign in")).not.toBeInTheDocument();
      expect(
        screen.getByRole("link", { name: "Open PLANETS" }),
      ).toHaveAttribute("href", projectAppUrl(context, true));
      fireEvent.click(
        screen.getByRole("button", { name: "Dismiss joining intent" }),
      );
      expect(screen.getByText("Take part with PLANETS")).toBeVisible();
      expect(replace).toHaveBeenCalledWith(
        new URL(projectAppUrl(context)).pathname,
        { scroll: false },
      );
    },
  );
  it("describes paused/ended participation truthfully and uses non-mutating detail", () => {
    render(
      <OrdinaryProjectHandoff
        project={project}
        config={{}}
        intent={false}
        joinable={false}
      />,
    );
    expect(
      screen.getByText(/not currently accepting participation/),
    ).toBeVisible();
    expect(screen.getByRole("link", { name: "Open PLANETS" })).toHaveAttribute(
      "href",
      projectAppUrl(project),
    );
  });
  it("shows same-account explanation and disabled store badges without fallback clutter or automatic navigation", () => {
    render(<ProjectAppHandoff project={project} config={{}} confirmed />);
    expect(screen.getByText(/same PLANETS account/)).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Google Play (coming soon)" }),
    ).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "App Store (coming soon)" }),
    ).toBeDisabled();
    expect(
      screen.queryByText(
        /App downloads are not available|If the app doesn't open/i,
      ),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("link", { name: "View Project in this browser" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Open PLANETS" })).toHaveAttribute(
      "href",
      projectAppUrl(project),
    );
    expect(replace).not.toHaveBeenCalled();
  });
  it("renders configured deliberate downloads without attaching admission/session data", () => {
    render(
      <ProjectAppHandoff
        project={project}
        config={{
          android: "https://downloads.example/android",
          ios: "https://downloads.example/ios",
        }}
        confirmed
      />,
    );
    expect(
      screen.getByRole("link", { name: "Download on Google Play" }),
    ).toHaveAttribute("href", "https://downloads.example/android");
    expect(
      screen.getByRole("link", { name: "Download on App Store" }),
    ).toHaveAttribute("href", "https://downloads.example/ios");
  });
  it("omits missing listings and permits HTTP only on explicit local loopback", () => {
    expect(parseHandoffConfig({})).toEqual({});
    expect(
      parseHandoffConfig({
        NEXT_PUBLIC_APP_ENV: "local",
        NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL:
          "http://127.0.0.1:1234/download",
      }),
    ).toEqual({ android: "http://127.0.0.1:1234/download" });
  });
  it.each([
    "javascript:alert(1)",
    "ftp://example.com/a",
    "https://user:secret@example.com/a",
    "https://example.com/#",
    "https://example.com/#section",
    "http://example.com/a",
    "http://localhost/a",
    "relative",
    "#",
  ])("fails clearly on unsafe download %s", (value) => {
    expect(() =>
      parseHandoffConfig({ NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL: value }),
    ).toThrow(/NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL/);
  });
});
