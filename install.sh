#!/usr/bin/env bash
# One-shot install for macOS / Linux (TradingView → Jupiter bot)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT="$ROOT/creedbuilder"
ENV_FILE="$BOT/.env"
ENV_EXAMPLE="$BOT/.env.example"

step() { printf '\n==> %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_node() {
  if need_cmd node; then
    major="$(node -v | sed 's/^v//' | cut -d. -f1)"
    if [[ "$major" -ge 20 ]]; then
      echo "Node.js already OK: $(node -v)"
      return
    fi
  fi
  step "Installing Node.js 20+"
  if need_cmd brew; then
    brew install node@22 || brew install node
  elif need_cmd apt-get; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
  else
    echo "Install Node.js 20+ manually, then re-run ./install.sh" >&2
    exit 1
  fi
}

install_cloudflared() {
  if need_cmd cloudflared; then
    echo "cloudflared already installed"
    return
  fi
  step "Installing cloudflared"
  if need_cmd brew; then
    brew install cloudflare/cloudflare/cloudflared
  elif need_cmd apt-get; then
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
    sudo apt-get update && sudo apt-get install -y cloudflared
  else
    echo "Install cloudflared manually: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" >&2
    exit 1
  fi
}

set_env() {
  local key="$1" value="$2" file="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    # portable-ish in-place replace
    local tmp
    tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v} {print}' "$file" >"$tmp"
    mv "$tmp" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

random_secret() {
  if need_cmd openssl; then
    openssl rand -base64 24 | tr -d '/+=' | cut -c1-32
  else
    head -c 32 /dev/urandom | base64 | tr -d '/+=' | cut -c1-32
  fi
}

echo "creedBuilder installer (TradingView + Jupiter / Solana)"
echo "Repo: $ROOT"

install_node
install_cloudflared

step "npm install + build"
cd "$BOT"
npm install
npm run build

step "Writing .env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
fi

secret="$(grep '^WEBHOOK_SECRET=' "$ENV_FILE" | cut -d= -f2- || true)"
if [[ -z "$secret" || "$secret" == "change-me" ]]; then
  set_env WEBHOOK_SECRET "$(random_secret)" "$ENV_FILE"
fi

key="$(grep '^SOLANA_PRIVATE_KEY=' "$ENV_FILE" | cut -d= -f2- || true)"
pubkey=""
if [[ -z "$key" ]]; then
  step "Generating Solana wallet"
  wallet_json="$(npm run -s gen-wallet)"
  priv="$(printf '%s' "$wallet_json" | sed -n 's/.*"privateKeyBase58":"\([^"]*\)".*/\1/p')"
  pubkey="$(printf '%s' "$wallet_json" | sed -n 's/.*"publicKey":"\([^"]*\)".*/\1/p')"
  set_env SOLANA_PRIVATE_KEY "$priv" "$ENV_FILE"
else
  export K="$key"
  pubkey="$(node --input-type=module -e "import bs58 from 'bs58'; import {Keypair} from '@solana/web3.js'; console.log(Keypair.fromSecretKey(bs58.decode(process.env.K)).publicKey.toBase58())")"
  unset K
fi

set_env DRY_RUN true "$ENV_FILE"
secret="$(grep '^WEBHOOK_SECRET=' "$ENV_FILE" | cut -d= -f2-)"

cat <<EOF

Install complete.

Wallet (fund with SOL for live trades):
  $pubkey

DRY_RUN=true (quotes only). Edit creedbuilder/.env to go live.

Next:
  ./start.sh

TradingView alert messages:
  {"secret":"$secret","action":"buy"}
  {"secret":"$secret","action":"sell"}
EOF
