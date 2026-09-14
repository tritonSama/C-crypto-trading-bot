#!/usr/bin/env bash
# Start webhook bot + Cloudflare quick tunnel (macOS / Linux)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT="$ROOT/creedbuilder"
ENV_FILE="$BOT/.env"
LOG_DIR="$ROOT/Setup/logs"
mkdir -p "$LOG_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing creedbuilder/.env — run ./install.sh first." >&2
  exit 1
fi

PORT="$(grep '^PORT=' "$ENV_FILE" | cut -d= -f2- || true)"
PORT="${PORT:-8787}"
SECRET="$(grep '^WEBHOOK_SECRET=' "$ENV_FILE" | cut -d= -f2-)"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found — run ./install.sh first." >&2
  exit 1
fi

cleanup() {
  [[ -n "${BOT_PID:-}" ]] && kill "$BOT_PID" 2>/dev/null || true
  [[ -n "${TUNNEL_PID:-}" ]] && kill "$TUNNEL_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Starting creedBuilder on port $PORT ..."
cd "$BOT"
npm run start >"$LOG_DIR/bot.out.log" 2>"$LOG_DIR/bot.err.log" &
BOT_PID=$!
sleep 2
if ! kill -0 "$BOT_PID" 2>/dev/null; then
  cat "$LOG_DIR/bot.err.log" >&2 || true
  echo "Bot failed to start." >&2
  exit 1
fi

echo "Starting Cloudflare quick tunnel ..."
cloudflared tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate \
  >"$LOG_DIR/tunnel.out.log" 2>"$LOG_DIR/tunnel.err.log" &
TUNNEL_PID=$!

PUBLIC_URL=""
for _ in $(seq 1 45); do
  sleep 1
  PUBLIC_URL="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG_DIR/tunnel.err.log" "$LOG_DIR/tunnel.out.log" 2>/dev/null | head -n1 || true)"
  [[ -n "$PUBLIC_URL" ]] && break
done

if [[ -z "$PUBLIC_URL" ]]; then
  echo "Tunnel started but URL not parsed yet. Check $LOG_DIR/tunnel.err.log"
else
  echo
  echo "Health:  ${PUBLIC_URL}/health"
  echo "Webhook: ${PUBLIC_URL}/webhook"
  echo
  echo "TradingView alert messages:"
  echo "{\"secret\":\"${SECRET}\",\"action\":\"buy\"}"
  echo "{\"secret\":\"${SECRET}\",\"action\":\"sell\"}"
  echo
  echo "Press Ctrl+C to stop."
fi

wait "$BOT_PID"
