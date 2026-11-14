---
tags: [architecture, network, doors]
updated: 2026-11-15
---

# Network and doors — what is public, what is never

## The non-negotiable (INFRA §2, amended 2026-11-08; dashboard door 2026-11-13)

**Two sanctioned public surfaces + one dashboard door; never a public API.**

| Door | Serves | Posture |
| :-- | :-- | :-- |
| `gofar.id` + `www.gofar.id` | earendil (content reads) | public, unauthenticated reads; cutover verified live 2026-11-11 (`ainurrofiq.com` 301s in; www production-only by ruling) |
| `console.gofar.id` | mellon (authenticated writes + the Bao plane) | public but TLS-only posture: Traefik console middlewares (headers/HSTS/rate-limit), JWT sessions minted ONLY by lumen-admin with `tv`-revocation; service stays ClusterIP; HUMAN-GATE #10 checklist before DNS flips; port-forward = break-glass |
| `anor.gofar.id` | Grafana dashboards (per-env filtered) | layered: proxied DNS → managed challenge → Access allowlist → Grafana OIDC (Access = the identity; break-glass admin lives on the tunnel path) |
| `img.gofar.id` | R2 bucket custom domain | bucket-side, outside ACME (GATE #9 closed 2026-11-13) |
| staging twins | earendil-staging / mellon-staging | contractual (`staging.gofar.id`, `staging-console.gofar.id`); DNS + seeds land when staging goes live |

**Cluster-internal, ever:** lumen (both roles), Meilisearch, OpenBao, ESO, the
K8s API (`:6443`), node SSH (mesh-only, port 22 closed publicly).

## How browser→API traffic actually flows

The browser never calls lumen directly — there is literally no route:

1. earendil: browser GET `/api/*` → same-origin SSR proxy
   (`src/routes/api/[...path]/+server.ts`) → `API_BASE` (internal service DNS).
   Search suggest is the ONLY client-side API call.
2. mellon: the portal relay (`src/lib/api/routing.ts`) sends session/users/
   setup/bao to `ADMIN_URL` (lumen-admin) and content + `/api` to `CMS_URL`
   (this env's cms); unknown paths throw — no default.
3. Everything else (ESO→Bao, jobs→DB) is in-cluster service DNS.

A failing direct API call is fixed by the proxy or the seeded env — never by
exposing the API. This is the estate's most classic "tempting bug".

## TLS & DNS posture

- **DNS-01** via the shared ClusterIssuer (works from any cluster — the
  self-signed rehearsal component died with the rehearsal trees; staging
  rides the SAME issuer).
- The zone lives on **Cloudflare** (proxy + ACME; `ainurrofiq.com` 301s in).
  Current procedure + record table: runbook/07 Act 1.
- Certificates are created in-cluster by cert-manager and referenced — never
  stored in Git.

## The admin plane

The mesh (admin laptop→cluster) is **Tailscale** since 2026-11-13 (replacing
the NetBird-agent assumption: open-source client, zero-ops control plane,
Headscale as escape hatch). Node-to-node traffic rides the provider private
plane (Path A) or the mesh (Path B) — the full decision matrix is
[`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) §2/§3.
