FROM node:20-slim

# yt-dlp needs Python + ffmpeg (ffmpeg is used for merging/remuxing formats).
#
# YouTube now requires a "PO Token" (proof-of-origin) on most extraction
# requests — without one, yt-dlp fails with "Failed to extract any player
# response" on nearly every video, regardless of how up to date yt-dlp is.
# bgutil-ytdlp-pot-provider is the fix the yt-dlp maintainers themselves
# point to: a small local server that generates these tokens, plus a yt-dlp
# plugin that talks to it. We install both here:
#   - the plugin via `pip install --target`, so yt-dlp's standalone binary
#     can find it via --plugin-dirs (it has no site-packages of its own)
#   - the token-generating server, built from source into /opt/bgutil,
#     started by server.js alongside the main process (see startBgutilPotServer)
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip ffmpeg curl ca-certificates git && \
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp && \
    pip3 install --no-cache-dir --target /opt/ytdlp-plugins bgutil-ytdlp-pot-provider && \
    git clone --depth 1 --branch 1.3.2 https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git /opt/bgutil && \
    cd /opt/bgutil/server && npm ci && npx tsc && \
    apt-get purge -y git curl && \
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
