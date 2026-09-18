# Agent Task: Multi-Token Support

## Goal
Currently, the application trades a single token mint specified by the `TOKEN_MINT` configuration. The goal is to modify the application to support dynamic token inputs from the TradingView webhook payload, allowing the user to trade an array of different tokens using the same bot instance.

## Instructions
1. Review the existing webhook payload schema in `src/webhook.ts`.
2. Expand the `payloadSchema` to optionally accept a `tokenMint` string.
3. Update `src/jupiter.ts` to accept the `tokenMint` as an argument for generating a quote and executing the swap. If a `tokenMint` is provided in the webhook, use it. If not, fallback to the default `config.TOKEN_MINT`.
4. Update the test trade API endpoint in `src/gui-api.ts` to reflect the changes in the `jupiter.ts` function signatures.
5. Update `pine/CreedBuilderSignal.pine` with comments explaining how a user can format their JSON alert to pass a specific `tokenMint`.
6. Update `DOCUMENTATION.md` to explain the new multi-token feature and the updated webhook payload structure.
