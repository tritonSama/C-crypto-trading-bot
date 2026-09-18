# Agent Task: Dockerization

## Goal
The application is currently run via platform-specific bash or PowerShell scripts (`start.sh`, `Start.cmd`) which require Node.js and Cloudflared to be installed locally. The goal is to Dockerize the entire application stack so it can be deployed seamlessly to any cloud provider or server.

## Instructions
1. Create a `Dockerfile` in the root of the repository. It should:
   - Use a Node.js 20+ base image (e.g., `node:20-alpine`).
   - Copy `package.json` and `package-lock.json`, and run `npm install --omit=dev`.
   - Copy the remaining source code.
   - Run `npm run build` to compile the TypeScript and Vite Vue application.
   - Expose port `8787`.
   - Start the node backend `npm run start`.
2. Create a `docker-compose.yml` file. It should:
   - Have a `bot` service using the newly created Dockerfile.
   - Have a `cloudflared` service using the official `cloudflare/cloudflared` image to establish a quick tunnel pointing to the `bot` container on port `8787`.
3. Update `DOCUMENTATION.md` to explain how a user can spin up the environment using `docker compose up -d`.
4. Ensure you verify that the container builds correctly before submitting your changes.
