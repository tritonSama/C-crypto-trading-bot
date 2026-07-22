import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { Router } from "express";
import { z } from "zod";
import { config } from "./config.js";
import { loadKeypair, runTrade } from "./jupiter.js";
import { fetchSolanaNews, SOLANA_TOKENS } from "./solana-data.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const botRoot = path.join(__dirname, "..");
const envPath = path.join(botRoot, ".env");
const pinePath = path.join(botRoot, "..", "pine", "CreedBuilderSignal.pine");

const editableSchema = z.object({
  DRY_RUN: z.boolean().optional(),
  TOKEN_MINT: z.string().min(32).optional(),
  BUY_AMOUNT_LAMPORTS: z.number().int().positive().optional(),
  SELL_PERCENT: z.number().min(1).max(100).optional(),
  SLIPPAGE_BPS: z.number().int().positive().optional(),
  SOLANA_RPC_URL: z.string().url().optional(),
  JUPITER_API_KEY: z.string().optional(),
  WEBHOOK_SECRET: z.string().min(8).optional(),
});

function setEnvValue(content: string, key: string, value: string): string {
  const line = `${key}=${value}`;
  if (new RegExp(`^${key}=`, "m").test(content)) {
    return content.replace(new RegExp(`^${key}=.*$`, "m"), line);
  }
  return `${content.trimEnd()}\n${line}\n`;
}

function applyRuntime(updates: Record<string, string | number | boolean>) {
  const runtime = config as unknown as Record<string, unknown>;
  for (const [key, value] of Object.entries(updates)) {
    process.env[key] = String(value);
    runtime[key] = value;
  }
}

function publicStatus() {
  let wallet: string | null = null;
  let walletError: string | null = null;
  try {
    wallet = loadKeypair().publicKey.toBase58();
  } catch (err) {
    walletError = err instanceof Error ? err.message : String(err);
  }

  const setupComplete = Boolean(wallet) && Boolean(config.WEBHOOK_SECRET) && config.WEBHOOK_SECRET !== "change-me";

  return {
    service: "creedBuilder",
    port: config.PORT,
    dryRun: config.DRY_RUN,
    wallet,
    walletError,
    setupComplete,
    tokenMint: config.TOKEN_MINT,
    solMint: config.SOL_MINT,
    buyAmountLamports: config.BUY_AMOUNT_LAMPORTS,
    sellPercent: config.SELL_PERCENT,
    slippageBps: config.SLIPPAGE_BPS,
    rpcUrl: config.SOLANA_RPC_URL,
    hasJupiterKey: Boolean(config.JUPITER_API_KEY),
    webhookSecret: config.WEBHOOK_SECRET,
    localWebhook: `http://127.0.0.1:${config.PORT}/webhook`,
    localGui: `http://127.0.0.1:${config.PORT}/`,
    guiSteps: [
      "Run Install.cmd once (wallet + dependencies).",
      "Run Start.cmd (bot + Cloudflare tunnel + this GUI).",
      "Copy the public webhook URL from the Start.cmd window into TradingView.",
      "Paste pine/CreedBuilderSignal.pine into TradingView and create Buy/Sell alerts.",
      "Keep DRY_RUN=true until a test quote looks right, then go live.",
    ],
  };
}

export function guiApiRouter(): Router {
  const router = Router();

  router.get("/api/status", (_req, res) => {
    res.json(publicStatus());
  });

  router.get("/api/tokens", (_req, res) => {
    res.json({ tokens: SOLANA_TOKENS });
  });

  router.get("/api/news", async (_req, res) => {
    try {
      const items = await fetchSolanaNews();
      res.json({ items });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(502).json({ error: message, items: [] });
    }
  });

  router.get("/api/pine", (_req, res) => {
    if (!fs.existsSync(pinePath)) {
      res.status(404).json({ error: "Pine file not found" });
      return;
    }
    res.type("text/plain").send(fs.readFileSync(pinePath, "utf8"));
  });

  router.get("/api/config", (_req, res) => {
    res.json({
      DRY_RUN: config.DRY_RUN,
      TOKEN_MINT: config.TOKEN_MINT,
      BUY_AMOUNT_LAMPORTS: config.BUY_AMOUNT_LAMPORTS,
      SELL_PERCENT: config.SELL_PERCENT,
      SLIPPAGE_BPS: config.SLIPPAGE_BPS,
      SOLANA_RPC_URL: config.SOLANA_RPC_URL,
      JUPITER_API_KEY: config.JUPITER_API_KEY ? "(set)" : "",
      WEBHOOK_SECRET: config.WEBHOOK_SECRET,
    });
  });

  router.post("/api/config", (req, res) => {
    const parsed = editableSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid config", details: parsed.error.flatten() });
      return;
    }

    let envText = fs.existsSync(envPath) ? fs.readFileSync(envPath, "utf8") : "";
    const runtime: Record<string, string | number | boolean> = {};

    for (const [key, value] of Object.entries(parsed.data)) {
      if (value === undefined) continue;
      if (key === "JUPITER_API_KEY" && value === "(set)") continue;
      envText = setEnvValue(envText, key, String(value));
      runtime[key] = value as string | number | boolean;
    }

    fs.writeFileSync(envPath, envText, "utf8");
    applyRuntime(runtime);
    res.json({ ok: true, status: publicStatus() });
  });

  router.post("/api/test-trade", async (req, res) => {
    const action = String(req.body?.action || "").toLowerCase();
    if (action !== "buy" && action !== "sell") {
      res.status(400).json({ error: 'action must be "buy" or "sell"' });
      return;
    }
    try {
      const result = await runTrade(action);
      res.json({
        ok: true,
        action,
        dryRun: result.dryRun,
        inAmount: result.quote.inAmount,
        outAmount: result.quote.outAmount,
        signature: result.signature ?? null,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: message });
    }
  });

  return router;
}
