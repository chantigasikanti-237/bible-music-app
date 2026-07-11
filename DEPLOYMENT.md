# Deployment Guide — Bible App (Free-Tier Stack)

Real architecture, 3 moving pieces:

```
Cloudflare (DNS + your domain)
        │
        ▼
Cloudflare Pages ──(proxies /api/* )──▶  Render.com ──▶ MongoDB Atlas
(bible-ui, static build)                 (bible-backend,   (free M0 cluster)
        │                                 Node/Express)
        ▼
Flutter app (WebView loads your Cloudflare Pages domain)
```

Why this stack: Cloudflare's edge (Pages/Workers) does **not** run a persistent Express server with MongoDB/Redis connections — that needs a real always-on (or on-demand) Node process. So: static frontend on Cloudflare Pages, backend on Render, DB on Atlas, DNS on Cloudflare tying it together. Redis is **not required** — `bible-backend/src/config/redis.js` already degrades gracefully (rate limiting falls back to in-memory) when `REDIS_URL` is empty. Skip it for a free deploy.

Total cost: **$0**, with one caveat — Render's free tier spins the backend down after ~15 min idle; the next request takes ~30-50s to cold-start. Fine for personal use/testing; upgrade to a paid Render instance ($7/mo) later if that's not acceptable.

---

## Phase 0 — Accounts needed (all free)

- [Cloudflare](https://cloudflare.com) — you already have this + a domain.
- [MongoDB Atlas](https://mongodb.com/cloud/atlas) — free M0 cluster.
- [Render](https://render.com) — free Web Service.
- [GitHub](https://github.com) — Render and Cloudflare Pages both deploy from a git repo. Push this project there if it isn't already.

---

## Phase 1 — MongoDB Atlas (database)

1. Create a free account → **Build a Database** → choose **M0 Free**.
2. Create a database user (username + password — save these).
3. **Network Access** → Add IP Address → **Allow Access from Anywhere** (`0.0.0.0/0`). Render's IPs aren't static on the free tier, so this is required.
4. **Connect** → **Drivers** → copy the connection string. It looks like:
   ```
   mongodb+srv://<user>:<password>@cluster0.xxxxx.mongodb.net/bible_app?retryWrites=true&w=majority
   ```
   This is your `MONGO_URI`.

---

## Phase 2 — Backend on Render

1. Push `bible-backend/` to a GitHub repo (or use the existing one, pointing Render at the `bible-backend` subfolder as the root directory).
2. Render dashboard → **New +** → **Web Service** → connect your repo.
3. Settings:
   - **Root Directory**: `bible-backend`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start` (runs `node server.js`)
   - **Instance Type**: Free
4. **Environment Variables** (Render dashboard → Environment tab) — set every one of these:

   | Key | Value |
   |---|---|
   | `NODE_ENV` | `production` |
   | `PORT` | `5000` (Render sets its own `$PORT`, but the app reads `process.env.PORT`, so this is fine as a default) |
   | `MONGO_URI` | from Phase 1 |
   | `JWT_SECRET` | generate one: `openssl rand -hex 32` |
   | `JWT_ISSUER` | `bible-backend` |
   | `JWT_AUDIENCE` | `bible-app` |
   | `JWT_ACCESS_EXPIRES_IN` | `15m` |
   | `JWT_REFRESH_EXPIRES_IN` | `30d` |
   | `PASSWORD_RESET_TTL_MINUTES` | `15` |
   | `EMAIL_VERIFICATION_TTL_MINUTES` | `60` |
   | `BCRYPT_SALT_ROUNDS` | `12` |
   | `REDIS_URL` | *(leave empty — optional, skipped in this guide)* |
   | `CORS_ORIGIN` | `https://yourdomain.com` (your real domain from Phase 4 — not localhost) |
   | `AUTH_COOKIE_NAME` | `refresh_token` |
   | `AUTH_COOKIE_DOMAIN` | `yourdomain.com` |
   | `AUTH_COOKIE_PATH` | `/api/auth` |
   | `AUTH_COOKIE_SECURE` | `true` — **must** be true in production (HTTPS-only cookie) |
   | `AUTH_COOKIE_SAME_SITE` | `strict` |
   | `TRUST_PROXY` | `true` — Render sits behind its own proxy; needed so client IP / rate-limiting works correctly |
   | `EXPOSE_DEBUG_TOKENS` | `false` |
   | `MFA_ISSUER` | `Bible App` |
   | `YOUVERSION_APP_KEY` | your YouVersion API key |
   | `YOUTUBE_API_KEY` | your YouTube Data API v3 key |
   | `CHAPTER_CACHE_TTL_SECONDS` | `3600` |
   | `LOG_LEVEL` | `info` |
   | `SMTP_HOST` | `smtp.gmail.com` (or your provider) |
   | `SMTP_PORT` | `587` |
   | `SMTP_SECURE` | `false` |
   | `SMTP_USER` | your email |
   | `SMTP_PASS` | app password (not your real password — generate one in Google Account → Security → App Passwords) |
   | `SMTP_FROM` | `"Bible App <youremail@gmail.com>"` |

5. Deploy. Render gives you a URL like `https://bible-backend-xxxx.onrender.com`. Test it:
   ```bash
   curl https://bible-backend-xxxx.onrender.com/api/v1/bibles/111/books
   ```
   Should return real JSON, not an error.

---

## Phase 3 — Frontend on Cloudflare Pages

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git** → pick your repo.
2. Build settings:
   - **Root directory**: `bible-ui`
   - **Build command**: `npm run build`
   - **Build output directory**: `dist`
3. Add a `_redirects` file so relative `/api/...` calls (used everywhere in the React code — `fetch('/api/v1/...')` etc.) transparently reach your Render backend, with **zero code changes**:

   Create `bible-ui/public/_redirects`:
   ```
   /api/*  https://bible-backend-xxxx.onrender.com/api/:splat  200
   ```
   (Replace with your actual Render URL from Phase 2.) Vite copies everything in `public/` into `dist/` untouched, so this file ships as-is.

   This is a *proxy* rewrite (status 200, not a redirect) — the browser never sees the Render domain, it thinks it's talking to itself. That also sidesteps CORS entirely for browser traffic, and keeps the auth cookie same-origin (needed since `AUTH_COOKIE_SAME_SITE=strict`).

4. Deploy. Cloudflare gives you `https://your-project.pages.dev` — test the whole thing works there before attaching your real domain.

---

## Phase 4 — Point your Cloudflare domain at it

1. In the same Pages project → **Custom domains** → **Add a domain** → enter your domain (or a subdomain like `app.yourdomain.com`).
2. Cloudflare auto-creates the DNS record (CNAME to your `.pages.dev`) since the domain's already on your Cloudflare account. SSL cert issues automatically within a few minutes.
3. Go back and update `CORS_ORIGIN` and `AUTH_COOKIE_DOMAIN` in Render's env vars (Phase 2) to match this final domain exactly, then redeploy the backend.

---

## Phase 5 — Point the Flutter app at production

Right now `lib/screens/web_app_screen.dart` hardcodes:
```dart
..loadRequest(Uri.parse('http://localhost:3000'));
```
Change to your real domain:
```dart
..loadRequest(Uri.parse('https://yourdomain.com'));
```
Then build a release APK:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. (Signing config for Play Store distribution is a separate step, not covered here — ask if you need it.)

---

## Verification checklist

- [ ] `curl https://yourdomain.com/api/v1/bibles/111/books` (through the Pages proxy) returns real data
- [ ] Register a new account on the deployed site → verification email actually arrives
- [ ] Login persists (refresh cookie working — check DevTools → Application → Cookies, should be `Secure`, `HttpOnly`)
- [ ] Bible download / music download work over the real domain
- [ ] APK installed on a phone with wifi/mobile data (no USB tunnel) loads the app correctly

## Known free-tier limits

- Render free web service **sleeps after ~15 min idle**, ~30-50s cold start on next request.
- MongoDB Atlas M0: 512MB storage cap — fine for text/user data, but do **not** rely on it for large audio blobs (the app already avoids this — audio caching is client-side IndexedDB, not server-stored).
- No Redis: rate limiting is in-memory per Render instance — resets on every cold-start/redeploy. Acceptable for low traffic; revisit if you scale up.
