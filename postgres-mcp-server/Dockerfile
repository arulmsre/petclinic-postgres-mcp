FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy built application
COPY dist/ ./dist/

# Set environment variables
ENV NODE_ENV=production
ENV PG_HOST=${PG_HOST}
ENV PG_PORT=${PG_PORT:-5432}
ENV PG_DATABASE=${PG_DATABASE}
ENV PG_USER=${PG_USER}
ENV PG_PASSWORD=${PG_PASSWORD}
ENV PG_SSL=${PG_SSL:-true}

# Run the application
CMD ["node", "dist/index.js"]
