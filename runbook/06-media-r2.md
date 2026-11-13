---
tags: [runbook, media]
updated: 2026-11-13
---

# 06 · Media on Cloudflare R2 — how photos arrive and get seen

> **Why R2:** photos are the only heavy thing a blog has. R2 = S3-compatible
> object storage **with zero download fees**, served through Cloudflare's
> CDN for free. Same vendor as DNS/guard/backups — one bill, one console,
> one account to lose instead of three. (Owner ruling 2026-11-13, closes
> the estate's GATE #9.)

## 1. The shape of an upload (layman version)

```
you (portal, logged in) → mellon relays → lumen validates (size/type) 
   → lumen PUTs bytes to the PRIVATE R2 bucket → post stores the URL
readers → https://img.gofar.id/<path>.jpg → Cloudflare CDN cache → (miss) → R2
```

Your server never stores photos, visitors never hit your server for them,
and nobody can list the bucket — the *domain* is the only public face.

## 2. One-time setup (dashboard clicks, ~10 min)

1. R2 → **Create bucket** `omicron-media` (private; not the backups bucket —
   one bucket per purpose, different lifecycles, different blast radius).
2. R2 → bucket → **Manage Domain Bindings → Connect a custom domain**:
   `img.gofar.id` (this creates the 🟠 DNS record for you — ch.04's table
   row appears). Enable "Public Access via Domain Bindings only" — the
   bucket *stays* unlistable.
3. R2 → **Manage R2 API Tokens** → create, **Object Read & Write**, scoped
   to `omicron-media` only. Copy the Access Key/Secret NOW into
   `kv/lumen/production` (ch.05 §4 keys `LUMEN_MEDIA_ACCESS_KEY/_SECRET_KEY`).
   > **Why scoped:** a bucket-scoped token can replace your photos; it
   > cannot touch DNS, buckets, or anything else in the account.
4. `LUMEN_MEDIA_FORCE_PATH=false` — R2 speaks virtual-host style fine
   (MinIO-era tutorials will tell you "true"; R2 says no need).

Nothing else. The lumen side already exists (M5 shipped the relay: config
binds `LUMEN_MEDIA_*`, `internal/media` speaks S3 with aws-sdk-go-v2); the
vortex production ES already declares the family — `kustomize edit`-style
PR `94db3ca`. **No code, no new buckets-in-code:** `media_create_bucket`
stays dev-only on purpose (prod never auto-creates cloud resources).

## 3. Maintenance & verification

- **The 30-second smoke test** (monthly, ch.12): portal → upload a tiny png
  → find its `img.gofar.id` URL → `curl -sI` shows `cf-cache-status: HIT`
  or `MISS` (both fine; absence of either = not behind CDN) → delete.
- **Cost truth:** 10 GB + 1M Class-B ops/month free tier; a blog lives at
  $0 unless it gets *famous* famous. Watch the one stat that could grow:
  storage bytes (alert at 5 GB in ch.09 if you like a number).
- **Backups:** media already sits in someone else's durable cloud — the
  important copy is the **database** (it knows which object belongs to
  which post). Cross-bucket rule restated in ch.10: media bucket ≠ backup
  bucket, backups of *config* ride Git, backups of *database* ride restic.

## 4. The upgrade nobody needs yet: **presigned uploads**

*(requested as a written option — this is where it gets explained so future
you can decide with the facts.)*

**What it is:** instead of lumen relaying bytes, it issues a short-lived
signed *ticket* and the browser uploads **straight to R2**.

| | Relay (today) | Presigned (maybe) |
|---|---|---|
| Path | browser → lumen → R2 | browser → R2 |
| Server load | bytes pass through your node | your node moves *zero* bytes |
| Big files / many uploads | the pain point (RAM/bandwidth of a $12 box) | the reason to switch |
| Rules enforcement | lumen validates everything, one door | ticket is a *blank check up to its limits* → needs an extra "confirm" step after upload so the BE still curates what becomes a post |
| Extra pieces | — | bucket CORS config, size/type policy baked into tickets, orphan-cleanup for abandoned uploads, one more secret-shaped thing to think about |

**Trigger sentence to remember:** *"the day originals get big (RAW photos,
video stills, gallery-heavy posts), this becomes a PR-shaped upgrade"* —
sign endpoint + confirm step + CORS. Not before. Keeping it simple *is*
the plan, and the plan writes its upgrade path down so simplicity is a
choice, not a hole.

Next → [07 GitOps & Argo](07-gitops-argo.md)
