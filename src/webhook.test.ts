import { describe, it, expect, vi, beforeEach } from "vitest";
import express from "express";

// Set required env vars before importing anything that imports config
process.env.WEBHOOK_SECRET = "test-secret-1234";
process.env.SOL_MINT = "So11111111111111111111111111111111111111112";
process.env.TOKEN_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
process.env.BUY_AMOUNT_LAMPORTS = "10000";
process.env.SOLANA_RPC_URL = "http://localhost:8899";

import { webhookRouter } from "./webhook.js";
import { config } from "./config.js";
import * as jupiter from "./jupiter.js";
import * as db from "./db.js";
import request from "supertest";

vi.mock("./jupiter.js", () => ({
  runTrade: vi.fn(),
}));

vi.mock("./db.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("./db.js")>();
  return {
    ...actual,
    logTrade: vi.fn(),
  };
});

describe("Webhook Router", () => {
  let app: express.Application;

  beforeEach(() => {
    vi.clearAllMocks();
    app = express();
    app.use(express.json());
    app.use(webhookRouter());
  });

  it("should return health status", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it("should reject invalid secrets", async () => {
    const res = await request(app)
      .post("/webhook")
      .send({ secret: "wrong-secret", action: "buy" });

    // Assuming config.WEBHOOK_SECRET is not "wrong-secret"
    if (config.WEBHOOK_SECRET !== "wrong-secret") {
       expect(res.status).toBe(401);
       expect(res.body.error).toBe("Unauthorized");
    }
  });

  it("should reject invalid actions", async () => {
    const res = await request(app)
      .post("/webhook")
      .send({ secret: config.WEBHOOK_SECRET, action: "hold" });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Invalid payload");
  });

  it("should process a valid buy alert", async () => {
    const mockQuote = { inAmount: "10", outAmount: "20" };
    vi.mocked(jupiter.runTrade).mockResolvedValue({
      dryRun: true,
      quote: mockQuote as any,
    });

    const res = await request(app)
      .post("/webhook")
      .send({ secret: config.WEBHOOK_SECRET, action: "buy" });

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(jupiter.runTrade).toHaveBeenCalledWith("buy", undefined);
    expect(db.logTrade).toHaveBeenCalled();
  });

  it("should process a valid multi-token alert", async () => {
    const mockQuote = { inAmount: "10", outAmount: "20" };
    vi.mocked(jupiter.runTrade).mockResolvedValue({
      dryRun: true,
      quote: mockQuote as any,
    });

    const tokenMint = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
    const res = await request(app)
      .post("/webhook")
      .send({ secret: config.WEBHOOK_SECRET, action: "sell", tokenMint });

    expect(res.status).toBe(200);
    expect(jupiter.runTrade).toHaveBeenCalledWith("sell", tokenMint);
  });
});
