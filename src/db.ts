import Database from "better-sqlite3";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, "..", "creedbuilder.db");

export const db = new Database(process.env.NODE_ENV === "test" ? ":memory:" : dbPath);
db.pragma("journal_mode = WAL");

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS trade_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL,
    dry_run BOOLEAN NOT NULL,
    in_amount TEXT,
    out_amount TEXT,
    signature TEXT,
    error TEXT
  );
`);

export function getConfigValue(key: string): string | null {
  const row = db.prepare("SELECT value FROM config WHERE key = ?").get(key) as { value: string } | undefined;
  return row ? row.value : null;
}

export function setConfigValue(key: string, value: string) {
  db.prepare("INSERT INTO config (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").run(key, value);
}

export function logTrade(action: string, dryRun: boolean, inAmount?: string, outAmount?: string, signature?: string, error?: string) {
  db.prepare(`
    INSERT INTO trade_logs (action, dry_run, in_amount, out_amount, signature, error)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    action,
    dryRun ? 1 : 0,
    inAmount ?? null,
    outAmount ?? null,
    signature ?? null,
    error ?? null
  );
}

export function getTradeLogs(limit: number = 50) {
  return db.prepare("SELECT * FROM trade_logs ORDER BY timestamp DESC LIMIT ?").all(limit);
}
