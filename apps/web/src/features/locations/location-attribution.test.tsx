import { render, screen } from "@testing-library/react";
import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";
import { LocationAttribution } from "./location-attribution";
it("renders fixed linked readable credits in SSR and the accessible DOM", () => {
  render(<LocationAttribution />);
  expect(
    screen.getByRole("link", { name: "Powered by Geoapify" }),
  ).toHaveAttribute("href", "https://www.geoapify.com/");
  expect(
    screen.getByRole("link", { name: "© OpenStreetMap contributors" }),
  ).toHaveAttribute("href", "https://www.openstreetmap.org/copyright");
  const html = renderToStaticMarkup(<LocationAttribution />);
  expect(html).toContain("noopener noreferrer");
  expect(html).not.toContain("selected_exact");
});
