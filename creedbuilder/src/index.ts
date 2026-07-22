import express from "express";
import { config } from "./config.js";
import { webhookRouter } from "./webhook.js";
import { loadKeypair } from "./jupiter.js";

const app = express();
app.use(express.json({ type: ["application/json", "text/plain"] }));
app.use(webhookRouter());

try {
  const wallet = loadKeypair();
  console.log(`[creedBuilder] wallet ${wallet.publicKey.toBase58()}`);
} catch (err) {
  console.warn(`[creedBuilder] wallet not ready: ${err instanceof Error ? err.message : err}`);
}

console.log(`[creedBuilder] DRY_RUN=${config.DRY_RUN}`);
console.log(`[creedBuilder] listening on http://127.0.0.1:${config.PORT}`);
console.log(`[creedBuilder] webhook POST /webhook  health GET /health`);

app.listen(config.PORT, "127.0.0.1");
