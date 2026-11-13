---
tags: [runbook, backup, dr]
updated: 2026-11-13
---

# 10 · Backup & Recovery — the promise, and how to keep it

> **Why this chapter:** a backup you have never restored is a rumor. The
> estate's rule: back up nightly, encrypt before upload, verify monthly by
> actually restoring, and keep the *keys to the backups* offline with the
> vault keys — because the backup bucket without its password is a brick,
> and with it is everything.

## 1. What gets backed up — and what doesn't (the honest table)

| Thing | Reconstructable without a backup? | Plan |
|---|---|---|
| Postgres data (posts, users, media DB pointers) | ❌ **the only copy** | nightly `pg_dump` → restic |
| OpenBao `/data` (every secret ever seeded) | ❌ | restic the PVC dir, *after* a snapshot-consistency pause (see 3c) |
| Media photos | ✅ already offsite (R2) — but the **database** rows linking them are the fragile memory (ch.06) | covered by the DB backup |
| Meilisearch index | ✅ rebuilds from Postgres (the A11 recipe: wipe + `cmd/seed` reconcile) | not backed up |
| K8s objects, all YAML, images | ✅ Git = truth, ghcr = tags | GitHub + GitLab mirror already do it |
| TLS certs | ✅ re-issued in minutes | not backed up |
| Unseal keys · restic password · root tokens | ❌❌ **NOT in any backup** — these unlock backups | *offline: password manager + paper, separate physical places* |

## 2. Where: Cloudflare R2, its own bucket (never the media bucket)

`restic` (installed on the server; toolbelt in ch.01) speaks S3 → R2. One
bucket per purpose = one accident can't hit both your photos and your
photos-about-the-past.

```bash
# on the server, once:
restic init --repo s3:s3.amazonaws.com/<backup-bucket-name> \
  --repo-endpoint https://<acct>.r2.cloudflarestorage.com --backend-retries 3
# asks for the repo PASSWORD — that's the offline-vault item; restic
# encrypts client-side, R2 never sees plaintext, and Cloudflare support
# couldn't read your backups either. That's the point.
```

## 3. The nightly loop (systemd, two timers)

### 3a. Database dump → stage dir → snapshot

```bash
# /etc/cron.d/omicron-backup  (or systemd timer; cron shown for clarity)
02 3 * * * root kubectl -n db exec lumen-pg-0 -- pg_dumpall -U postgres \
  > /srv/backup/pg/dump-$(date +\%F).sql && \
  restic -r s3:... backup /srv/backup/pg --tag pg
03 3 * * * root restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12
04 3 * * * root restic check   # and echo a metric line for the ch.09 alert
```

### 3b. Vault data

```bash
05 3 * * * root kubectl -n secrets exec openbao-0 -- bao snapshot save /tmp/snap 2>/dev/null; \
  kubectl cp secrets/openbao-0:/tmp/snap /srv/backup/bao/snapshot && \
  restic -r s3:... backup /srv/backup/bao --tag bao
```

> **Why a snapshot API, not rsync of the PVC dir:** copying a live database
> directory gets you a backup that restores to *corruption* — the classic
> half-written-file surprise. Bao's snapshot is consistent by design.

### 3c. Retention reality

7 daily / 4 weekly / 12 monthly ≈ a year of "what Tuesday looked like" in
a few gigabytes. Restic dedups; blog data is tiny; disk is the least of
your worries.

## 4. The monthly drill (this is the actual job; the rest is plumbing)

First Saturday, 20 minutes, **on the rehearsal VM** (never prod):

1. `restic restore latest --target /tmp/verify` on the VM.
2. Feed `dump-*.sql` into a scratch Postgres pod; `psql -c 'select
   count(*) from posts'` → matches anor's number. **This is the only
   sentence that proves the backup works.**
3. Note the Bao snapshot restores too (`bao operator migrate -command …`
   or straight-into-datadir on a throwaway instance) + remember: restoring
   the vault = you ALSO need the offline unseal keys → drill both together
   or you've drilled half the plane.

## 5. Total-loss runbook (the "VPS burned down" sequence)

1. New VPS → **this folder, in order**: 02 → 03 → (buy time: 04 while
   anything is still pointed elsewhere) → 07.
2. Restore Bao: fresh vault pod → restore snapshot → unseal (offline keys)
   → seed state = whatever was backed up; re-issue AppRole creds only if
   the vault was lost, not restored (ch.05).
3. Restore Postgres: Patroni comes up empty → restore `pg_dumpall` into
   the primary → ESO already syncing (its values came from step 2).
4. Argo reconciles the rest; images live in ghcr, media in R2, search
   reindexes (ch.05's A11 recipe / 09).
5. RTO honesty: with these chapters, a rebuild is an afternoon — the long
   tail is DNS TTLs and *your own memory of order*, which is why this
   folder exists and why the drill is monthly.

## 6. Provider snapshots ≠ backup (why both exist)

Contabo/sumopod snapshots are a great *whole-machine* shortcut and a lousy
strategy: same vendor, same building, often same firewall. **R2/restic is
the encrypted off-vendor copy; snapshots (if you enable them) are the
fast local undo.** If forced to pick one, pick this chapter's loop.

Next → [11 Access from Laptop](11-access.md)
