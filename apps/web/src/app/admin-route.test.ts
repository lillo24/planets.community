import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  notFound: vi.fn((): never => {
    throw new Error("NEXT_NOT_FOUND");
  }),
  readModerationCase: vi.fn(),
  readModerationQueue: vi.fn(),
  requireCurrentModerationStaff: vi.fn(),
}));

vi.mock("next/navigation", () => ({ notFound: mocks.notFound }));
vi.mock("@/features/moderation/moderation-server", () => ({
  readModerationCase: mocks.readModerationCase,
  readModerationQueue: mocks.readModerationQueue,
  requireCurrentModerationStaff: mocks.requireCurrentModerationStaff,
}));

describe("staff-only admin route group", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("terminates before the admin loading boundary when staff access is denied", async () => {
    mocks.requireCurrentModerationStaff.mockResolvedValueOnce(null);
    const { default: AdminLayout } = await import("@/app/(admin)/layout");

    await expect(AdminLayout({ children: "protected" })).rejects.toThrow(
      "NEXT_NOT_FOUND",
    );
    expect(mocks.notFound).toHaveBeenCalledOnce();
  });

  it("renders the protected branch after staff identity is established", async () => {
    mocks.requireCurrentModerationStaff.mockResolvedValueOnce({
      profileId: "staff-profile",
      role: "moderator",
    });
    const { default: AdminLayout } = await import("@/app/(admin)/layout");

    await expect(AdminLayout({ children: "protected" })).resolves.toBe(
      "protected",
    );
    expect(mocks.notFound).not.toHaveBeenCalled();
  });
});

describe("staff-only admin route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it.each(["signed-out", "ordinary authenticated non-staff"])(
    "%s queue access terminates through the not-found boundary",
    async () => {
      mocks.readModerationQueue.mockResolvedValueOnce({ status: "denied" });
      const { default: AdminPage } = await import("@/app/(admin)/admin/page");

      await expect(
        AdminPage({ searchParams: Promise.resolve({}) }),
      ).rejects.toThrow("NEXT_NOT_FOUND");
      expect(mocks.notFound).toHaveBeenCalledOnce();
    },
  );

  it("renders queue unavailable after an authorized operational failure", async () => {
    mocks.readModerationQueue.mockRejectedValueOnce(
      new Error("The moderation queue could not be loaded."),
    );
    const { default: AdminPage } = await import("@/app/(admin)/admin/page");

    render(await AdminPage({ searchParams: Promise.resolve({}) }));
    expect(screen.getByText("Queue unavailable")).toBeDefined();
    expect(mocks.notFound).not.toHaveBeenCalled();
  });

  it("exposes state filters and pagination as native navigation links", async () => {
    mocks.readModerationQueue.mockResolvedValueOnce({
      status: "ready",
      staffRole: "moderator",
      page: { cases: [], nextCursor: "next-page" },
    });
    const { default: AdminPage } = await import("@/app/(admin)/admin/page");
    const view = render(
      await AdminPage({
        searchParams: Promise.resolve({ state: "under_review" }),
      }),
    );
    expect(screen.getByRole("link", { name: "Under review" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByRole("link", { name: "Received" })).toHaveAttribute(
      "href",
      "/admin?state=received",
    );
    expect(screen.getByRole("link", { name: "More cases" })).toHaveAttribute(
      "href",
      "/admin?state=under_review&cursor=next-page",
    );
    expect(screen.queryByRole("button", { name: "More cases" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Under review" })).toBeNull();
    view.unmount();
  });
});

describe("staff-only moderation case route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("denied case access terminates through the not-found boundary", async () => {
    mocks.readModerationCase.mockResolvedValueOnce({ status: "denied" });
    const { default: ModerationCasePage } =
      await import("@/app/(admin)/admin/cases/[id]/page");

    await expect(
      ModerationCasePage({ params: Promise.resolve({ id: caseId }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(mocks.notFound).toHaveBeenCalledOnce();
  });

  it("renders case unavailable after an authorized operational failure", async () => {
    mocks.readModerationCase.mockRejectedValueOnce(
      new Error("The moderation case could not be loaded."),
    );
    const { default: ModerationCasePage } =
      await import("@/app/(admin)/admin/cases/[id]/page");

    render(
      await ModerationCasePage({ params: Promise.resolve({ id: caseId }) }),
    );
    expect(screen.getByText("Case unavailable")).toBeDefined();
    expect(mocks.notFound).not.toHaveBeenCalled();
  });
});

const caseId = "00000000-0000-4000-8000-000000000901";
