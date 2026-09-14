<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";

const props = defineProps<{
  symbol: string;
}>();

const host = ref<HTMLDivElement | null>(null);
const containerId = `tv_${Math.random().toString(36).slice(2, 10)}`;
let widget: { remove?: () => void } | null = null;

type TvWidgetCtor = new (options: Record<string, unknown>) => { remove?: () => void };

function loadTvScript(): Promise<void> {
  const w = window as Window & { TradingView?: { widget: TvWidgetCtor } };
  if (w.TradingView?.widget) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-tv="1"]');
    if (existing) {
      existing.addEventListener("load", () => resolve());
      existing.addEventListener("error", () => reject(new Error("TradingView script failed")));
      return;
    }
    const script = document.createElement("script");
    script.src = "https://s3.tradingview.com/tv.js";
    script.async = true;
    script.dataset.tv = "1";
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("TradingView script failed"));
    document.head.appendChild(script);
  });
}

async function mountWidget() {
  if (!host.value || !props.symbol) return;
  await loadTvScript();
  await nextTick();
  if (widget?.remove) {
    try {
      widget.remove();
    } catch {
      /* ignore */
    }
  }
  host.value.innerHTML = "";
  const inner = document.createElement("div");
  inner.id = containerId;
  inner.style.height = "100%";
  host.value.appendChild(inner);

  const Tv = (window as Window & { TradingView?: { widget: TvWidgetCtor } }).TradingView;
  if (!Tv?.widget) return;

  widget = new Tv.widget({
    autosize: true,
    symbol: props.symbol,
    interval: "15",
    timezone: "Etc/UTC",
    theme: "dark",
    style: "1",
    locale: "en",
    toolbar_bg: "#0b0b0f",
    enable_publishing: false,
    hide_side_toolbar: false,
    allow_symbol_change: true,
    container_id: containerId,
    backgroundColor: "#0b0b0f",
    gridColor: "rgba(153, 69, 255, 0.12)",
  });
}

onMounted(() => {
  mountWidget().catch(() => undefined);
});

watch(
  () => props.symbol,
  () => {
    mountWidget().catch(() => undefined);
  }
);

onBeforeUnmount(() => {
  if (widget?.remove) {
    try {
      widget.remove();
    } catch {
      /* ignore */
    }
  }
});
</script>

<template>
  <div class="chart-shell">
    <div ref="host" class="chart-host" />
  </div>
</template>

<style scoped>
.chart-shell,
.chart-host {
  width: 100%;
  height: 420px;
}

.chart-host {
  border-radius: 12px;
  overflow: hidden;
  background: #0b0b0f;
}
</style>
