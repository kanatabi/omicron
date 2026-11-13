---
tags: [runbook, index]
updated: 2026-11-13
status: draft — written from rehearsed knowledge (minikube rehearsal era: see
  [[../RUNBOOK|archived rehearsal log]]); every VPS step is only PROVEN once
  walked, and each chapter marks its own proof state.
---

# 00 · Overview — what we're building and why

**TL;DR:** one small Linux server (~$12/month) runs our entire blog system.
You push code to GitHub → you click "release it" → new versions appear on the
internet automatically. Photos live on Cloudflare R2, dashboards at
`anor.gofar.id`, secrets in an encrypted vault inside the cluster, and all
doors face the world *through Cloudflare*, never directly.

## In words a human can hold

- **Kubernetes (k3s)** is a traffic controller for little programs ("pods").
  k3s is a complete Kubernetes that fits in one package — we run it on the
  one server.
- **GitOps** means: the folder of YAML files (`vortex` repo) *is* the truth of
  what runs. A robot (Argo CD) watches that folder and constantly nudges the
  server to look like it. You never change the server by hand — you change
  the folder, the robot copies.
- **The secrets vault (OpenBao)** holds passwords *inside* the cluster so they
  never appear in any repo. Another robot (ESO) copies them from vault into
  the places programs look.
- **Cloudflare** sits in front of every public door: hides the server's real
  address, absorbs floods (DDoS), proves visitors are human ("checking your
  browser"), checks the dashboard's guest list (Access), and hosts photos and
  backups (R2 buckets).

```
 GitHub (code + vortex YAML)          Cloudflare edge
   │ merge→gates→approve-release        blog · console · anor · img (all 🟠 proxied)
   ▼                                       │  only Cloudflare IPs reach:
 Argo CD ──watches──▶ the ONE k3s server ◀─┘  ports 80/443
   pods: earendil blog · mellon portal · lumen API · Postgres · search · vault(OpenBao)
   images: ghcr.io/kanatabi/<app>:v1.2.3 (released tags ONLY)
   photos: lumen → R2 bucket → img.gofar.id (CDN) · backups: restic → R2
 your laptop → SSH tunnels (+ optional Tailscale) for anything admin
```

## The folder — reading order

| # | Chapter | One line |
|---|---|---|
| 01 | [Prerequisites](01-prerequisites.md) | what to buy/prepare and why each |
| 02 | [VPS Hardening](02-security.md) | locks on the front door before anything else |
| 03 | [K3s](03-k3s.md) | the cluster itself (same commands VM & VPS) |
| 04 | [DNS, TLS & Cloudflare](04-dns-tls.md) | records, challenges, certificates forever |
| 05 | [Secrets Vault](05-secrets-vault.md) | OpenBao + ESO: values live only here |
| 06 | [Media on R2](06-media-r2.md) | photo upload flow + the presigned option |
| 07 | [GitOps & Argo](07-gitops-argo.md) | how software arrives on the server |
| 08 | [Releases](08-releases.md) | the ritual: bump approval → evidence → deploy gate |
| 09 | [Observability](09-observability.md) | Grafana/VictoriaMetrics/Loki/Alloy + family lab |
| 10 | [Backup & Recovery](10-backup-dr.md) | what's backed up, where, and proving it works |
| 11 | [Access from Laptop](11-access.md) | tunnels, Tailscale, kubectl, Argo UI |
| 12 | [Operations Calendar](12-operations.md) | weekly/monthly/quarterly + incident cards |
| 13 | [References](13-references.md) | official docs for every claim |

**Order matters**: 01→02→03 before anything public exists; 04 and 05 can be
prepared in parallel with 03; the estate only goes live after 02+04 are green.

## Decisions already made (owner rulings — don't re-litigate in a hurry)

| Question | Settled | Where |
|---|---|---|
| Where | one VPS, 4 CPU/8 GB min (Contabo first; sumopod/helipod valid; provider-neutral commands) | 01 |
| How does software ship | released `vX.Y.Z` tags only; humans approve bump + deploy; merge never deploys | 08 + root AGENTS §4 |
| Secrets | OpenBao only; Git templates only | 05 |
| Public guard | Cloudflare proxy + managed challenges; Access for the dashboard guest list | 04 |
| Dashboard door | `anor.gofar.id` (alt name `beacon.gofar.id` — swap in the 4 places listed in 04) | 04, 09 |
| Photos | Cloudflare R2 + `img.gofar.id` CDN, uploaded through lumen (relay, not presigned — yet) | 06 |
| Backups | restic → Cloudflare R2 (own bucket), monthly restore drill is the real task | 10 |
| Admin road | SSH tunnels day one; Tailscale optional chapter (replaced INFRA's NetBird plan 2026-11-13) | 11 |

## Obsidian note

This folder IS the doc set — open it as a vault (or a subfolder of one).
Links are relative, so everything works in Obsidian *and* on GitHub.
Obsidian's `.obsidian/` settings stay gitignored; the prose stays clean.
