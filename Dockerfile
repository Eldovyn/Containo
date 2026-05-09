# Stage 1: Dependencies
FROM node:22-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Enable corepack untuk pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy file manifest (lockfile opsional jika belum ada, tapi disarankan)
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
# Kita tidak menggunakan --frozen-lockfile jika kamu baru setup, 
# agar pnpm bisa meng-generate lockfile jika belum ada.
RUN pnpm install --frozen-lockfile --ignore-scripts

# Bangun ulang library spesifik yang butuh kompilasi native
RUN pnpm rebuild sharp cpu-features protobufjs ssh2 unrs-resolver

# Stage 2: Builder
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate

# Ambil node_modules dari stage deps
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Matikan telemetri Next.js untuk privasi/kecepatan
ENV NEXT_TELEMETRY_DISABLED 1

# Build aplikasi
RUN pnpm build

# Stage 3: Runner
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN apk add --no-cache libc6-compat

# Security: Jalankan sebagai user non-root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy asset publik dan hasil build standalone
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

# Port yang digunakan
EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

# Jalankan server dari hasil standalone build
CMD ["node", "server.js"]
