# creedBuilder Documentation

## Overview

creedBuilder is an automated Solana trading bot driven by TradingView Pine Script alerts. It listens for webhook signals from TradingView and executes corresponding trades (buys/sells) on the Solana blockchain using the Jupiter API. It features a local Vue.js GUI for configuration, monitoring, and testing.

> **Disclaimer:** This is an educational proof of concept. You can lose money. You own your keys, funds, and alerts.

## Architecture & Components

The application is composed of several moving parts:

1. **TradingView (Pine Script Indicator):**
   - Located in `pine/CreedBuilderSignal.pine`.
   - Analyzes charts on TradingView and sends JSON alerts via a webhook POST request to the local application.

2. **Node.js Webhook Server & API (Backend):**
   - Built with Express.js (`src/index.ts`).
   - Handles incoming POST webhook requests from TradingView.
   - Hosts API endpoints for the Vue.js GUI.
   - Interacts with the Solana blockchain via `@solana/web3.js` and Jupiter's Swap API (`src/jupiter.ts`).
   - Uses `zod` for payload validation.

3. **Vue 3 + Vite GUI (Frontend):**
   - Located in `gui/`.
   - Provides a user interface (at `http://127.0.0.1:8787`) to manage configurations (saved in `.env`), view current status, generate wallets, test trades (Dry Run mode), and copy TradingView webhook parameters.

4. **Cloudflared Tunnel:**
   - Started via `Start.cmd` / `start.sh`.
   - Exposes the local Node.js server securely to the internet, giving TradingView a public URL to POST alerts to.

## Application Flow

1. User starts the app (`Start.cmd` / `start.sh`), which boots the Node server on port 8787 and opens a Cloudflare tunnel.
2. The user configures settings (Token mint, Buy Amount, Slippage, Dry Run state) via the Vue GUI.
3. TradingView triggers a Buy or Sell alert based on the Pine Script indicator.
4. TradingView POSTs a JSON payload (containing an `action` and a `secret`) to the Cloudflare public URL.
5. The Cloudflare tunnel routes the request to the local Node.js webhook endpoint (`/webhook`).
6. The Node server validates the secret.
7. If `DRY_RUN` is false, it requests a quote from Jupiter API and signs/sends a transaction on the Solana network. If `DRY_RUN` is true, it merely simulates the request.
8. The server responds to the webhook with the transaction signature (or simulation result).

## Features

- **Automated Trading:** Jupiter Swap API integration for zero-slippage automated routing.
- **Dry-Run Mode:** Test alert payloads and view simulated swap amounts without spending real funds.
- **Dockerization:** Fully isolated containerized deployment using Docker Compose.
- **Database Integration:** SQLite integration (`better-sqlite3`) to securely store runtime configuration and log all webhook trade history.
- **Multi-Token Support:** Trade dozens of tokens from the same bot by overriding the target mint directly inside the TradingView alert JSON payload.
- **Automated Testing:** Core logic components are unit tested via Vitest with GitHub Actions CI support.

## API Endpoints

The Express server exposes the following key endpoints:

### Webhook API (`src/webhook.ts`)

- **GET `/health`**: Returns basic status (dryRun state, tokenMint).
- **GET `/webhook`**: Informs users that this endpoint requires a POST with JSON (used mostly as a manual health check).
- **POST `/webhook`**:
  - **Payload:** `{ "secret": "<WEBHOOK_SECRET>", "action": "buy" | "sell" }`
  - Validates the secret against the `.env` configuration.
  - Executes a trade (via `runTrade` in `jupiter.ts`).
  - Returns the transaction result (amounts, signature, dryRun status).

### GUI API (`src/gui-api.ts`)

These are consumed by the Vue.js frontend:

- **GET `/api/status`**: Returns a comprehensive state of the app (wallet pubkey, current config, setup status, local URLs).
- **GET `/api/tokens`**: Returns a curated list of Solana tokens from `solana-data.ts`.
- **GET `/api/news`**: Scrapes and returns recent Solana news items.
- **GET `/api/pine`**: Returns the content of the `pine/CreedBuilderSignal.pine` file for easy copying.
- **GET `/api/config`**: Returns the current application configuration.
- **POST `/api/config`**: Updates the application configuration, rewriting the `.env` file and updating runtime process env vars.
- **POST `/api/test-trade`**: Manually triggers a buy or sell trade for testing purposes from the GUI.

## Next Steps & Recommendations

The application has a robust core, but the following improvements could enhance its capabilities:

### 1. Advanced Trading Features
- **Advanced Strategy Config:** Add UI controls and logic for dynamic stop-loss, take-profit, or trailing stops, possibly utilizing Jupiter Limit Orders instead of market swaps.
- **WebSocket/RPC Resilience:** Implement connection retries and fallback RPC URLs for the Solana connection to handle network congestion.

### 2. Notifications
- **Discord/Telegram Alerts:** Send a message to a Discord webhook or a Telegram bot whenever a trade successfully executes or encounters an error.

## Docker Deployment
The application is fully Dockerized. To run the bot and the Cloudflared tunnel using Docker Compose, run:
```bash
docker compose up -d
```
Check the `cloudflared` container logs to find your public `.trycloudflare.com` URL:
```bash
docker compose logs cloudflared
```
