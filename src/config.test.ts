import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

// Set required env vars before importing config
process.env.WEBHOOK_SECRET = "test-secret-1234";
process.env.SOL_MINT = "So11111111111111111111111111111111111111112";
process.env.TOKEN_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
process.env.BUY_AMOUNT_LAMPORTS = "10000";
process.env.SOLANA_RPC_URL = "http://localhost:8899";

describe("Configuration", () => {
  it("should load configuration correctly", async () => {
    const { config } = await import("./config.js");
    expect(config.WEBHOOK_SECRET).toBe("test-secret-1234");
    expect(config.SOL_MINT).toBe("So11111111111111111111111111111111111111112");
    expect(config.PORT).toBe(8787); // default
  });
});
