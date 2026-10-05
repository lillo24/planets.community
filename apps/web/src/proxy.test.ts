import { NextRequest } from "next/server";
import { expect, it, vi } from "vitest";
const update = vi.hoisted(() => vi.fn());
vi.mock("@/features/auth/update-session", () => ({
  updateSupabaseSession: update,
}));
import { proxy } from "./proxy";

it("serves verification resources without session refresh even with a cookie", async () => {
  for (const path of [
    "/.well-known/assetlinks.json",
    "/.well-known/apple-app-site-association",
  ]) {
    const response = await proxy(
      new NextRequest(`https://planets.community${path}`, {
        headers: { Cookie: "synthetic=session" },
      }),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("x-middleware-next")).toBe("1");
    expect(response.headers.has("set-cookie")).toBe(false);
  }
  expect(update).not.toHaveBeenCalled();
});

it("retains the existing session owner for product and auth traffic", async () => {
  const request = new NextRequest("https://planets.community/auth");
  update.mockResolvedValueOnce(new Response(null, { status: 204 }));
  expect((await proxy(request)).status).toBe(204);
  expect(update).toHaveBeenCalledWith(request);
});
