import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import path from "path";
import { fileURLToPath } from "url";

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root,
  plugins: [vue()],
  base: "/",
  build: {
    outDir: path.join(root, "..", "public"),
    emptyOutDir: true,
  },
  server: {
    port: 5173,
    proxy: {
      "/api": "http://127.0.0.1:8787",
      "/health": "http://127.0.0.1:8787",
      "/webhook": "http://127.0.0.1:8787",
    },
  },
});
