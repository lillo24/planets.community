const AREA_NAMES = ["mobile", "web", "site", "database"];

const FULL_VALIDATION_PATHS = new Set([
  ".editorconfig",
  ".gitattributes",
  ".gitignore",
  "package.json",
  "scripts/classify-validation-paths.mjs",
  "scripts/lib/validation-paths.mjs",
  "scripts/lib/validation-paths.test.mjs",
]);

const SHARED_NODE_PATHS = new Set([".nvmrc", "package-lock.json"]);

export function classifyValidationPaths(paths, { forceAll = false } = {}) {
  const areas = emptyAreas();

  if (forceAll) {
    markAll(areas);
    return areas;
  }

  for (const rawPath of paths) {
    const path = normalizePath(rawPath);
    if (!path || isDocumentationPath(path)) {
      continue;
    }

    if (FULL_VALIDATION_PATHS.has(path) || path.startsWith(".github/")) {
      markAll(areas);
      continue;
    }

    if (SHARED_NODE_PATHS.has(path)) {
      mark(areas, "web", "site", "database");
      continue;
    }

    if (path === ".prettierignore") {
      mark(areas, "web", "site");
      continue;
    }

    if (path === "apps/web/src/types/database.generated.ts") {
      mark(areas, "web", "database");
      continue;
    }

    if (path.startsWith("apps/mobile/")) {
      mark(areas, "mobile");
      continue;
    }

    if (path.startsWith("apps/web/")) {
      mark(areas, "web");
      continue;
    }

    if (path.startsWith("apps/site/")) {
      mark(areas, "site");
      continue;
    }

    if (path.startsWith("supabase/")) {
      mark(areas, "database");
      continue;
    }

    if (path.startsWith("scripts/lib/")) {
      mark(areas, "mobile", "web", "database");
      continue;
    }

    if (path === "scripts/generate-mobile-local-config.mjs") {
      mark(areas, "mobile");
      continue;
    }

    if (
      path === "scripts/generate-web-local-config.mjs" ||
      path === "scripts/generate-database-types.mjs"
    ) {
      mark(areas, "web", "database");
      continue;
    }

    if (/^scripts\/(?:verify-local-|process-local-).+\.mjs$/.test(path)) {
      mark(areas, "database");
      continue;
    }

    // Unknown source or tooling paths are cross-cutting until explicitly mapped.
    markAll(areas);
  }

  return areas;
}

function emptyAreas() {
  return Object.fromEntries(AREA_NAMES.map((area) => [area, false]));
}

function isDocumentationPath(path) {
  return (
    path.startsWith("docs/") ||
    path.startsWith("history-implementations/") ||
    /\.(?:md|mdx)$/i.test(path)
  );
}

function mark(areas, ...names) {
  for (const name of names) {
    areas[name] = true;
  }
}

function markAll(areas) {
  mark(areas, ...AREA_NAMES);
}

function normalizePath(path) {
  return String(path).replaceAll("\\", "/").replace(/^\.\//, "");
}
