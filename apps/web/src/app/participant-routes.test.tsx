import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  preview,
  project,
  token,
} from "@/features/project-participant-invites/participant-test-fixtures";
const readParticipantPreview = vi.fn();
const readParticipantConfirmation = vi.fn();
const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});
vi.mock("@/features/project-participant-invites/participant-server", () => ({
  readParticipantPreview,
  readParticipantConfirmation,
}));
vi.mock(
  "@/features/project-participant-invites/participant-invite-flow",
  () => ({
    ParticipantInviteFlow: ({ initialRead }: { initialRead: unknown }) => (
      <div>{JSON.stringify(initialRead)}</div>
    ),
  }),
);
vi.mock(
  "@/features/project-participant-invites/participant-confirmation",
  () => ({
    ParticipantConfirmation: () => <div>Checking current participation</div>,
  }),
);
vi.mock("next/navigation", () => ({ notFound }));
beforeEach(() => vi.clearAllMocks());
describe("participant GET routes", () => {
  it("reads a minimal preview on GET with generic uncached metadata", async () => {
    const route = await import("./join/project/[token]/page");
    readParticipantPreview.mockResolvedValue({ preview });
    const html = renderToStaticMarkup(
      await route.default({
        params: Promise.resolve({ token }),
        searchParams: Promise.resolve({}),
      }),
    );
    expect(readParticipantPreview).toHaveBeenCalledExactlyOnceWith(token);
    expect(html).toContain("Community mural");
    expect(html).not.toContain("issuer");
    expect(route.dynamic).toBe("force-dynamic");
    expect(route.revalidate).toBe(0);
    expect(route.metadata.robots).toMatchObject({
      index: false,
      follow: false,
    });
    expect(JSON.stringify(route.metadata)).not.toContain(token);
  });
  it("does not turn preview failure into canonical unavailable", async () => {
    const route = await import("./join/project/[token]/page");
    readParticipantPreview.mockResolvedValue({ failure: "network" });
    expect(
      renderToStaticMarkup(
        await route.default({
          params: Promise.resolve({ token }),
          searchParams: Promise.resolve({}),
        }),
      ),
    ).toContain("network");
  });
  it.each(["proposals", "tavoli"])(
    "token-free %s confirmation rechecks canonical membership on every GET",
    async (kind) => {
      const route = await import("./joined/[kind]/[id]/page");
      readParticipantConfirmation.mockResolvedValue({
        auth: { account: project.id, phase: "ready" },
        participation: { current: true, creator: false },
      });
      const page = () =>
        route.default({
          params: Promise.resolve({ kind, id: project.id }),
          searchParams: Promise.resolve({}),
        });
      expect(renderToStaticMarkup(await page())).toContain(
        "You currently participate",
      );
      readParticipantConfirmation.mockResolvedValue({
        auth: { account: project.id, phase: "ready" },
        participation: { current: false, creator: false },
      });
      expect(renderToStaticMarkup(await page())).not.toContain(
        "You currently participate",
      );
      expect(readParticipantConfirmation).toHaveBeenCalledTimes(2);
      expect(readParticipantPreview).not.toHaveBeenCalled();
      expect(route.dynamic).toBe("force-dynamic");
    },
  );
  it.each([
    { kind: "admin", id: project.id },
    { kind: "proposals", id: "bad" },
  ])("rejects invalid confirmation route %j", async (params) => {
    const route = await import("./joined/[kind]/[id]/page");
    await expect(
      route.default({
        params: Promise.resolve(params),
        searchParams: Promise.resolve({}),
      }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(readParticipantConfirmation).not.toHaveBeenCalled();
  });
});
