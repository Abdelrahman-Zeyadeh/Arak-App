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
const { execFile } = require('child_process');

const app = express();
app.use(express.json({ limit: '256kb' }));

const PORT = process.env.PORT || 3000;
const YTDLP_PATH = process.env.YTDLP_PATH || 'yt-dlp';
// Optional shared secret so randoms can't hammer your free-tier instance.
// Set API_KEY on the host and the same value in the app's Settings screen.
const API_KEY = process.env.API_KEY || '';

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

  const args = [
    '--dump-json',
    '--no-warnings',
    '--no-playlist',
    '--no-check-certificates',
    '--socket-timeout', '20',
    url,
  ];

  execFile(
    YTDLP_PATH,
    args,
    { maxBuffer: 1024 * 1024 * 25, timeout: 45000 },
    async (err, stdout, stderr) => {
      if (err) {
        const message = (stderr || err.message || '').toString();
        console.error('[extract] yt-dlp failed:', message);

        // Instagram photo-only posts (no video track) are a real, common
        // case yt-dlp intentionally refuses ("There is no video in this
        // post") since it only handles video extraction. Fall back to
        // scraping the post's og:image so the app can still offer a photo
        // download instead of a dead end.
        if (url.includes('instagram.com') && /no video in this post/i.test(message)) {
          const photoJson = await tryExtractInstagramPhoto(url);
          if (photoJson) return res.json(photoJson);
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
        return res.json(json);
      } catch (parseErr) {
        console.error('[extract] failed to parse yt-dlp output:', parseErr.message);
        return res.status(502).json({ error: 'parse_failed', message: parseErr.message });
      }
    }
  );
});

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

app.listen(PORT, () => {
  console.log(`Arak extraction server listening on port ${PORT}`);
});
