import {
  Connection,
  Keypair,
  VersionedTransaction,
  PublicKey,
} from "@solana/web3.js";
import bs58 from "bs58";
import { config, jupiterBaseUrl, jupiterHeaders } from "./config.js";

export type QuoteResponse = Record<string, unknown> & {
  inputMint: string;
  outputMint: string;
  inAmount: string;
  outAmount: string;
  error?: string;
};

export function loadKeypair(): Keypair {
  if (!config.SOLANA_PRIVATE_KEY) {
    throw new Error("SOLANA_PRIVATE_KEY is empty. Re-run the installer or set it in creedbuilder/.env");
  }
  const secret = bs58.decode(config.SOLANA_PRIVATE_KEY);
  return Keypair.fromSecretKey(secret);
}

export function connection(): Connection {
  return new Connection(config.SOLANA_RPC_URL, "confirmed");
}

export async function getQuote(
  inputMint: string,
  outputMint: string,
  amount: number
): Promise<QuoteResponse> {
  const params = new URLSearchParams({
    inputMint,
    outputMint,
    amount: String(amount),
    slippageBps: String(config.SLIPPAGE_BPS),
    restrictIntermediateTokens: "true",
  });

  const res = await fetch(`${jupiterBaseUrl()}/quote?${params}`, {
    headers: jupiterHeaders(),
  });
  const body = (await res.json()) as QuoteResponse;
  if (!res.ok || body.error) {
    throw new Error(`Jupiter quote failed: ${JSON.stringify(body)}`);
  }
  return body;
}

export async function executeSwap(quote: QuoteResponse, wallet: Keypair): Promise<string> {
  const swapRes = await fetch(`${jupiterBaseUrl()}/swap`, {
    method: "POST",
    headers: {
      ...jupiterHeaders(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      quoteResponse: quote,
      userPublicKey: wallet.publicKey.toBase58(),
      wrapAndUnwrapSol: true,
      dynamicComputeUnitLimit: true,
      prioritizationFeeLamports: {
        priorityLevelWithMaxLamports: {
          maxLamports: 1_000_000,
          priorityLevel: "high",
        },
      },
    }),
  });

  const swapJson = (await swapRes.json()) as {
    swapTransaction?: string;
    error?: string;
  };

  if (!swapRes.ok || !swapJson.swapTransaction) {
    throw new Error(`Jupiter swap failed: ${JSON.stringify(swapJson)}`);
  }

  const tx = VersionedTransaction.deserialize(
    Buffer.from(swapJson.swapTransaction, "base64")
  );
  tx.sign([wallet]);

  const conn = connection();
  const sig = await conn.sendTransaction(tx, {
    skipPreflight: false,
    maxRetries: 3,
  });
  const latest = await conn.getLatestBlockhash();
  await conn.confirmTransaction({ signature: sig, ...latest }, "confirmed");
  return sig;
}

/** SPL token balance in raw units (0 if ATA missing). */
export async function getTokenRawBalance(
  owner: PublicKey,
  mint: string
): Promise<number> {
  const conn = connection();
  const mintPk = new PublicKey(mint);
  const accounts = await conn.getParsedTokenAccountsByOwner(owner, {
    mint: mintPk,
  });
  if (accounts.value.length === 0) return 0;
  const amount = accounts.value[0].account.data.parsed.info.tokenAmount.amount;
  return Number(amount);
}

export async function runTrade(action: "buy" | "sell"): Promise<{
  dryRun: boolean;
  quote: QuoteResponse;
  signature?: string;
}> {
  const wallet = loadKeypair();
  let inputMint: string;
  let outputMint: string;
  let amount: number;

  if (action === "buy") {
    inputMint = config.SOL_MINT;
    outputMint = config.TOKEN_MINT;
    amount = config.BUY_AMOUNT_LAMPORTS;
  } else {
    inputMint = config.TOKEN_MINT;
    outputMint = config.SOL_MINT;
    const bal = await getTokenRawBalance(wallet.publicKey, config.TOKEN_MINT);
    amount = Math.floor((bal * config.SELL_PERCENT) / 100);
    if (amount <= 0) {
      throw new Error("No TOKEN balance to sell");
    }
  }

  const quote = await getQuote(inputMint, outputMint, amount);
  console.log(
    `[jupiter] ${action} quote in=${quote.inAmount} out=${quote.outAmount} impact=${String(quote.priceImpactPct ?? "?")}`
  );

  if (config.DRY_RUN) {
    return { dryRun: true, quote };
  }

  const signature = await executeSwap(quote, wallet);
  console.log(`[jupiter] tx ${signature}`);
  return { dryRun: false, quote, signature };
}
