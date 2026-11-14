---
tags: [architecture, environments]
updated: 2026-11-15
---

# The environments model — one axis, any cluster shape

## The ruling (2026-11-13 restructure, converged 2026-11-14)

The estate has THREE environments under `vortex/environments/`:

| tree | nameSuffix | label omicron/env | namespace stance |
| :-- | :-- | :-- | :-- |
| foundation | — (explicit plain names) | `shared` | owns its platform ns + the co-tenant app ns (lumen-admin) |
| staging | `-staging` | `staging` | co-tenants the app ns (env-restricted selectors) |
| production | `-production` | `production` | co-tenants the app ns (env-restricted selectors) |

The trees are ENVIRONMENT files, not cluster files: one cluster can run
foundation+production, foundation+staging, or all three co-tenanted. **Moving
an environment to another cluster is repainting the destination in its hub CR
— zero manifest edits** (plus seeding a vault there).

## Shared-by-design services (foundation)

- **ONE Patroni cluster** (ns `db`) declaring THREE logical databases —
  `lumen_admin` / `lumen_staging` / `lumen_production` — each consumed via
  the `LUMEN_DB_URL` seeded behind its Bao path (`kv/lumen/shared` /
  `kv/lumen/staging` / `kv/lumen/production`).
- **ONE Meilisearch** (ns `search`); environments coexist as per-env INDEX
  names (`LUMEN_MEILI_INDEX_*` are VALUES behind each cms overlay's Bao path).
- ONE each: openbao, external-secrets, secrets-plane, observability (whose
  Grafana door `anor.gofar.id` is production-owned DNS hosted foundation-side).

## The naming contract (load-bearing)

`nameSuffix` rewrites `metadata.name` ONLY. Every name-bearing reference is
therefore authored final in files the overlay owns, or JSON6902-patched.
Vault values must name the suffixed Services (production
`API_BASE` → `http://lumen-http-server-production.lumen.svc.cluster.local`;
staging → the `-staging` twin). The full contract with its exact strings:
[vortex AGENTS.md §3](https://github.com/kanatabi/vortex/blob/main/AGENTS.md).

## Why the base/env split is absolute

- Bases (`bases/*`) are suffix-free, env-free, cluster-shape-free — and
  **ESO-free and pin-free**: a base `images:` stanza outranks every env
  overlay (kustomize override order, fixture-proven 2026-11-13), so env trees
  are the ONLY version homes. A base image pin would silently win over every
  bump.
- Placement is explicit per deployment (`node-pool` affinity + hostname
  anti-affinity for 2-replica apps); `components/single-node` collapses pools
  for the one-VPS reality without touching env trees.

## The hosts (who answers where)

`gofar.id` + `www` (production, earendil) · `console.gofar.id` (production,
mellon) · `anor.gofar.id` (Grafana door) · `img.gofar.id` (R2, bucket-side) ·
staging twins `staging.gofar.id` / `staging-console.gofar.id` (DNS + seeds
land when staging goes live). Details:
[network-and-doors.md](network-and-doors.md).
