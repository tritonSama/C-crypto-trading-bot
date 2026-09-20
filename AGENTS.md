# AI Agent Context (creedBuilder)

Hello, fellow AI Agent! When interacting with this repository, please keep the following crucial information in mind:

## 1. Repository Structure & Technical Debt
- **Active Codebase (`creedbuilder/`):** The modern, active application is located exclusively within the `creedbuilder/` directory. It is a Node.js webhook bot and Vue 3 frontend for automated Solana trading via Jupiter API.
- **Legacy Codebase (Root):** The root folder contains numerous legacy C# files (e.g., `Program.cs`, `Coin.cs`, `Global.cs`) and MongoDB schemas (`MongoDB_Schema/`). This is technical debt likely related to an old Coinbase bot project. **Do not modify or attempt to build the C# code** unless specifically instructed by the user to clean it up.

## 2. Build & Execution Commands
When asked to build or run the active application, always work inside the `creedbuilder/` directory:

```bash
# To install dependencies
cd creedbuilder && npm install

# To build the server and Vue GUI
cd creedbuilder && npm run build

# To run the development server
cd creedbuilder && npm run dev
```

For full environment startup (Node bot + Cloudflared tunnel + Vue GUI proxy), the user utilizes the root scripts:
- Windows: `.\Start.cmd`
- macOS/Linux: `./start.sh`

## 3. Important Context
- Configuration and state are currently managed by reading/writing to `creedbuilder/.env`.
- Ensure any new dependencies added are installed within `creedbuilder/package.json`.
- Refer to `DOCUMENTATION.md` for a comprehensive breakdown of the application architecture, webhook flow, and next steps for the project.

## 4. Future Agent Development Phases
To systematically improve the application and address existing technical debt, follow this phased layout when contributing:

### Phase 1: Technical Debt Cleanup & Restructuring
- **Goal:** Clean the workspace and centralize the modern application.
- **Actions:**
  1. Identify and delete all legacy C# files (e.g., `Program.cs`, `Coin.cs`, `MongoDB_Schema/`, etc.) located in the root directory.
  2. Move the contents of the `creedbuilder/` directory (the active Node.js/Vue app) directly into the root repository folder.
  3. Update any path references in `package.json`, `.gitignore`, `Install.cmd`, and `start.sh` to reflect the new structure.

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