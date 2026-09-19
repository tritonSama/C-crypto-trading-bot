import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { db, getConfigValue, setConfigValue, logTrade } from "./db.js";

describe("Database", () => {
  beforeEach(() => {
    // Clear tables before each test
    db.prepare("DELETE FROM config").run();
    db.prepare("DELETE FROM trade_logs").run();
  });

  it("should set and get config values", () => {
    setConfigValue("TEST_KEY", "test_value");
    const val = getConfigValue("TEST_KEY");
    expect(val).toBe("test_value");
  });

  it("should handle missing config values", () => {
    const val = getConfigValue("NONEXISTENT");
    expect(val).toBeNull();
  });

  it("should log trades correctly", () => {
    logTrade("buy", true, "100", "200", undefined, undefined);
    const row = db.prepare("SELECT * FROM trade_logs ORDER BY id DESC LIMIT 1").get() as any;
    expect(row).toBeDefined();
    expect(row.action).toBe("buy");
    expect(row.dry_run).toBe(1);
    expect(row.in_amount).toBe("100");
    expect(row.out_amount).toBe("200");
    expect(row.error).toBeNull();
  });
});
