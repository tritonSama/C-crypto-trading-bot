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
   - Built with Express.js (`creedbuilder/src/index.ts`).
   - Handles incoming POST webhook requests from TradingView.
   - Hosts API endpoints for the Vue.js GUI.
   - Interacts with the Solana blockchain via `@solana/web3.js` and Jupiter's Swap API (`creedbuilder/src/jupiter.ts`).
   - Uses `zod` for payload validation.

3. **Vue 3 + Vite GUI (Frontend):**
   - Located in `creedbuilder/gui/`.
   - Provides a user interface (at `http://127.0.0.1:8787`) to manage configurations (saved in `.env`), view current status, generate wallets, test trades (Dry Run mode), and copy TradingView webhook parameters.

4. **Cloudflared Tunnel:**
   - Started via `Start.cmd` / `start.sh`.
   - Exposes the local Node.js server securely to the internet, giving TradingView a public URL to POST alerts to.

5. **Legacy C# Application (Technical Debt):**
   - The root repository contains numerous C# files (e.g., `Program.cs`, `Coin.cs`, `Global.cs`, `Util.cs`, `Quote/`, `Setup/`, `Study/`, `Trade/`, `Workers/`).
   - These files reference Coinbase Pro and MongoDB (`MongoDB_Schema/`) and appear to belong to an older version or entirely different concept (e.g., a Coinbase Pro C# bot).
   - This legacy code is **not** actively used by the current TypeScript/Solana implementation.

## Application Flow

1. User starts the app (`Start.cmd` / `start.sh`), which boots the Node server on port 8787 and opens a Cloudflare tunnel.
2. The user configures settings (Token mint, Buy Amount, Slippage, Dry Run state) via the Vue GUI.
3. TradingView triggers a Buy or Sell alert based on the Pine Script indicator.
4. TradingView POSTs a JSON payload (containing an `action` and a `secret`) to the Cloudflare public URL.
5. The Cloudflare tunnel routes the request to the local Node.js webhook endpoint (`/webhook`).
6. The Node server validates the secret.
7. If `DRY_RUN` is false, it requests a quote from Jupiter API and signs/sends a transaction on the Solana network. If `DRY_RUN` is true, it merely simulates the request.
8. The server responds to the webhook with the transaction signature (or simulation result).

## API Endpoints

The Express server exposes the following key endpoints:

### Webhook API (`creedbuilder/src/webhook.ts`)

- **GET `/health`**: Returns basic status (dryRun state, tokenMint).
- **GET `/webhook`**: Informs users that this endpoint requires a POST with JSON (used mostly as a manual health check).
- **POST `/webhook`**:
  - **Payload:** `{ "secret": "<WEBHOOK_SECRET>", "action": "buy" | "sell" }`
  - Validates the secret against the `.env` configuration.
  - Executes a trade (via `runTrade` in `jupiter.ts`).
  - Returns the transaction result (amounts, signature, dryRun status).

### GUI API (`creedbuilder/src/gui-api.ts`)

These are consumed by the Vue.js frontend:

- **GET `/api/status`**: Returns a comprehensive state of the app (wallet pubkey, current config, setup status, local URLs).
- **GET `/api/tokens`**: Returns a curated list of Solana tokens from `solana-data.ts`.
- **GET `/api/news`**: Scrapes and returns recent Solana news items.
- **GET `/api/pine`**: Returns the content of the `pine/CreedBuilderSignal.pine` file for easy copying.
- **GET `/api/config`**: Returns the current application configuration.
- **POST `/api/config`**: Updates the application configuration, rewriting the `.env` file and updating runtime process env vars.
- **POST `/api/test-trade`**: Manually triggers a buy or sell trade for testing purposes from the GUI.

## Next Steps & Recommendations

The application works as a proof of concept, but several improvements should be made for stability and scalability:

### 1. Technical Debt Cleanup (Crucial)
- **Remove Legacy C# Code:** The root folder contains a significant amount of C# code (`*.cs` files, `MongoDB_Schema`, Coinbase references) that is entirely disconnected from the active Node.js Solana bot. This should be deleted to prevent confusion.
- **Consolidate Structure:** Move the active application out of the nested `creedbuilder/` subdirectory into the root folder to simplify the project structure.

### 2. Testing and CI/CD
- **Add Tests:** Implement automated tests (e.g., using Jest or Vitest) for the webhook routing, payload validation, and Jupiter API integration mocks.
- **CI Pipelines:** Add GitHub Actions to automatically run builds and linters on pull requests.

### 3. Feature Additions
- **Database Integration:** Move from `.env` file configuration (which gets mutated by the GUI) to a lightweight local database (like SQLite or a JSON document store like lowdb) to store trade history, logs, and configurations safely.
- **Multi-Token Support:** The current implementation seems geared towards a single selected token at a time. Expanding it to handle an array of tokens mapped to different TradingView alerts would be powerful.
- **Advanced Strategy Config:** Add UI controls for dynamic stop-loss, take-profit, or trailing stops.

### 4. Infrastructure & Deployment
- **Dockerization:** Provide a `Dockerfile` and `docker-compose.yml` to run the bot, GUI, and Cloudflared tunnel seamlessly in isolated containers, replacing the platform-specific `.cmd` and `.sh` scripts.
- **WebSocket/RPC Resilience:** Implement connection retries and fallback RPC URLs for the Solana connection to handle network congestion.
