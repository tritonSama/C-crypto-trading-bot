import { Router } from "express";
import { z } from "zod";
import { config } from "./config.js";
import { runTrade } from "./jupiter.js";

const payloadSchema = z.object({
  secret: z.string().min(1),
  action: z.enum(["buy", "sell", "BUY", "SELL"]).transform((a) => a.toLowerCase() as "buy" | "sell"),
});

let busy = false;

export function webhookRouter(): Router {
  const router = Router();

  router.get("/health", (_req, res) => {
    res.json({
      ok: true,
      dryRun: config.DRY_RUN,
      tokenMint: config.TOKEN_MINT,
    });
  });

  router.post("/webhook", async (req, res) => {
    try {
      const body =
        typeof req.body === "string"
          ? JSON.parse(req.body)
          : req.body;

      const parsed = payloadSchema.safeParse(body);
      if (!parsed.success) {
        res.status(400).json({ error: "Invalid payload", details: parsed.error.flatten() });
        return;
      }

      if (parsed.data.secret !== config.WEBHOOK_SECRET) {
        res.status(401).json({ error: "Unauthorized" });
        return;
      }

      if (busy) {
        res.status(429).json({ error: "Trade already in progress" });
        return;
      }

      busy = true;
      try {
        const result = await runTrade(parsed.data.action);
        res.json({
          ok: true,
          action: parsed.data.action,
          dryRun: result.dryRun,
          inAmount: result.quote.inAmount,
          outAmount: result.quote.outAmount,
          signature: result.signature ?? null,
        });
      } finally {
        busy = false;
      }
    } catch (err) {
      busy = false;
      const message = err instanceof Error ? err.message : String(err);
      console.error("[webhook]", message);
      res.status(500).json({ error: message });
    }
  });

  return router;
}
