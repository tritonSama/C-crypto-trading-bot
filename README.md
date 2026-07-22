# creedBuilder

Automated **Solana** trading driven by **TradingView Pine Script** alerts, executed through **[Jupiter](https://jup.ag)**.

> Educational proof of concept only. You can lose money. You own your keys, funds, and alert setup.

## Clone & install (Windows)

```powershell
git clone https://github.com/tritonSama/creedBuilder.git
cd creedBuilder
.\Install.cmd
.\Start.cmd
```

That is the full path: clone → install deps/wallet → start bot + public webhook tunnel.

| Step | What it does |
| --- | --- |
| `Install.cmd` | Node.js (if needed), cloudflared, `npm install`, build, creates `creedbuilder/.env` + wallet (`DRY_RUN=true`) |
| `Start.cmd` | Runs the webhook bot and prints a `https://….trycloudflare.com/webhook` URL for TradingView |

**Requirements:** Windows 10/11 with [Git](https://git-scm.com/download/win) and [winget](https://learn.microsoft.com/windows/package-manager/winget/) (App Installer).

## Clone & install (macOS / Linux)

```bash
git clone https://github.com/tritonSama/creedBuilder.git
cd creedBuilder
chmod +x install.sh start.sh
./install.sh
./start.sh
```

## After install → TradingView

1. Paste [`pine/CreedBuilderSignal.pine`](pine/CreedBuilderSignal.pine) into the Pine Editor → Add to chart  
2. Create **Buy** / **Sell** alerts  
3. Webhook URL = URL printed by `Start.cmd` / `./start.sh`  
4. Alert message (secret is in `creedbuilder/.env`):

```json
{"secret":"YOUR_WEBHOOK_SECRET","action":"buy"}
```

```json
{"secret":"YOUR_WEBHOOK_SECRET","action":"sell"}
```

## Go live (careful)

1. Fund the wallet address printed at install (backup `SOLANA_PRIVATE_KEY`)  
2. Edit `creedbuilder/.env` (`TOKEN_MINT`, `BUY_AMOUNT_LAMPORTS`, …)  
3. Set `DRY_RUN=false`  
4. Restart with `Start.cmd` / `./start.sh`

Optional: `JUPITER_API_KEY` for `api.jup.ag` (default uses free `lite-api.jup.ag`).

## Layout

```
TradingView (Pine) → webhook → creedbuilder → Jupiter → Solana
```

| Path | Role |
| --- | --- |
| `pine/CreedBuilderSignal.pine` | Indicator + `alertcondition`s |
| `creedbuilder/` | Webhook server + Jupiter swaps |
| `Install.cmd` / `install.sh` | One-shot setup |
| `Start.cmd` / `start.sh` | Run bot + tunnel |
| Legacy `*.cs` | Old Coinbase Pro C# reference |

## Manual bot commands

```powershell
cd creedbuilder
npm install
npm run build
npm start
```
