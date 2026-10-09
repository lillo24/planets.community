import { defineConfig } from "vite";
import vinext from "vinext";
import { cloudflare } from "@cloudflare/vite-plugin";

// Separate beta-runtime trial; next dev/build/start remain the Node fallback.
export default defineConfig({
  plugins: [
    vinext(),
    cloudflare({
      configPath: "./wrangler.staging.jsonc",
      viteEnvironment: { name: "rsc", childEnvironments: ["ssr"] },
    }),
  ],
});
