---
tags: [architecture, observability]
updated: 2026-11-15
---

# Observability — the eyes and their doors

## The contract (INFRA Phase 5)

**No sidecars.** Grafana **Alloy** runs as a worker-node DaemonSet; apps opt
into scraping with `prometheus.io/{scrape,port,path}` pod annotations and
serve `/metrics` on an unrouted admin port (9090) plus structured stdout
logs. Traces are OFF (no Tempo); the statsd listener exists but stays
commented.

## The stack

| Piece | Role | Notes |
| :-- | :-- | :-- |
| VictoriaMetrics | metrics store | single instance, worker-1 |
| Loki | log store | 7d retention |
| Alloy | the collector | DaemonSet, one per worker |
| Grafana | the UI + alerting | its door `anor.gofar.id` is production-owned DNS hosted foundation-side; per-env dashboards filtered |

## The doors

Dashboards are the one human-facing observability surface (`anor.gofar.id`,
ruling 2026-11-13): Cloudflare proxy → managed challenge → Access allowlist →
Grafana OIDC. The API plane stays private — metrics/log reads happen through
the dashboards or the tunnel.

## What the labels promise (walked 2026-11-14/15)

- Every pod log carries the app label; the fallback chain was fixed so the
  short app label wins (vortex `0e18f0f`).
- The OTLP semconv door is live at the edge (traefik) — same commit round.
- Alert rule #1 (TLS expiry) is semantically correct as of 2026-11-15: the
  gauge `k3s_certificate_expiration_seconds` is a REMAINING-seconds gauge —
  the expr must be a bare threshold (`min(...) < 1814400`), never a
  drift-difference. The walked lesson is the ledger's property:
  [../repos/vortex/LEARNING.md](../repos/vortex/LEARNING.md).

## Seeding is structural here too

The grafana feeds (`kv/grafana/production`, four keys) must exist before the
observability hub is applied — an ES errors on any missing declared key, and
the wedge is permanent (the sync-op block class). That's why the
observability hub is the ONE manual gate in bootstrap order.

Details: [vortex AGENTS.md](https://github.com/kanatabi/vortex/blob/main/AGENTS.md)
§5/§7; the budget table in [`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) §1.
