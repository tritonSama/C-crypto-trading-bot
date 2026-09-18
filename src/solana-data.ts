export type SolanaToken = {
  symbol: string;
  name: string;
  mint: string;
  /** TradingView symbol for the embedded chart */
  tvSymbol: string;
  tags: string[];
};

/** Curated Solana ecosystem tokens for chart + Jupiter trading. */
export const SOLANA_TOKENS: SolanaToken[] = [
  {
    symbol: "SOL",
    name: "Solana",
    mint: "So11111111111111111111111111111111111111112",
    tvSymbol: "BINANCE:SOLUSDT",
    tags: ["l1", "native"],
  },
  {
    symbol: "USDC",
    name: "USD Coin",
    mint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    tvSymbol: "BINANCE:SOLUSDT",
    tags: ["stablecoin"],
  },
  {
    symbol: "JUP",
    name: "Jupiter",
    mint: "JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN",
    tvSymbol: "BINANCE:JUPUSDT",
    tags: ["defi", "dex"],
  },
  {
    symbol: "RAY",
    name: "Raydium",
    mint: "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R",
    tvSymbol: "BINANCE:RAYUSDT",
    tags: ["defi", "dex"],
  },
  {
    symbol: "ORCA",
    name: "Orca",
    mint: "orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE",
    tvSymbol: "BINANCE:ORCAUSDT",
    tags: ["defi", "dex"],
  },
  {
    symbol: "BONK",
    name: "Bonk",
    mint: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263",
    tvSymbol: "BINANCE:BONKUSDT",
    tags: ["meme"],
  },
  {
    symbol: "WIF",
    name: "dogwifhat",
    mint: "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm",
    tvSymbol: "BINANCE:WIFUSDT",
    tags: ["meme"],
  },
  {
    symbol: "PYTH",
    name: "Pyth Network",
    mint: "HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3",
    tvSymbol: "BINANCE:PYTHUSDT",
    tags: ["oracle"],
  },
  {
    symbol: "JTO",
    name: "Jito",
    mint: "jtojtomepa8beP8AuQc6eXt5FriJwfFMwQx2v2f9mCL",
    tvSymbol: "BINANCE:JTOUSDT",
    tags: ["staking", "mev"],
  },
  {
    symbol: "W",
    name: "Wormhole",
    mint: "85VBFQZC9TZkfaptBWjvUw7YbZjx5FbnAm8UvHVgPKMa",
    tvSymbol: "BINANCE:WUSDT",
    tags: ["bridge"],
  },
];

export type NewsItem = {
  id: string;
  title: string;
  url: string;
  source: string;
  publishedAt: string;
  body: string;
  categories: string;
};

export async function fetchSolanaNews(): Promise<NewsItem[]> {
  const url =
    "https://min-api.cryptocompare.com/data/v2/news/?lang=EN&categories=SOL,Blockchain,Trading";
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
  });
  if (!res.ok) {
    throw new Error(`News feed failed (${res.status})`);
  }
  const json = (await res.json()) as {
    Data?: Array<{
      id: string | number;
      title: string;
      url: string;
      source: string;
      published_on: number;
      body: string;
      categories: string;
    }>;
  };

  const rows = json.Data ?? [];
  const solanaish = rows.filter((row) => {
    const hay = `${row.title} ${row.body} ${row.categories}`.toLowerCase();
    return (
      hay.includes("solana") ||
      hay.includes(" sol ") ||
      hay.includes("jupiter") ||
      hay.includes("raydium") ||
      hay.includes("bonk") ||
      row.categories?.toUpperCase().includes("SOL")
    );
  });

  const picked = (solanaish.length > 0 ? solanaish : rows).slice(0, 16);
  return picked.map((row) => ({
    id: String(row.id),
    title: row.title,
    url: row.url,
    source: row.source,
    publishedAt: new Date(row.published_on * 1000).toISOString(),
    body: row.body?.slice(0, 220) ?? "",
    categories: row.categories ?? "",
  }));
}
