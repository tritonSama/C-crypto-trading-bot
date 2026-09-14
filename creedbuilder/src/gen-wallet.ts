import { Keypair } from "@solana/web3.js";
import bs58 from "bs58";

const kp = Keypair.generate();
const secret = bs58.encode(kp.secretKey);
console.log(JSON.stringify({
  publicKey: kp.publicKey.toBase58(),
  privateKeyBase58: secret,
}));
