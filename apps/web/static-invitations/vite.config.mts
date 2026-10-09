import { fileURLToPath } from "node:url";
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { publicKeys, trialPublicConfig } from "./public-config";

const root = fileURLToPath(new URL("./", import.meta.url));
export default defineConfig(({ mode }) => {
  if (mode !== "trial-local" && mode !== "trial-staging")
    throw new Error("Choose trial-local or trial-staging explicitly.");
  const loaded = loadEnv(mode, root, "NEXT_PUBLIC_");
  const selected = Object.fromEntries(
    Object.entries(loaded).filter(([key]) =>
      publicKeys.includes(key as (typeof publicKeys)[number]),
    ),
  );
  // Unknown public settings fail, instead of silently enabling telemetry or
  // allowing a service credential to enter this separate build boundary.
  const settings = trialPublicConfig(loaded);
  if ((mode === "trial-local") !== (settings.config.appEnv === "local"))
    throw new Error("Static build mode/environment mismatch.");
  return {
    root,
    envPrefix: "STATIC_TRIAL_NEVER_AUTOMATICALLY_EXPOSE_",
    plugins: [
      react(),
      {
        name: "static-runtime-boundary",
        generateBundle(_, bundle) {
          for (const item of Object.values(bundle))
            if (item.type === "chunk")
              for (const id of Object.keys(item.modules)) {
                if (/[/\\](next|vinext|server-only)[/\\]/u.test(id))
                  throw new Error(
                    "Server runtime entered static invitation bundle.",
                  );
              }
        },
      },
    ],
    resolve: {
      alias: { "@": fileURLToPath(new URL("../src/", import.meta.url)) },
    },
    define: {
      STATIC_INVITATION_CONFIG: JSON.stringify(settings),
      ...Object.fromEntries(
        [...publicKeys, "NEXT_PUBLIC_SENTRY_DSN"].map((key) => [
          `process.env.${key}`,
          JSON.stringify(selected[key]) ?? "undefined",
        ]),
      ),
    },
    build: {
      outDir: "../dist/static-invitations",
      emptyOutDir: true,
      sourcemap: false,
    },
  };
});
