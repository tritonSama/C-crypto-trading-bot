# creedBuilder

Automated **Solana** trading driven by **TradingView Pine Script** alerts, executed through **[Jupiter](https://jup.ag)**, with a local **Vue** control GUI.

> Educational proof of concept only. You can lose money. You own your keys, funds, and alerts.

## First-time setup (Windows)

### 1. Clone

```powershell
git clone https://github.com/tritonSama/creedBuilder.git
cd creedBuilder
```

### 2. Install (once)

```powershell
.\Install.cmd
```

This installs Node.js (if needed), cloudflared, npm packages, builds the **server + Vue GUI**, and creates `creedbuilder/.env` with a wallet (`DRY_RUN=true`).

### 3. Start

```powershell
.\Start.cmd
```

This starts:

- the webhook bot  
- a Cloudflare tunnel (public HTTPS URL for TradingView)  
- the **Vue GUI** in your browser at [http://127.0.0.1:8787](http://127.0.0.1:8787)

### 4. Finish setup in the GUI

In the Vue app:

1. Confirm your **wallet** address (fund with SOL only when you go live)  
2. Click **Copy Pine script** → paste into [TradingView](https://www.tradingview.com/chart/) Pine Editor → Add to chart  
3. Copy the **public webhook URL** from the `Start.cmd` window (ends with `/webhook`) into TradingView alert webhooks  
4. Use **Copy buy/sell alert JSON** for the alert message body  
5. Click **Test buy quote** / **Test sell quote** while `DRY_RUN=true`  
6. Edit trade settings (mint, size, slippage) and **Save**

### 5. Go live (careful)

1. Fund the wallet shown in the GUI  
2. Set `DRY_RUN` to `false` in the GUI and Save  
3. Restart with `.\Start.cmd` if needed  

---

## First-time setup (macOS / Linux)

```bash
git clone https://github.com/tritonSama/creedBuilder.git
cd creedBuilder
chmod +x install.sh start.sh
./install.sh
./start.sh
```

Then open [http://127.0.0.1:8787](http://127.0.0.1:8787) and follow the same GUI steps.

## What talks to what

```
TradingView (Pine alerts)
        │  POST /webhook
        ▼
creedBuilder (Node + Vue GUI on :8787)
        │
        ▼
   Jupiter Swap API → Solana
```

| Path | Role |
| --- | --- |
| `creedbuilder/gui/` | Vue 3 + Vite source |
| `creedbuilder/public/` | Built GUI (from `npm run build`) |
| `pine/CreedBuilderSignal.pine` | TradingView indicator |
| `Install.cmd` / `install.sh` | One-shot setup |
| `Start.cmd` / `start.sh` | Bot + tunnel + GUI |

## Dev (optional)

```powershell
cd creedbuilder
npm run build:server
npm run dev          # API on :8787
npm run dev:gui      # Vite GUI on :5173 (proxies /api)
```

## Requirements

- Windows 10/11 with [Git](https://git-scm.com/download/win) + [winget](https://learn.microsoft.com/windows/package-manager/winget/), or macOS/Linux with Node 20+  
- TradingView account (for alerts)  
- SOL in the bot wallet only when leaving dry-run
