import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import { exec } from "child_process";
import { config } from "./config.js";
import { webhookRouter } from "./webhook.js";
import { guiApiRouter } from "./gui-api.js";
import { loadKeypair } from "./jupiter.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "..", "public");

const app = express();
app.use(express.json({ type: ["application/json", "text/plain"] }));
app.use(guiApiRouter());
app.use(webhookRouter());
app.use(express.static(publicDir));

app.use((req, res, next) => {
  if (req.method !== "GET" && req.method !== "HEAD") return next();
  if (
    req.path.startsWith("/api") ||
    req.path.startsWith("/webhook") ||
    req.path.startsWith("/health")
  ) {
    return next();
  }
  res.sendFile(path.join(publicDir, "index.html"), (err) => {
    if (err) next(err);
  });
});
try {
  const wallet = loadKeypair();
  console.log(`[creedBuilder] wallet ${wallet.publicKey.toBase58()}`);
} catch (err) {
  console.warn(`[creedBuilder] wallet not ready: ${err instanceof Error ? err.message : err}`);
}

const guiUrl = `http://127.0.0.1:${config.PORT}/`;
console.log(`[creedBuilder] DRY_RUN=${config.DRY_RUN}`);
console.log(`[creedBuilder] GUI ${guiUrl}`);
console.log(`[creedBuilder] webhook POST /webhook`);

app.listen(config.PORT, "127.0.0.1", () => {
  if (process.env.OPEN_GUI !== "false") {
    const cmd =
      process.platform === "win32"
        ? `start "" "${guiUrl}"`
        : process.platform === "darwin"
          ? `open "${guiUrl}"`
          : `xdg-open "${guiUrl}"`;
    exec(cmd, () => undefined);
  }
});
