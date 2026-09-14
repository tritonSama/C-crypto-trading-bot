import "dotenv/config";
import { z } from "zod";

const boolFromEnv = z
  .string()
  .optional()
  .transform((v) => (v ?? "true").toLowerCase() !== "false" && (v ?? "true") !== "0");

const schema = z.object({
  PORT: z.coerce.number().default(8787),
  WEBHOOK_SECRET: z.string().min(8),
  DRY_RUN: boolFromEnv,
  SOLANA_RPC_URL: z.string().url(),
  SOLANA_PRIVATE_KEY: z.string().optional().default(""),
  JUPITER_API_KEY: z.string().optional().default(""),
  SOL_MINT: z.string().min(32),
  TOKEN_MINT: z.string().min(32),
  BUY_AMOUNT_LAMPORTS: z.coerce.number().int().positive(),
  SELL_PERCENT: z.coerce.number().min(1).max(100).default(100),
  SLIPPAGE_BPS: z.coerce.number().int().positive().default(50),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid configuration:", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;

export function jupiterBaseUrl(): string {
  return config.JUPITER_API_KEY
    ? "https://api.jup.ag/swap/v1"
    : "https://lite-api.jup.ag/swap/v1";
}

export function jupiterHeaders(): Record<string, string> {
  const headers: Record<string, string> = { Accept: "application/json" };
  if (config.JUPITER_API_KEY) {
    headers["x-api-key"] = config.JUPITER_API_KEY;
  }
  return headers;
}
