import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { renderPolicy } from "./src/policies/render";
import { policyLinks } from "./src/policies/metadata";

export default defineConfig({
  plugins: [
    react(),
    {
      name: "planets-policy-html",
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          const path = req.url?.split("?")[0];
          if (!policyLinks.some(([, href]) => href === path)) return next();
          res.setHeader("Content-Type", "text/html; charset=utf-8");
          res.end(renderPolicy(path!));
        });
      },
      generateBundle() {
        for (const [, path] of policyLinks) {
          this.emitFile({
            type: "asset",
            fileName: `${path.slice(1)}.html`,
            source: renderPolicy(path),
          });
        }
      },
    },
  ],
  build: {
    outDir: "dist",
  },
});
