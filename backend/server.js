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

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const { execFile, spawn } = require('child_process');
const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const ytdl = require('@distube/ytdl-core');

const app = express();
app.use(express.json({ limit: '256kb' }));

// Structured JSON request logging & request-id tracking (Stage 2)
app.use((req, res, next) => {
  const reqId = req.headers['x-request-id'] || crypto.randomUUID();
  req.id = reqId;
  res.setHeader('x-request-id', reqId);
  const start = Date.now();
  const deviceId = req.headers['x-device-id'] || null;

  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      level: res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info',
      time: new Date().toISOString(),
      reqId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: duration,
      ip: req.ip || req.connection.remoteAddress || null,
      deviceId: deviceId ? `${deviceId.slice(0, 8)}...` : undefined,
    };
    if (res.statusCode >= 500) {
      console.error(JSON.stringify(logData));
    } else {
      console.log(JSON.stringify(logData));
    }
  });

  next();
});

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

// Second, independent workaround for the same PO Token problem: a real
// signed-in session (cookies) plus a specific player client is what actual
// browsers/apps present, and yt-dlp is more permissive with those than an
// anonymous request. Two ways to provide the cookies.txt content, since
// different hosts support different secret-storage mechanisms:
//   - COOKIES_PATH: an absolute path to an already-mounted file (e.g.
//     Render's "Secret Files", mounted at /etc/secrets/<name>)
//   - COOKIES_CONTENT: the raw cookies.txt text itself, for hosts (e.g.
//     Fly.io) that only offer secret *environment variables*, no secret
//     *files* — written out to a temp file once at startup below.
// Never commit a real cookies.txt to the repo — it's equivalent to a
// login session for whatever account exported it.
let COOKIES_PATH = process.env.COOKIES_PATH || '';
if (!COOKIES_PATH && process.env.COOKIES_CONTENT) {
  COOKIES_PATH = path.join(os.tmpdir(), 'yt-cookies.txt');
  try {
    fs.writeFileSync(COOKIES_PATH, process.env.COOKIES_CONTENT, { mode: 0o600 });
  } catch (e) {
    console.error('[startup] failed to write COOKIES_CONTENT to disk:', e.message);
    COOKIES_PATH = '';
  }
}
// Comma-separated client list for yt-dlp's `player_client` extractor-arg.
// Default to empty so yt-dlp uses its full default extractor clients which extract all 40+ audio/video formats.
const PLAYER_CLIENT = process.env.PLAYER_CLIENT || '';

// Device ids abusing the server, comma-separated. The only lever available
// for cutting one off without shipping a new app build.
const BLOCKED_DEVICE_IDS = new Set(
  (process.env.BLOCKED_DEVICE_IDS || '').split(',').map((d) => d.trim()).filter(Boolean),
);

// Shape of the id the app generates (SecureStorageService.getDeviceId):
// "arak_<hex>". Checked so the header carries something we can attribute a
// rate-limit bucket and a block to, rather than any eight characters.
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{12,128}$/;

/// Gate for the routes the app itself calls (/extract, /yt/*).
///
/// This is **identification, not authentication**: the device id is
/// self-asserted, so anyone can mint one. That is deliberate — the id is
/// baked into every install and there is no registration handshake yet, so
/// treating it as a secret would only lock out real users. What it does buy
/// is a stable key for per-device rate limiting and for BLOCKED_DEVICE_IDS.
///
/// Nothing dangerous may sit behind this gate. Anything that runs a command,
/// mutates the server, or exposes its internals goes behind
/// [requireAdminKey] instead, which needs the real API_KEY.
function checkAuth(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  if (API_KEY && apiKey === API_KEY) return next();

  const deviceId = (req.headers['x-device-id'] || '').trim();
  if (deviceId && BLOCKED_DEVICE_IDS.has(deviceId)) {
    return res.status(403).json({ error: 'device_blocked' });
  }
  if (DEVICE_ID_PATTERN.test(deviceId)) return next();
  if (!API_KEY) return next();
  return res.status(401).json({ error: 'unauthorized' });
}

/// Gate for operator-only routes. Requires the real API_KEY — a device id is
/// never enough, because a device id is not a secret (see [checkAuth]).
/// With no API_KEY configured these routes stay shut rather than falling
/// open, and answer 404 so an unconfigured server doesn't advertise them.
function requireAdminKey(req, res, next) {
  if (!API_KEY) return res.status(404).json({ error: 'not_found' });
  if (req.headers['x-api-key'] === API_KEY) return next();
  return res.status(401).json({ error: 'unauthorized' });
}

// --- YouTube Data API Proxy & Caching (Stage 1) ---
const YT_API_KEYS = (process.env.YT_API_KEYS || process.env.YOUTUBE_API_KEY || '').split(',').map(k => k.trim()).filter(Boolean);
let currentKeyIndex = 0;

class SimpleCache {
  constructor(maxSize = 1000) {
    this.maxSize = maxSize;
    this.map = new Map();
  }

  get(key) {
    const entry = this.map.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiry) {
      this.map.delete(key);
      return null;
    }
    // Refresh LRU order
    this.map.delete(key);
    this.map.set(key, entry);
    return entry.value;
  }

  set(key, value, ttlMs) {
    if (this.map.size >= this.maxSize) {
      const oldestKey = this.map.keys().next().value;
      if (oldestKey) this.map.delete(oldestKey);
    }
    this.map.set(key, { value, expiry: Date.now() + ttlMs });
  }
}

const ytCache = new SimpleCache(1000);
const extractionCache = new SimpleCache(500);
const EXTRACTION_CACHE_TTL_MS = 2 * 60 * 60 * 1000; // 2 hours

// --- Rate Limiting & Concurrency Hardening (Stage 2) ---
const keyGenerator = (req) => {
  const deviceId = req.headers['x-device-id'];
  if (deviceId && typeof deviceId === 'string' && deviceId.trim().length >= 8) {
    return `dev:${deviceId.trim()}`;
  }
  const ip = req.ip || req.connection.remoteAddress || '127.0.0.1';
  return typeof ipKeyGenerator === 'function' ? ipKeyGenerator(ip) : `ip:${ip}`;
};

const ytProxyLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  limit: 60, // 60 requests per minute per device/IP
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator,
  validate: { keyGeneratorIpFallback: false },
  message: { error: 'too_many_requests', message: 'API rate limit exceeded. Please slow down.' },
});

const extractionLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  limit: 15, // 15 extraction requests per minute per device/IP
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator,
  validate: { keyGeneratorIpFallback: false },
  message: { error: 'too_many_requests', message: 'Extraction rate limit exceeded. Please slow down.' },
});

class ConcurrencyQueue {
  constructor(maxConcurrent = 3, maxQueueSize = 10) {
    this.maxConcurrent = maxConcurrent;
    this.maxQueueSize = maxQueueSize;
    this.running = 0;
    this.queue = [];
  }

  get stats() {
    return {
      running: this.running,
      queued: this.queue.length,
      maxConcurrent: this.maxConcurrent,
      maxQueueSize: this.maxQueueSize,
    };
  }

  acquire() {
    if (this.running < this.maxConcurrent) {
      this.running++;
      return Promise.resolve(() => this.release());
    }

    if (this.queue.length >= this.maxQueueSize) {
      const err = new Error('Server is busy processing other extractions. Please retry in a few moments.');
      err.code = 'QUEUE_FULL';
      err.status = 429;
      return Promise.reject(err);
    }

    return new Promise((resolve, reject) => {
      this.queue.push({
        resolve: () => {
          this.running++;
          resolve(() => this.release());
        },
        reject,
      });
    });
  }

  release() {
    this.running = Math.max(0, this.running - 1);
    if (this.queue.length > 0 && this.running < this.maxConcurrent) {
      const next = this.queue.shift();
      if (next) next.resolve();
    }
  }
}

const extractQueue = new ConcurrencyQueue(3, 10);

async function fetchFromYouTube(endpoint, params = {}) {
  if (YT_API_KEYS.length === 0) {
    throw new Error('No YouTube API keys configured on backend (set YT_API_KEYS)');
  }

  let lastError = null;
  for (let attempt = 0; attempt < YT_API_KEYS.length; attempt++) {
    const key = YT_API_KEYS[currentKeyIndex];
    const url = new URL(`https://www.googleapis.com/youtube/v3/${endpoint}`);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null && v !== '') {
        url.searchParams.set(k, v);
      }
    }
    url.searchParams.set('key', key);

    try {
      const resp = await fetch(url.toString(), {
        headers: { 'Accept': 'application/json' }
      });
      const data = await resp.json();

      if (resp.status === 403 && data.error && data.error.errors && data.error.errors.some(e => e.reason === 'quotaExceeded')) {
        console.warn(`[yt-proxy] Key index ${currentKeyIndex} exceeded quota. Rotating key...`);
        currentKeyIndex = (currentKeyIndex + 1) % YT_API_KEYS.length;
        continue;
      }

      if (!resp.ok) {
        const msg = data.error ? data.error.message : `HTTP ${resp.status}`;
        throw new Error(msg);
      }

      return data;
    } catch (err) {
      lastError = err;
      if (err.message && err.message.includes('quotaExceeded')) {
        currentKeyIndex = (currentKeyIndex + 1) % YT_API_KEYS.length;
        continue;
      }
      throw err;
    }
  }

  throw lastError || new Error('All YouTube API keys exhausted');
}

// 1. Trending videos proxy (30 min cache)
app.get('/yt/trending', checkAuth, ytProxyLimiter, async (req, res) => {
  const regionCode = req.query.regionCode || 'US';
  const videoCategoryId = req.query.videoCategoryId || '0';
  const pageToken = req.query.pageToken || '';
  const maxResults = req.query.maxResults || '25';
  const cacheKey = `trending:${regionCode}:${videoCategoryId}:${pageToken}:${maxResults}`;

  const cached = ytCache.get(cacheKey);
  if (cached) {
    return res.json({ ...cached, _cached: true });
  }

  try {
    const data = await fetchFromYouTube('videos', {
      part: 'snippet,contentDetails,statistics',
      chart: 'mostPopular',
      regionCode,
      videoCategoryId: videoCategoryId !== '0' ? videoCategoryId : undefined,
      pageToken: pageToken || undefined,
      maxResults,
    });

    ytCache.set(cacheKey, data, 30 * 60 * 1000); // 30 minutes
    return res.json(data);
  } catch (err) {
    console.error('[yt-proxy] /yt/trending failed:', err.message);
    return res.status(502).json({ error: 'yt_api_failed', message: err.message });
  }
});

// 2. Video details proxy (24h cache)
app.get('/yt/videos', checkAuth, ytProxyLimiter, async (req, res) => {
  const id = req.query.id;
  if (!id) return res.status(400).json({ error: 'id query param is required' });

  const cacheKey = `videos:${id}`;
  const cached = ytCache.get(cacheKey);
  if (cached) {
    return res.json({ ...cached, _cached: true });
  }

  try {
    const data = await fetchFromYouTube('videos', {
      part: req.query.part || 'snippet,contentDetails,statistics',
      id,
    });

    ytCache.set(cacheKey, data, 24 * 60 * 60 * 1000); // 24 hours
    return res.json(data);
  } catch (err) {
    console.error('[yt-proxy] /yt/videos failed:', err.message);
    return res.status(502).json({ error: 'yt_api_failed', message: err.message });
  }
});

// 3. Channels proxy (7 days cache)
app.get('/yt/channels', checkAuth, ytProxyLimiter, async (req, res) => {
  const id = req.query.id;
  const forHandle = req.query.forHandle;
  if (!id && !forHandle) {
    return res.status(400).json({ error: 'id or forHandle query param is required' });
  }

  const cacheKey = `channels:${id || forHandle}`;
  const cached = ytCache.get(cacheKey);
  if (cached) {
    return res.json({ ...cached, _cached: true });
  }

  try {
    const params = {
      part: req.query.part || 'snippet,statistics,brandingSettings',
    };
    if (id) params.id = id;
    if (forHandle) params.forHandle = forHandle;

    const data = await fetchFromYouTube('channels', params);
    ytCache.set(cacheKey, data, 7 * 24 * 60 * 60 * 1000); // 7 days
    return res.json(data);
  } catch (err) {
    console.error('[yt-proxy] /yt/channels failed:', err.message);
    return res.status(502).json({ error: 'yt_api_failed', message: err.message });
  }
});

// Enhanced real health check (Stage 2)
let cachedHealthYtdlp = { version: null, error: null, checkedAt: 0 };

async function getYtdlpVersion() {
  const now = Date.now();
  if (now - cachedHealthYtdlp.checkedAt < 60 * 1000 && (cachedHealthYtdlp.version || cachedHealthYtdlp.error)) {
    return cachedHealthYtdlp;
  }
  return new Promise((resolve) => {
    execFile(YTDLP_PATH, ['--version'], { timeout: 10000 }, (err, stdout, stderr) => {
      if (err) {
        cachedHealthYtdlp = { version: null, error: (stderr || err.message || '').trim(), checkedAt: now };
      } else {
        cachedHealthYtdlp = { version: (stdout || '').trim(), error: null, checkedAt: now };
      }
      resolve(cachedHealthYtdlp);
    });
  });
}

app.get('/health', async (req, res) => {
  const ytdlpInfo = await getYtdlpVersion();
  const cookiesLoaded = !!COOKIES_PATH && fs.existsSync(COOKIES_PATH);
  const mem = process.memoryUsage();

  const healthData = {
    status: ytdlpInfo.error ? 'degraded' : 'ok',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    ytdlp: {
      path: YTDLP_PATH,
      version: ytdlpInfo.version,
      error: ytdlpInfo.error,
    },
    cookiesLoaded,
    queue: extractQueue.stats,
    cache: {
      ytItems: ytCache.map.size,
      extractionItems: extractionCache.map.size,
    },
    memory: {
      rssMb: Math.round(mem.rss / 1024 / 1024),
      heapUsedMb: Math.round(mem.heapUsed / 1024 / 1024),
    },
  };

  const statusCode = ytdlpInfo.error ? 503 : 200;
  return res.status(statusCode).json(healthData);
});

app.post('/update', requireAdminKey, (req, res) => {
  execFile(YTDLP_PATH, ['--update-to', 'nightly'], { timeout: 60000 }, (error, stdout, stderr) => {
    if (error) {
      console.error('[update] yt-dlp update to nightly failed:', error.message);
      return res.status(500).json({ error: error.message, stderr });
    }
    console.log('[update] yt-dlp update to nightly:', stdout.trim());
    return res.json({ status: 'ok', output: stdout.trim() || stderr.trim() });
  });
});

// Arguments are always built internally and never read from the request.
// yt-dlp has flags that run system commands (--exec among them), so echoing
// a caller-supplied argv into execFile turns a diagnostic route into remote
// command execution — which it was, reachable with any well-formed device
// id and no API key at all. Behind requireAdminKey for the same reason:
// stderr and the raw stdout snippet are operator information.
app.post('/debug-extract', requireAdminKey, extractionLimiter, async (req, res) => {
  const url = req.body && req.body.url;
  if (!url || typeof url !== 'string') {
    return res.status(400).json({ error: 'url is required' });
  }
  const args = ytdlpArgs(url);

  let release;
  try {
    release = await extractQueue.acquire();
  } catch (queueErr) {
    if (queueErr.code === 'QUEUE_FULL') {
      res.setHeader('Retry-After', '5');
      return res.status(429).json({ error: 'server_busy', message: queueErr.message });
    }
    return res.status(500).json({ error: 'queue_error', message: queueErr.message });
  }

  execFile(YTDLP_PATH, args, { maxBuffer: 1024 * 1024 * 25, timeout: 30000 }, (err, stdout, stderr) => {
    release();
    let parsedFormatsCount = 0;
    try {
      const lines = stdout.trim().split('\n').filter(Boolean);
      const json = JSON.parse(lines[lines.length - 1]);
      parsedFormatsCount = json.formats ? json.formats.length : 0;
    } catch(e) {}
    res.json({
      exitCode: err ? err.code : 0,
      error: err ? err.message : null,
      args,
      formatsCount: parsedFormatsCount,
      stderr,
      stdoutLength: (stdout || '').length,
      stdoutSnippet: (stdout || '').substring(0, 500),
    });
  });
});

app.post('/extract', checkAuth, extractionLimiter, async (req, res) => {
  const url = req.body && req.body.url;
  if (!url || typeof url !== 'string') {
    return res.status(400).json({ error: 'url is required' });
  }

  // 1. Check extraction cache (Stage 2)
  const cached = extractionCache.get(url);
  if (cached) {
    return res.json({ ...cached, _cached: true });
  }

  // 2. Concurrency limit & queue (Stage 2)
  let release;
  try {
    release = await extractQueue.acquire();
  } catch (queueErr) {
    if (queueErr.code === 'QUEUE_FULL') {
      res.setHeader('Retry-After', '5');
      return res.status(429).json({
        error: 'server_busy',
        message: queueErr.message,
      });
    }
    return res.status(500).json({ error: 'queue_error', message: queueErr.message });
  }

  const args = ytdlpArgs(url);

  execFile(
    YTDLP_PATH,
    args,
    { maxBuffer: 1024 * 1024 * 25, timeout: 45000 },
    async (err, stdout, stderr) => {
      try {
        if (err) {
          const message = (stderr || err.message || '').toString();
          console.error(`[extract] yt-dlp failed for ${url}:`, message);

          // Last-resort fallback for Instagram photo posts
          if (url.includes('instagram.com') && /no video in this post/i.test(message)) {
            const photoJson = await tryExtractInstagramPhoto(url);
            if (photoJson) {
              extractionCache.set(url, photoJson, EXTRACTION_CACHE_TTL_MS);
              return res.json(photoJson);
            }
          }

          // Fallback to @distube/ytdl-core for YouTube
          if (isYoutubeUrl(url)) {
            const ytdlJson = await tryExtractViaYtdlCore(url);
            if (ytdlJson) {
              extractionCache.set(url, ytdlJson, EXTRACTION_CACHE_TTL_MS);
              return res.json(ytdlJson);
            }
          }

          return res.status(502).json({
            error: 'extraction_failed',
            message: message.slice(-1000),
          });
        }

        const lines = stdout.trim().split('\n').filter(Boolean);
        const json = JSON.parse(lines[lines.length - 1]);

        // If YouTube returned 0 formats, try ytdl-core fallback
        if (!json.formats || json.formats.length === 0) {
          if (isYoutubeUrl(url)) {
            console.log('[extract] YouTube video yielded 0 formats from yt-dlp, attempting fallback via ytdl-core...');
            const ytdlJson = await tryExtractViaYtdlCore(url);
            if (ytdlJson && ytdlJson.formats && ytdlJson.formats.length > 0) {
              extractionCache.set(url, ytdlJson, EXTRACTION_CACHE_TTL_MS);
              return res.json(ytdlJson);
            }
            return res.status(502).json({
              error: 'extraction_failed',
              message: 'YouTube video yielded 0 formats from yt-dlp and fallback failed',
            });
          }
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

        // Cache valid extraction result (2 hours TTL)
        extractionCache.set(url, json, EXTRACTION_CACHE_TTL_MS);
        return res.json(json);
      } catch (parseErr) {
        console.error('[extract] failed to parse yt-dlp output:', parseErr.message);

        if (url.includes('instagram.com')) {
          const photoJson = await tryExtractInstagramPhoto(url);
          if (photoJson) {
            extractionCache.set(url, photoJson, EXTRACTION_CACHE_TTL_MS);
            return res.json(photoJson);
          }
        }

        return res.status(502).json({ error: 'parse_failed', message: parseErr.message });
      } finally {
        release();
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
    '--js-runtimes', 'deno,node',
    '--remote-components', 'ejs:github',
  ];
  if (YTDLP_PLUGIN_DIRS) {
    args.push('--plugin-dirs', YTDLP_PLUGIN_DIRS);
  }
  if (isYoutubeUrl(url)) {
    if (YTDLP_PLUGIN_DIRS) {
      args.push('--extractor-args', `youtubepot-bgutilhttp:base_url=${BGUTIL_BASE_URL}`);
    }
    if (PLAYER_CLIENT) {
      args.push('--extractor-args', `youtube:player_client=${PLAYER_CLIENT}`);
    }
    if (COOKIES_PATH) {
      args.push('--cookies', COOKIES_PATH);
    }
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
  execFile(YTDLP_PATH, ['--update-to', 'nightly'], { timeout: 60000 }, (error, stdout, stderr) => {
    if (error) {
      console.error('[startup] yt-dlp nightly self-update failed (continuing with existing binary):', error.message);
      return;
    }
    console.log('[startup] yt-dlp nightly self-update:', stdout.trim() || stderr.trim());
  });
}

selfUpdateYtdlp();
startBgutilPotServer();

app.listen(PORT, () => {
  console.log(`Arak extraction server listening on port ${PORT}`);
});
