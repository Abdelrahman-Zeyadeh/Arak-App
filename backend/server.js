// Arak Extraction Server
//
// A tiny HTTP wrapper around the real `yt-dlp` binary. The Arak mobile app
// (Android/iOS) cannot execute subprocesses, so it cannot run yt-dlp
// locally the way the Windows/macOS/Linux desktop build does. Instead of
// relying on hand-rolled regex scraping of Facebook/Instagram/Twitter pages
// (which those platforms actively block for anonymous requests), the app
// calls this server, which runs the same yt-dlp extractors the desktop
// build uses and returns the standard `--dump-json` payload.
//
// The response format matches yt-dlp's own JSON output, so the Flutter
// app parses it with the exact same `VideoMetadata.fromYtDlpJson` code
// path used for the desktop binary — one extraction format for every
// platform.

const express = require('express');
const { execFile, spawn } = require('child_process');
const ytdl = require('@distube/ytdl-core');

const app = express();
app.use(express.json({ limit: '256kb' }));

const PORT = process.env.PORT || 3000;
const YTDLP_PATH = process.env.YTDLP_PATH || 'yt-dlp';
// Optional shared secret so randoms can't hammer your free-tier instance.
// Set API_KEY on the host and the same value in the app's Settings screen.
const API_KEY = process.env.API_KEY || '';

// See the Dockerfile for why these exist: YouTube now requires a PO Token
// on most requests, so yt-dlp needs the bgutil plugin (found via
// --plugin-dirs, since the standalone binary has no site-packages of its
// own) talking to a locally-running token server. Both are empty in local
// dev unless you've installed them yourself — extraction still works there,
// just without the PO Token workaround, so it inherits whatever YouTube's
// current anti-bot behavior is.
const YTDLP_PLUGIN_DIRS = process.env.YTDLP_PLUGIN_DIRS || '';
const BGUTIL_SERVER_PATH = process.env.BGUTIL_SERVER_PATH || '';
const BGUTIL_BASE_URL = process.env.BGUTIL_BASE_URL || 'http://127.0.0.1:4416';

function checkAuth(req, res, next) {
  if (!API_KEY) return next();
  if (req.headers['x-api-key'] === API_KEY) return next();
  return res.status(401).json({ error: 'unauthorized' });
}

app.get('/health', (req, res) => {
  res.json({ status: 'ok', ytdlp: YTDLP_PATH });
});

app.post('/extract', checkAuth, (req, res) => {
  const url = req.body && req.body.url;
  if (!url || typeof url !== 'string') {
    return res.status(400).json({ error: 'url is required' });
  }

  const args = ytdlpArgs(url);

  execFile(
    YTDLP_PATH,
    args,
    { maxBuffer: 1024 * 1024 * 25, timeout: 45000 },
    async (err, stdout, stderr) => {
      if (err) {
        const message = (stderr || err.message || '').toString();
        console.error('[extract] yt-dlp failed:', message);

        // Last-resort fallback for Instagram photo posts if the flag above
        // still didn't yield metadata for some reason: scrape the public
        // page's og:image directly.
        if (url.includes('instagram.com') && /no video in this post/i.test(message)) {
          const photoJson = await tryExtractInstagramPhoto(url);
          if (photoJson) return res.json(photoJson);
        }

        // yt-dlp is a single shared open-source project — when YouTube ships
        // a breaking internal change, every yt-dlp install worldwide fails
        // the same way (e.g. "Failed to extract any player response") until
        // its maintainers ship a fix release, which can take a day or more.
        // @distube/ytdl-core is a separate, independently-maintained
        // extractor for YouTube specifically — often already patched for
        // exactly this kind of break, or breaks on a different schedule —
        // so it's a real second opinion worth trying, not just a retry of
        // the same failure.
        if (isYoutubeUrl(url)) {
          const ytdlJson = await tryExtractViaYtdlCore(url);
          if (ytdlJson) return res.json(ytdlJson);
        }

        return res.status(502).json({
          error: 'extraction_failed',
          message: message.slice(-1000),
        });
      }
      try {
        // yt-dlp sometimes prints warnings to stdout before the JSON line;
        // the JSON payload is always the last non-empty line.
        const lines = stdout.trim().split('\n').filter(Boolean);
        const json = JSON.parse(lines[lines.length - 1]);

        // Photo-only post: --ignore-no-formats-error lets this through with
        // an empty/missing `formats` array but a real `thumbnail`/`url`
        // pointing at the full-resolution image. Synthesize a single
        // "photo" format from it so the app has something to download.
        if ((!json.formats || json.formats.length === 0)) {
          const imageUrl = json.thumbnail || json.url;
          if (imageUrl) {
            json.formats = [
              {
                format_id: 'photo',
                ext: 'jpg',
                vcodec: 'none',
                acodec: 'none',
                format_note: 'Photo',
                url: imageUrl,
              },
            ];
          }
        }

        return res.json(json);
      } catch (parseErr) {
        console.error('[extract] failed to parse yt-dlp output:', parseErr.message);

        // Same Instagram photo fallback if --ignore-no-formats-error still
        // produced no parseable JSON line.
        if (url.includes('instagram.com')) {
          const photoJson = await tryExtractInstagramPhoto(url);
          if (photoJson) return res.json(photoJson);
        }

        return res.status(502).json({ error: 'parse_failed', message: parseErr.message });
      }
    }
  );
});

function isYoutubeUrl(url) {
  return /(?:youtube\.com|youtu\.be)/i.test(url);
}

// Builds the yt-dlp argument list for a given URL. Split out from the
// /extract handler so the PO Token plumbing (see the Dockerfile and the
// constants above) lives in one place instead of being duplicated anywhere
// else yt-dlp gets invoked.
function ytdlpArgs(url) {
  const args = [
    '--dump-json',
    '--no-warnings',
    '--no-playlist',
    '--no-check-certificates',
    '--socket-timeout', '20',
    // Photo-only posts (no video track — common on Instagram/Facebook)
    // would otherwise make yt-dlp hard-error with "There is no video in
    // this post" and print nothing. This flag makes it still dump the
    // metadata JSON (title/thumbnail/etc.) with an empty `formats` list,
    // which we turn into a downloadable "photo" format below.
    '--ignore-no-formats-error',
  ];
  if (YTDLP_PLUGIN_DIRS) {
    args.push('--plugin-dirs', YTDLP_PLUGIN_DIRS);
  }
  if (isYoutubeUrl(url) && YTDLP_PLUGIN_DIRS) {
    args.push('--extractor-args', `youtubepot-bgutilhttp:base_url=${BGUTIL_BASE_URL}`);
  }
  args.push(url);
  return args;
}

// Starts the local PO Token server the bgutil yt-dlp plugin talks to (see
// the Dockerfile). It's a plain long-running Node process — if it dies,
// YouTube extraction degrades back to failing with PO Token errors until
// the next deploy/restart, rather than taking the rest of this server down
// with it, so its exit is logged but not treated as fatal.
function startBgutilPotServer() {
  if (!BGUTIL_SERVER_PATH) {
    console.log('[startup] BGUTIL_SERVER_PATH not set — skipping PO Token server (expected in local dev)');
    return;
  }
  const proc = spawn('node', [BGUTIL_SERVER_PATH], { stdio: 'inherit' });
  proc.on('exit', (code) => {
    console.error(
      `[startup] bgutil PO Token server exited (code ${code}) — YouTube extraction may start failing with PO Token errors until this service restarts.`
    );
  });
  proc.on('error', (err) => {
    console.error('[startup] failed to start bgutil PO Token server:', err.message);
  });
}

// Independent fallback extractor for YouTube, used only when yt-dlp itself
// fails (see the comment at its call site). Reshapes @distube/ytdl-core's
// own info/format shape into the same yt-dlp `--dump-json` shape the app
// already parses (`VideoMetadata.fromYtDlpJson`), so no extra branching is
// needed on the Flutter side.
async function tryExtractViaYtdlCore(url) {
  try {
    const info = await ytdl.getInfo(url);
    const details = info.videoDetails;
    const thumbnails = details.thumbnails || [];
    const bestThumbnail = thumbnails.length ? thumbnails[thumbnails.length - 1].url : '';

    const formats = info.formats
      .filter((f) => f.hasAudio || f.hasVideo)
      .map((f) => ({
        format_id: String(f.itag),
        ext: f.container || 'mp4',
        height: f.height || null,
        resolution: f.qualityLabel || null,
        format_note: f.qualityLabel || f.quality || '',
        filesize: f.contentLength ? Number(f.contentLength) : null,
        vcodec: f.hasVideo ? f.videoCodec || 'unknown' : 'none',
        acodec: f.hasAudio ? f.audioCodec || 'unknown' : 'none',
        fps: f.fps || null,
        abr: f.audioBitrate || null,
        url: f.url,
      }));

    return {
      id: details.videoId,
      title: details.title,
      uploader: details.author ? details.author.name : '',
      thumbnail: bestThumbnail,
      duration: details.lengthSeconds ? parseInt(details.lengthSeconds, 10) : 0,
      webpage_url: details.video_url || url,
      formats,
    };
  } catch (e) {
    console.error('[extract] ytdl-core fallback also failed:', e.message);
    return null;
  }
}

// Scrapes an Instagram post's public page for its og:image / og:title meta
// tags and returns a synthetic yt-dlp-shaped JSON payload (a single "photo"
// format) so the app's existing formats-parsing code can handle it without
// any extra branching. Returns null if the page can't be read.
async function tryExtractInstagramPhoto(url) {
  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml',
      },
    });
    if (!response.ok) return null;
    const html = await response.text();

    const imageMatch = html.match(/<meta property="og:image" content="([^"]+)"/i);
    const titleMatch = html.match(/<meta property="og:title" content="([^"]+)"/i);
    const imageUrl = imageMatch ? imageMatch[1].replace(/&amp;/g, '&') : null;
    if (!imageUrl) return null;

    const idMatch = url.match(/\/(?:p|reel|reels)\/([^/?]+)/);
    const id = idMatch ? idMatch[1] : 'instagram_photo';

    return {
      id,
      title: titleMatch ? titleMatch[1] : 'Instagram Photo',
      uploader: 'Instagram',
      thumbnail: imageUrl,
      duration: 0,
      webpage_url: url,
      formats: [
        {
          format_id: 'photo',
          ext: 'jpg',
          vcodec: 'none',
          acodec: 'none',
          format_note: 'Photo',
          url: imageUrl,
        },
      ],
    };
  } catch (e) {
    console.error('[extract] Instagram photo fallback failed:', e.message);
    return null;
  }
}

// YouTube changes its player/signature internals often enough that a
// yt-dlp binary baked into the Docker image at build time can go stale
// within days — this server keeps running for weeks between deploys (Render
// free tier just spins the same container up/down on inactivity, it
// doesn't rebuild), so a build-time-only yt-dlp silently rots and every
// extraction starts failing with "Failed to extract any player response"
// until someone happens to redeploy. Self-updating on every boot means each
// cold start is also a chance to pick up a yt-dlp fix, no redeploy needed.
function selfUpdateYtdlp() {
  execFile(YTDLP_PATH, ['-U'], { timeout: 30000 }, (error, stdout, stderr) => {
    if (error) {
      console.error('[startup] yt-dlp self-update failed (continuing with existing binary):', error.message);
      return;
    }
    console.log('[startup] yt-dlp self-update:', stdout.trim() || stderr.trim());
  });
}

selfUpdateYtdlp();
startBgutilPotServer();

app.listen(PORT, () => {
  console.log(`Arak extraction server listening on port ${PORT}`);
});
