# AI Agent Context (creedBuilder)

Hello, fellow AI Agent! When interacting with this repository, please keep the following crucial information in mind:

## 1. Repository Structure & Technical Debt
The modern, active application is located exclusively within the repository root. It is a Node.js webhook bot and Vue 3 frontend for automated Solana trading via Jupiter API. (Note: legacy C# code that previously cluttered the root has been removed).

## 2. Build & Execution Commands
When asked to build or run the active application, always work inside the root directory:

```bash
# To install dependencies
npm install

# To build the server and Vue GUI
npm run build

# To run the development server
npm run dev
```

For full environment startup (Node bot + Cloudflared tunnel + Vue GUI proxy), the user utilizes the root scripts:
- Windows: `.\Start.cmd`
- macOS/Linux: `./start.sh`

## 3. Important Context
- Configuration and state are currently managed by reading/writing to `creedbuilder/.env`.
- Ensure any new dependencies added are installed within `creedbuilder/package.json`.
- Refer to `DOCUMENTATION.md` for a comprehensive breakdown of the application architecture, webhook flow, and next steps for the project.