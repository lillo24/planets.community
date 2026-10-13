export type ProjectGroupAttribution =
  | Readonly<{ state: "unavailable" }>
  | Readonly<{
      state: "group";
      groupId: string;
      name: string;
      kind: "informal" | "organization";
    }>;
export type GroupProject = Readonly<{
  id: string;
  title: string;
  summary: string;
  kind: "one_time" | "recurring";
  idea: boolean;
  publishedAt: string;
}>;
export function parseAttributions(
  value: unknown,
): Map<string, ProjectGroupAttribution> {
  if (!Array.isArray(value) || value.length > 50)
    throw new TypeError("Invalid attribution batch.");
  const result = new Map<string, ProjectGroupAttribution>();
  for (const row of value) {
    if (!row || typeof row.project_id !== "string")
      throw new TypeError("Invalid attribution identity.");
    if (row.state === "unavailable" && Object.keys(row).length === 2) {
      result.set(row.project_id, { state: "unavailable" });
    } else if (
      row.state === "group" &&
      typeof row.group_id === "string" &&
      typeof row.name === "string" &&
      ["informal", "organization"].includes(row.group_kind)
    ) {
      result.set(row.project_id, {
        state: "group",
        groupId: row.group_id,
        name: row.name,
        kind: row.group_kind,
      });
    } else throw new TypeError("Invalid public attribution projection.");
  }
  return result;
}
export function parseGroupProjects(value: unknown): GroupProject[] {
  if (!Array.isArray(value) || value.length > 20)
    throw new TypeError("Invalid group Project page.");
  return value.map((row) => {
    if (
      !row ||
      typeof row.project_id !== "string" ||
      typeof row.title !== "string" ||
      typeof row.summary !== "string" ||
      !["one_time", "recurring"].includes(row.project_kind) ||
      typeof row.published_at !== "string" ||
      !Number.isFinite(Date.parse(row.published_at))
    )
      throw new TypeError("Invalid group Project projection.");
    return {
      id: row.project_id,
      title: row.title,
      summary: row.summary,
      kind: row.project_kind,
      idea: row.definition_phase === "idea",
      publishedAt: row.published_at,
    };
  });
}
