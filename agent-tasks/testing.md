# Agent Task: Automated Testing

## Goal
The application currently relies entirely on manual testing. The goal is to introduce a test runner (like Vitest or Jest) and write unit tests for the core logic components.

## Instructions
1. Install `vitest` or `jest` (and their respective TypeScript types) as development dependencies.
2. Add a `test` script to `package.json`.
3. Create a `tests/` directory or write test files inline (e.g., `src/webhook.test.ts`).
4. Write unit tests for:
   - Configuration validation (`src/config.ts`).
   - The SQLite database getters, setters, and trade logging functions (`src/db.ts`).
   - Webhook payload validation and response logic (mocking the Jupiter API call) (`src/webhook.ts`).
5. Ensure all tests run and pass cleanly using `npm run test`.
6. Consider setting up a basic `.github/workflows/test.yml` GitHub action to run the tests on pull requests.
