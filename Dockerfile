# syntax=docker/dockerfile:1

# ---------- Build stage ----------
FROM node:22-alpine AS build
WORKDIR /app

# Enable pnpm (repo uses pnpm per its README)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install deps first for better layer caching
COPY frontend/package.json ./
COPY frontend/pnpm-lock.yaml* ./
RUN pnpm install --no-frozen-lockfile

# Copy the rest of the frontend source
COPY frontend/ ./

# Build-time env vars (Vite only inlines VITE_* vars at build time).
# Render turns any envVars you set on the service into Docker build args
# automatically, so these ARGs pick them up.
ARG VITE_API_BASE_URL
ARG VITE_RECAPTCHA_SITE_KEY
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_RECAPTCHA_SITE_KEY=${VITE_RECAPTCHA_SITE_KEY}

RUN pnpm approve-builds || true
RUN pnpm build

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine

# Template so we can substitute Render's $PORT at container start
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

ENV PORT=10000
EXPOSE 10000

# nginx:alpine's entrypoint already runs envsubst on files in
# /etc/nginx/templates/*.template -> /etc/nginx/conf.d/*.conf using env vars,
# as long as we only reference ${PORT} (envsubst needs the var listed below).
ENV NGINX_ENVSUBST_TEMPLATE_SUFFIX=.template
ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/conf.d

CMD ["nginx", "-g", "daemon off;"]
