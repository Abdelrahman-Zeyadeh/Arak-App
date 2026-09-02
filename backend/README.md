# Arak Extraction Server

Why this exists: on Android/iOS the app can't run the `yt-dlp` binary
locally (no subprocess execution), so Facebook/Instagram/Twitter links were
falling back to fragile HTML scraping + free third-party mirror APIs that
frequently break or get blocked. This tiny server runs the **real yt-dlp**
and gives the app a reliable `POST /extract` endpoint that returns the
same JSON yt-dlp produces on desktop.

## Run locally

```bash
cd backend
npm install
# yt-dlp must be installed and on PATH — https://github.com/yt-dlp/yt-dlp#installation
npm start
```

Server listens on `http://localhost:3000`. Test it:

```bash
curl -X POST http://localhost:3000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.facebook.com/watch/?v=..."}'
```

## Deploy for free — Render.com

1. Push this repo to GitHub (the `backend/` folder just needs to be in it).
2. Go to https://render.com → **New** → **Web Service** → connect your repo.
3. Set **Root Directory** to `backend`.
4. **Runtime**: Docker (Render will pick up the `Dockerfile` automatically).
5. **Instance Type**: Free.
6. (Optional but recommended) Add an environment variable `API_KEY` with a
   random secret string — this stops strangers from using your free
   instance. If you set it here, enter the same value in the app's
   **Settings → Extraction Server** screen.
7. Deploy. Render gives you a URL like `https://arak-extraction.onrender.com`.
8. In the Arak app, go to **Settings → Extraction Server**, paste that URL
   (and the API key if you set one), and save.

### Free tier caveat

Render's free web services spin down after ~15 minutes of no traffic and
take 20–50 seconds to "wake up" on the next request (cold start). That's
fine for personal use — the app's extraction call has enough timeout to
survive one cold start, and every request after that is fast.

## Deploy for free — Fly.io (alternative)

```bash
cd backend
fly launch   # accept defaults, it detects the Dockerfile
fly deploy
```

Fly's free allowance also sleeps idle machines; same cold-start trade-off
as Render.

## Security note

This server just shells out to `yt-dlp` with a URL you send it — don't
expose it publicly without the `API_KEY` option, or randoms could rack up
your host's compute time.
