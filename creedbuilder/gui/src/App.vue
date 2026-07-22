<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import {
  fetchNews,
  fetchPine,
  fetchStatus,
  fetchTokens,
  saveConfig,
  testTrade,
  type NewsItem,
  type SolanaToken,
  type Status,
} from "./api";
import TvChart from "./TvChart.vue";

const status = ref<Status | null>(null);
const tokens = ref<SolanaToken[]>([]);
const news = ref<NewsItem[]>([]);
const selected = ref<SolanaToken | null>(null);
const result = ref("");
const saveMsg = ref("");
const newsError = ref("");
const loading = ref(false);

const form = reactive({
  DRY_RUN: true,
  TOKEN_MINT: "",
  BUY_AMOUNT_LAMPORTS: 10000000,
  SELL_PERCENT: 100,
  SLIPPAGE_BPS: 50,
  SOLANA_RPC_URL: "",
  WEBHOOK_SECRET: "",
});

const dryLabel = computed(() => (status.value?.dryRun ? "DRY RUN" : "LIVE"));
const chartSymbol = computed(() => selected.value?.tvSymbol || "BINANCE:SOLUSDT");
const selectedLabel = computed(() =>
  selected.value ? `${selected.value.symbol} · ${selected.value.name}` : "SOL"
);

function applyStatus(s: Status) {
  status.value = s;
  form.DRY_RUN = s.dryRun;
  form.TOKEN_MINT = s.tokenMint;
  form.BUY_AMOUNT_LAMPORTS = s.buyAmountLamports;
  form.SELL_PERCENT = s.sellPercent;
  form.SLIPPAGE_BPS = s.slippageBps;
  form.SOLANA_RPC_URL = s.rpcUrl;
  form.WEBHOOK_SECRET = s.webhookSecret;

  const match = tokens.value.find((t) => t.mint === s.tokenMint);
  if (match) selected.value = match;
}

async function refresh() {
  loading.value = true;
  try {
    applyStatus(await fetchStatus());
  } catch (err) {
    result.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

async function loadMarket() {
  tokens.value = await fetchTokens();
  if (!selected.value) {
    selected.value = tokens.value.find((t) => t.symbol === "SOL") || tokens.value[0] || null;
  }
  try {
    news.value = await fetchNews();
    newsError.value = "";
  } catch (err) {
    newsError.value = err instanceof Error ? err.message : String(err);
  }
}

async function selectToken(token: SolanaToken) {
  selected.value = token;
  // Native SOL is the spend asset; keep chart but don't set TOKEN_MINT to wrapped SOL for buys.
  if (token.symbol === "SOL") {
    result.value = "Chart set to SOL. Pick a token (JUP, BONK, …) to set Jupiter buy output mint.";
    return;
  }
  form.TOKEN_MINT = token.mint;
  saveMsg.value = `Selected ${token.symbol}…`;
  try {
    const data = await saveConfig({ TOKEN_MINT: token.mint });
    applyStatus(data.status);
    saveMsg.value = `${token.symbol} set as TOKEN_MINT.`;
  } catch (err) {
    saveMsg.value = err instanceof Error ? err.message : String(err);
  }
}

async function copy(text: string, note: string) {
  await navigator.clipboard.writeText(text);
  result.value = note;
}

async function onCopyPine() {
  try {
    const pine = await fetchPine();
    await copy(pine, "Pine script copied. Paste into TradingView Pine Editor.");
  } catch (err) {
    result.value = err instanceof Error ? err.message : String(err);
  }
}

async function onCopyAlert(action: "buy" | "sell") {
  if (!status.value) return;
  const payload = JSON.stringify({
    secret: status.value.webhookSecret,
    action,
  });
  await copy(payload, `Copied ${action} alert JSON:\n${payload}`);
}

async function onTest(action: "buy" | "sell") {
  result.value = `Running ${action}...`;
  try {
    const data = await testTrade(action);
    result.value = JSON.stringify(data, null, 2);
  } catch (err) {
    result.value = err instanceof Error ? err.message : String(err);
  }
}

async function onSave() {
  saveMsg.value = "Saving...";
  try {
    const data = await saveConfig({
      DRY_RUN: form.DRY_RUN,
      TOKEN_MINT: form.TOKEN_MINT.trim(),
      BUY_AMOUNT_LAMPORTS: Number(form.BUY_AMOUNT_LAMPORTS),
      SELL_PERCENT: Number(form.SELL_PERCENT),
      SLIPPAGE_BPS: Number(form.SLIPPAGE_BPS),
      SOLANA_RPC_URL: form.SOLANA_RPC_URL.trim(),
      WEBHOOK_SECRET: form.WEBHOOK_SECRET.trim(),
    });
    applyStatus(data.status);
    saveMsg.value = "Saved.";
    result.value = JSON.stringify(data.status, null, 2);
  } catch (err) {
    saveMsg.value = err instanceof Error ? err.message : String(err);
  }
}

function formatTime(iso: string) {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

onMounted(async () => {
  await loadMarket();
  await refresh();
});
</script>

<template>
  <div class="noise" aria-hidden="true" />

  <header class="top">
    <div>
      <p class="eyebrow">solana · jupiter · news</p>
      <h1>creedBuilder</h1>
    </div>
    <div class="badges">
      <span class="badge" :class="{ live: status && !status.dryRun }">{{ dryLabel }}</span>
      <span class="badge badge-muted">{{ loading ? "loading…" : "bot online" }}</span>
    </div>
  </header>

  <main class="layout">
    <section class="panel wide chart-panel">
      <div class="chart-head">
        <div>
          <h2>Solana chart</h2>
          <p class="hint">TradingView embed · {{ selectedLabel }}</p>
        </div>
      </div>
      <div class="token-row">
        <button
          v-for="token in tokens"
          :key="token.mint"
          type="button"
          class="token-chip"
          :class="{ active: selected?.mint === token.mint }"
          @click="selectToken(token)"
        >
          {{ token.symbol }}
        </button>
      </div>
      <TvChart :symbol="chartSymbol" />
    </section>

    <section class="panel hero-panel">
      <h2>First-time setup</h2>
      <p class="lede">
        Do this once. GUI lives at
        <code>http://127.0.0.1:8787</code>
        while the bot is running.
      </p>
      <ol class="steps">
        <li v-for="(step, i) in status?.guiSteps || []" :key="i">
          <strong>Step {{ i + 1 }}.</strong> {{ step }}
        </li>
      </ol>
      <div class="row wrap">
        <a class="btn ghost" href="https://www.tradingview.com/chart/" target="_blank" rel="noreferrer">
          Open TradingView
        </a>
        <button type="button" class="btn" @click="onCopyPine">Copy Pine script</button>
        <button type="button" class="btn" @click="onCopyAlert('buy')">Copy buy alert JSON</button>
        <button type="button" class="btn" @click="onCopyAlert('sell')">Copy sell alert JSON</button>
      </div>
      <p class="hint">
        Public webhook URL comes from <strong>Start.cmd</strong> (Cloudflare tunnel). Paste into TradingView alerts.
      </p>
    </section>

    <section class="panel">
      <h2>Status & trade</h2>
      <dl v-if="status" class="kv">
        <dt>wallet</dt>
        <dd>{{ status.wallet || status.walletError || "missing" }}</dd>
        <dt>token mint</dt>
        <dd>{{ status.tokenMint }}</dd>
        <dt>buy lamports</dt>
        <dd>{{ status.buyAmountLamports }}</dd>
        <dt>sell %</dt>
        <dd>{{ status.sellPercent }}</dd>
      </dl>
      <div class="row wrap">
        <button type="button" class="btn" @click="refresh">Refresh</button>
        <button type="button" class="btn accent" @click="onTest('buy')">Buy (SOL → token)</button>
        <button type="button" class="btn danger" @click="onTest('sell')">Sell (token → SOL)</button>
      </div>
      <pre v-if="result" class="result">{{ result }}</pre>
    </section>

    <section class="panel wide">
      <h2>Solana news</h2>
      <p v-if="newsError" class="hint">{{ newsError }}</p>
      <div v-else class="news-grid">
        <a
          v-for="item in news"
          :key="item.id"
          class="news-card"
          :href="item.url"
          target="_blank"
          rel="noreferrer"
        >
          <p class="news-meta">{{ item.source }} · {{ formatTime(item.publishedAt) }}</p>
          <h3>{{ item.title }}</h3>
          <p class="news-body">{{ item.body }}</p>
        </a>
      </div>
    </section>

    <section class="panel wide">
      <h2>Trade settings</h2>
      <form class="form-grid" @submit.prevent="onSave">
        <label>
          <span>DRY_RUN</span>
          <select v-model="form.DRY_RUN">
            <option :value="true">true (quotes only, safe)</option>
            <option :value="false">false (live Jupiter swaps)</option>
          </select>
        </label>
        <label>
          <span>TOKEN_MINT</span>
          <input v-model="form.TOKEN_MINT" spellcheck="false" />
        </label>
        <label>
          <span>BUY_AMOUNT_LAMPORTS</span>
          <input v-model.number="form.BUY_AMOUNT_LAMPORTS" type="number" min="1" step="1" />
        </label>
        <label>
          <span>SELL_PERCENT</span>
          <input v-model.number="form.SELL_PERCENT" type="number" min="1" max="100" step="1" />
        </label>
        <label>
          <span>SLIPPAGE_BPS</span>
          <input v-model.number="form.SLIPPAGE_BPS" type="number" min="1" step="1" />
        </label>
        <label>
          <span>SOLANA_RPC_URL</span>
          <input v-model="form.SOLANA_RPC_URL" spellcheck="false" />
        </label>
        <label class="full">
          <span>WEBHOOK_SECRET</span>
          <input v-model="form.WEBHOOK_SECRET" spellcheck="false" />
        </label>
        <div class="full row wrap">
          <button type="submit" class="btn accent">Save settings</button>
          <p class="hint">{{ saveMsg }}</p>
        </div>
      </form>
    </section>
  </main>

  <footer class="foot">
    <p>Educational software. Charts via TradingView. News via CryptoCompare (Solana-filtered).</p>
  </footer>
</template>
