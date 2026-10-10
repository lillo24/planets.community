import { describe, expect, it } from "vitest";
import { publicExactMapsUrl } from "./public-exact-maps-url";
const item = "fa021000-0000-4000-8000-000000000001";
const preview = {
  item_kind: "one_time",
  item_id: item,
  audience: "public",
  scope: "exact",
  place: {
    kind: "address",
    label: "Synthetic venue",
    latitude: 46.12,
    longitude: 11.17,
  },
};
describe("canonical public exact Maps destination", () => {
  it("uses verified coordinates rather than address text", () => {
    const url = new URL(publicExactMapsUrl(preview, item, "Synthetic venue")!);
    expect(url.searchParams.get("query")).toBe("46.12,11.17");
  });
  it("has no destination when privacy changed, only city remains or label changed", () => {
    expect(publicExactMapsUrl(null, item, "Synthetic venue")).toBeNull();
    expect(
      publicExactMapsUrl({ ...preview, place: null }, item, "Synthetic venue"),
    ).toBeNull();
    expect(
      publicExactMapsUrl(
        { ...preview, scope: "area" },
        item,
        "Synthetic venue",
      ),
    ).toBeNull();
    expect(publicExactMapsUrl(preview, item, "Old venue")).toBeNull();
  });
  it("rejects protected or mismatched identity and invalid geometry", () => {
    expect(() =>
      publicExactMapsUrl(
        { ...preview, audience: "protected" },
        item,
        "Synthetic venue",
      ),
    ).toThrow();
    expect(() =>
      publicExactMapsUrl(
        { ...preview, item_id: "other" },
        item,
        "Synthetic venue",
      ),
    ).toThrow();
    expect(() =>
      publicExactMapsUrl(
        { ...preview, place: { ...preview.place, latitude: 91 } },
        item,
        "Synthetic venue",
      ),
    ).toThrow();
  });
});
