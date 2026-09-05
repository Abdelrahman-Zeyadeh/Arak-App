FROM node:22-slim

# yt-dlp needs Python + ffmpeg + a modern JS runtime (Node 22+ / Deno) for YouTube EJS challenge solving.
# YouTube requires:
# 1. PO Token provider (bgutil)
# 2. Modern JS runtime (Node 22 / Deno) + yt-dlp-ejs for YouTube signature/n-challenge solving
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip ffmpeg curl ca-certificates git unzip && \
    curl -L https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp && \
    curl -fsSL https://deno.land/install.sh | sh && \
    mv /root/.deno/bin/deno /usr/local/bin/deno && \
    pip3 install --no-cache-dir --break-system-packages --target /opt/ytdlp-plugins bgutil-ytdlp-pot-provider yt-dlp-ejs && \
    git clone --depth 1 --branch 1.3.2 https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git /opt/bgutil && \
    cd /opt/bgutil/server && npm ci && npx tsc && \
    apt-get purge -y git unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .

ENV PORT=3000
ENV YTDLP_PLUGIN_DIRS=/opt/ytdlp-plugins
ENV BGUTIL_SERVER_PATH=/opt/bgutil/server/build/main.js
EXPOSE 3000
CMD ["node", "server.js"]
