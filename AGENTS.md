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