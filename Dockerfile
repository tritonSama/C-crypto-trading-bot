FROM node:20-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy application source
COPY . .

# Build the TypeScript and Vue applications
RUN npm run build

# Prune dev dependencies after build
RUN npm prune --omit=dev

# Expose the API port
EXPOSE 8787

# Start the node backend
CMD ["npm", "run", "start"]
