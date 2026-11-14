---
tags: [architecture, overview]
updated: 2026-11-15
---

# System overview — the estate end-to-end

## The shape (2026-11-15)

A personal blog on a small Kubernetes estate, built from five repos plus one
decision record and one runbook:

```
            the public internet
        │ gofar.id · www · console · anor
        ▼
   [ Traefik edge + cert-manager ]      ← edge worker (DNS-01 TLS)
   ┌──────────────────┬─────────────────┐
   │ earendil (SSR×2) │ mellon (portal) │   ← app pods, co-tenant ns
   └───────┬──────────┴───────┬─────────┘
           │ API_BASE / relays│ ADMIN_URL / CMS_URL
           ▼                  ▼
   [ lumen cms ×2 envs ]  [ lumen-admin ×1 ]   ← cluster-internal, ever
           │                  │
   Meilisearch · Patroni (3 logical DBs) · OpenBao · ESO
                          │
        Grafana · VictoriaMetrics · Loki · Alloy (worker DaemonSet)
```

## The cast

- **earendil** renders the blog; browsers only ever see it and its
  same-origin `/api/*` proxy.
- **lumen** comes in role flavors (role split 2026-11-13): `cms` per
  environment serves content; ONE `admin` control plane owns sessions, users,
  TOFU, and the Bao relay. No ingress, ever.
- **mellon** is the human's control surface — UI-only, no credentials, a
  routing table that decides which lumen answers (`mellon` DESIGN §2).
- **vortex** declares all of the above; Argo CD (self-hosted from
  `platform/argocd/`) applies it.
- **anvil** is how changes get RELEASED: approval-gated, tag-triggered,
  environment-laddered.
- **OpenBao** holds every value; **ESO** renders them; nothing sensitive
  touches Git.

## The three moves everything else serves

1. **A post gets published** — mellon's editor → lumen admin write path →
   §2 publish transaction (derivations server-owned) → Meilisearch index job
   → earendil serves it.
2. **An image gets stored** — upload relay → S3-protocol object storage + CDN
   (D1 resolved, revised 2026-11-08); content-hash filenames make
   `immutable` safe.
3. **The estate gets a new version** — merge → three waiting bump jobs → one
   human approval → tag → image → deploy-plan evidence → environment ladder
   → bump PR → Argo sync. See [releases-and-ci.md](releases-and-ci.md).

## Reading order for depth

1. [what-is-omicron.md](../what-is-omicron.md) — the cast
2. The root [`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) — the WHY
   (phases, budgets, secrets design)
3. [gitops.md](gitops.md) → [secrets-and-vault.md](secrets-and-vault.md) →
   the rest of this folder
4. [`runbook/`](../../runbook/00-overview.md) — the HOW, milestone-ordered
