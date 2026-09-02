import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ProfileForm } from "@/features/profile/profile-form";
import type { WebProfileGateway } from "@/features/profile/profile-gateway";
import type { ProfileEditorData } from "@/features/profile/profile-models";

const routerRefresh = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: routerRefresh }),
}));

afterEach(cleanup);

describe("ProfileForm", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders incomplete setup with categorized controlled skills", () => {
    render(<ProfileForm initialData={fixture()} gateway={gateway()} />);

    expect(screen.getByText("Complete your profile")).toBeVisible();
    expect(screen.getByText("Art & Creativity")).toBeVisible();
    expect(screen.getByText("Music")).toBeVisible();
    expect(
      screen.getByRole("checkbox", { name: "Mural painting" }),
    ).toBeVisible();
    expect(screen.getByRole("checkbox", { name: "Musician" })).toBeVisible();
    expect(document.body).not.toHaveTextContent("person@example.com");
  });

  it("validates before saving", () => {
    const profileGateway = gateway();
    render(<ProfileForm initialData={fixture()} gateway={profileGateway} />);

    fireEvent.change(screen.getByRole("textbox", { name: "Display name" }), {
      target: { value: "X" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Save profile" }));

    expect(screen.getByText(/Enter 2 to 60 characters/u)).toBeVisible();
    expect(profileGateway.updateOwnProfile).not.toHaveBeenCalled();
  });

  it("saves selected skills and visibility through the canonical gateway", async () => {
    const profileGateway = gateway();
    const refresh = vi.fn();
    render(
      <ProfileForm
        initialData={fixture()}
        gateway={profileGateway}
        onRefresh={refresh}
      />,
    );
    fireEvent.change(screen.getByRole("textbox", { name: "Display name" }), {
      target: { value: "  Casey  " },
    });
    fireEvent.click(screen.getByRole("checkbox", { name: "Mural painting" }));
    const bioVisibility = screen.getByRole("group", { name: "Bio" });
    fireEvent.click(
      within(bioVisibility).getByRole("button", { name: "Private" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Save profile" }));

    await waitFor(() => {
      expect(profileGateway.updateOwnProfile).toHaveBeenCalledWith({
        expectedProfileId: "user-a",
        displayName: "Casey",
        bio: "",
        selectedSkillIds: ["skill-mural"],
        visibility: {
          display_name: "public",
          bio: "private",
          skills: "public",
        },
      });
      expect(refresh).toHaveBeenCalledOnce();
    });
    expect(screen.getByText("Profile saved")).toBeVisible();
  });

  it("shows a safe retryable failure without raw backend details", async () => {
    const rawFailure = "private profile database diagnostics";
    const profileGateway = gateway();
    vi.mocked(profileGateway.updateOwnProfile).mockRejectedValueOnce(
      new Error(rawFailure),
    );
    render(<ProfileForm initialData={fixture()} gateway={profileGateway} />);
    fireEvent.change(screen.getByRole("textbox", { name: "Display name" }), {
      target: { value: "Casey" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Save profile" }));

    expect(await screen.findByText("Profile was not saved")).toBeVisible();
    expect(document.body).not.toHaveTextContent(rawFailure);
    expect(screen.getByRole("button", { name: "Save profile" })).toBeEnabled();
  });

  it("keeps a stale form bound to its server-rendered profile identity", async () => {
    const profileGateway = gateway();
    render(<ProfileForm initialData={fixture()} gateway={profileGateway} />);
    fireEvent.change(screen.getByRole("textbox", { name: "Display name" }), {
      target: { value: "Stale user A value" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Save profile" }));

    await waitFor(() => {
      expect(profileGateway.updateOwnProfile).toHaveBeenCalledWith(
        expect.objectContaining({
          expectedProfileId: "user-a",
          displayName: "Stale user A value",
        }),
      );
    });
  });
});

function gateway(): WebProfileGateway {
  return { updateOwnProfile: vi.fn().mockResolvedValue(undefined) };
}

function fixture(): ProfileEditorData {
  return {
    profile: {
      id: "user-a",
      displayName: null,
      bio: null,
      selectedSkillIds: [],
      visibility: {
        display_name: "public",
        bio: "public",
        skills: "public",
      },
    },
    categories: [
      {
        id: "category-art",
        slug: "art-creativity",
        label: "Art & Creativity",
        sortOrder: 1,
        skills: [
          {
            id: "skill-mural",
            categoryId: "category-art",
            slug: "mural-painting",
            label: "Mural painting",
            sortOrder: 1,
          },
        ],
      },
      {
        id: "category-music",
        slug: "music",
        label: "Music",
        sortOrder: 2,
        skills: [
          {
            id: "skill-musician",
            categoryId: "category-music",
            slug: "musician",
            label: "Musician",
            sortOrder: 1,
          },
        ],
      },
    ],
  };
}
