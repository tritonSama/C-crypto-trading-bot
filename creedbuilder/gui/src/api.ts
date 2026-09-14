export type Status = {
  service: string;
  port: number;
  dryRun: boolean;
  wallet: string | null;
  walletError: string | null;
  setupComplete: boolean;
  tokenMint: string;
  solMint: string;
  buyAmountLamports: number;
  sellPercent: number;
  slippageBps: number;
  rpcUrl: string;
  hasJupiterKey: boolean;
  webhookSecret: string;
  localWebhook: string;
  localGui: string;
  guiSteps: string[];
};

export type SolanaToken = {
  symbol: string;
  name: string;
  mint: string;
  tvSymbol: string;
  tags: string[];
};

export type NewsItem = {
  id: string;
  title: string;
  url: string;
  source: string;
  publishedAt: string;
  body: string;
  categories: string;
};

async function parseJson(res: Response) {
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error((data as { error?: string }).error || res.statusText);
  }
  return data;
}

export async function fetchStatus(): Promise<Status> {
  return parseJson(await fetch("/api/status")) as Promise<Status>;
}

export async function fetchTokens(): Promise<SolanaToken[]> {
  const data = (await parseJson(await fetch("/api/tokens"))) as { tokens: SolanaToken[] };
  return data.tokens;
}

export async function fetchNews(): Promise<NewsItem[]> {
  const data = (await parseJson(await fetch("/api/news"))) as { items: NewsItem[] };
  return data.items ?? [];
}

export async function fetchPine(): Promise<string> {
  const res = await fetch("/api/pine");
  if (!res.ok) throw new Error("Could not load Pine script");
  return res.text();
}

export async function saveConfig(body: Record<string, unknown>) {
  return parseJson(
    await fetch("/api/config", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    })
  ) as Promise<{ ok: boolean; status: Status }>;
}

export async function testTrade(action: "buy" | "sell") {
  return parseJson(
    await fetch("/api/test-trade", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    })
  );
}
