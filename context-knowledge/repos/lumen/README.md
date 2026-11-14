---
tags: [lumen, backend]
updated: 2026-11-15
---

# lumen — the REST backend

Live Go service (M1–M6 merged 2026-11-09; secrets control plane 2026-11-13):
the content API (Meilisearch search + Patroni Postgres), the admin API
(sessions, publish unit of work), the media upload relay (S3-protocol), and
the OpenBao passthrough (`/admin/bao/*`).

## Its own docs (authoritative for this repo)

- [AGENTS.md](https://github.com/kanatabi/lumen/blob/main/AGENTS.md) —
  refreshed 2026-11-15: live M1–M6 estate, real-first rule, role split
  (admin/cms/all), the test battery, where things live.
- [DESIGN.md](https://github.com/kanatabi/lumen/blob/main/DESIGN.md) — §1 the
  wire contract (mirrors earendil's `BlogApi`), §8 admin, §9 the Bao relay.
- [README.md](https://github.com/kanatabi/lumen/blob/main/README.md) — how to
  run (`make dev`).

## Estate facts an outsider needs

- **Role split (2026-11-13):** `LUMEN_ROLE=admin` is the single Control Plane
  (sessions/users/TOFU/Bao relay, no ingress); `cms` instances serve content
  per environment; the role is deployment identity, never a Bao value.
- The `/admin/bao/*` surface is the frozen
  [secrets-control-plane.md](../decisions/secrets-control-plane.md) contract —
  apps-are-data, key-set mirror, pin-as-lock.
- Cluster-internal only, ever; browsers ride the SSR/portal same-origin
  relays.
- Mellons reach both planes by path (`ADMIN_URL`/`CMS_URL` routing table).

Lesson ledger: [LEARNING.md](LEARNING.md).
