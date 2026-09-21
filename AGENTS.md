# AI Agent Context (creedBuilder)

Hello, fellow AI Agent! When interacting with this repository, please keep the following crucial information in mind:

## 1. Repository Structure
- **Active Codebase:** The modern, active application is located in the root directory. It is a Node.js webhook bot and Vue 3 frontend for automated Solana trading via Jupiter API.
- **Note:** The legacy C# codebase has been successfully removed in Phase 1 cleanup.

## 2. Build & Execution Commands
When asked to build or run the active application, use the root directory:

```bash
# To install dependencies
npm install

# To build the server and Vue GUI
npm run build

# To run the development server
npm run dev
```

For full environment startup (Node bot + Cloudflared tunnel + Vue GUI proxy), the user utilizes the root script:
- macOS/Linux: `./start.sh`

## 3. Important Context
- Configuration and state are currently managed by reading/writing to `.env`.
- Ensure any new dependencies added are installed within `package.json`.
- Refer to `DOCUMENTATION.md` for a comprehensive breakdown of the application architecture, webhook flow, and next steps for the project.

## 4. Future Agent Development Phases
To systematically improve the application and address existing technical debt, follow this phased layout when contributing:

### Phase 1: Technical Debt Cleanup & Restructuring (COMPLETED)
- **Goal:** Clean the workspace and centralize the modern application.
- **Actions:** Removed legacy C# codebase and centralized the Node.js/Vue app into the root repository.

### Phase 2: Infrastructure & Deployment Modernization
- **Goal:** Improve deployment reliability and implement continuous integration.
- **Actions:**
  1. **Dockerization:** Create a `Dockerfile` and `docker-compose.yml` to run the Node.js bot, Vue GUI, and Cloudflared tunnel seamlessly in isolated containers. Replace the platform-specific scripts with Docker instructions.
  2. **CI/CD:** Add GitHub Actions (`.github/workflows/`) to automatically run build steps and linting on pull requests.

### Phase 3: State Management & Testing
- **Goal:** Make the application state reliable and testable.
- **Actions:**
  1. **Database Integration:** Replace the current `.env` file mutation logic with a lightweight local database (e.g., `better-sqlite3` or `lowdb`). Use this for configuration storage, state management, and robust trade logging.
  2. **Automated Testing:** Integrate `Vitest` and write tests for webhook routing, payload validation (Zod), and Jupiter API integration mocks.

### Phase 4: Advanced Trading Features
- **Goal:** Expand trading capabilities.
- **Actions:**
  1. **Multi-Token Support:** Update the logic to accept optional `tokenMint` overrides in the webhook JSON payload, allowing dynamic multi-token trading.
  2. **Strategy Enhancements:** Add advanced configuration features like dynamic stop-loss, take-profit, or trailing stops.
  3. **Resilience:** Implement connection retries and fallback RPC URLs for the Solana web3 connection to handle network congestion.