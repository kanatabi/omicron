---
tags: [architecture, observability, metrics]
updated: 2026-11-15
---

# The metrics catalog — every series the estate's apps publish

The inventory of what the three apps' `/metrics` endpoints serve. The
vocabulary is ONE design shared by all three (owner ruling, 2026-11-15):
the same families, the same label axes, the same static `service` label —
so the estate's panels are `sum by (service, dependency)` instead of
per-app regexes. Each app's deep-dive note links here; this file is the
ONE place the list lives.

## The shared contract

- **Where:** every app serves `/metrics` on an **unrouted admin port**
  (`*_METRICS_PORT`, default `9090`) — Traefik never routes it; the
  no-sidecar contract (architecture [observability.md](observability.md)
  §opt-in). lumen carries it on every process shape (server, worker,
  all); the Node apps run two listeners in one process (app on `PORT`,
  metrics on 9090) via each repo's custom `server.js`.
- **The label axes:** `service` (static per app: `lumen`, `earendil`,
  `mellon`), `dependency` (which outside system), `operation` (an
  ENUMERATED verb — never a slug, id, or query value; cardinality is
  flat by construction), `result` (`ok|error|timeout`).
- **Result semantics:** a response that ARRIVED is `ok` even when it
  carries a 5xx (the transport succeeded; the status is the caller's
  story — the access line + error objects carry it). `timeout` = the
  bounded context expired and surfaced `DeadlineExceeded`
  (`AbortSignal.timeout` on the Node side, `context.WithTimeout` on
  lumen's). Anything else that throws is `error`. Errors ALWAYS
  rethrow — instrumentation never swallows.
- **The registry rule (Node apps):** prom-client's DEFAULT global
  register, shared across module copies — the SSR build bundles the
  metrics module into a chunk while `server.js` imports the source; a
  per-instance `new Registry()` puts the hooks' observations in a
  register nobody scrapes (the bug the smoke test caught; the
  `define()` guard makes definitions idempotent across copies).

## lumen (internal/obs — DESIGN §11)

| family | labels | answers |
| :-- | :-- | :-- |
| `outbound_request_total` | dependency, operation, result | did every outside call succeed? error vs timeout distinguished |
| `outbound_request_duration_seconds` | dependency, operation | each dep's latency distribution |
| `outbound_inflight` | dependency | who is hung RIGHT NOW |
| `http_request_total` | method, route, status | inbound RED (status axis) — chi ROUTE TEMPLATES |
| `http_request_duration_seconds` | method, route | inbound latency |
| `queue_job_total` | kind, result | the index queue's attempt outcomes (`done\|error`; river retries an error) |
| `queue_job_duration_seconds` | kind | job attempt latency |
| `db_pool_acquired` / `_idle` / `_max` | — | pool health |
| `db_pool_acquire_empty_total` | — | CUMULATIVE acquires that found no idle conn (rate = saturation; pgx exposes no live waiter count) |
| plus `collectDefaultMetrics`-style Go process metrics | — | GC, fds, goroutines |

lumen's dependencies (`dependency` axis): `meilisearch`,
`cloudflare-r2`, `openbao`, `lumen-admin` (the cms plane's
introspection edge). Its ops: `search`, `facets`, `index.upsert`,
`index.delete`, `ensure`, `ready` (engine); `put`, `ensure_bucket`
(r2); `login`, `list`, `read`, `write` (bao); `introspect` (admin).

Timeouts: flat viper keys `timeout_<dep>` / `timeout_<dep>_<op>` —
op override > dep default > in-code table; missing or EMPTY env =
default. lumen DESIGN §11 carries the budgets.

## earendil (src/lib/server/metrics.js)

| family | labels | answers |
| :-- | :-- | :-- |
| `outbound_request_total` | dependency, operation, result | the SSR loads' + proxy's lumen calls |
| `outbound_request_duration_seconds` | dependency, operation | lumen's latency as the BLOG sees it |
| `outbound_inflight` | dependency | hung lumen renders |
| `http_request_total` | method, route, status | inbound RED — SvelteKit ROUTE IDs (`/posts/[slug]`) |
| `http_request_duration_seconds` | method, route | page-render latency |
| plus prom-client defaults | — | event-loop lag, GC, process |

Dependency: `lumen` (the cms plane the SSR pod dials). Ops
(`#lib/api/client.ts`'s `OP`): `list-posts`, `read-post`,
`suggest-posts`, `search-posts`, `list-photos`, `featured-photo`,
`list-tags`, and `proxy-relay` (the `/api` proxy's CONSTANT op — the
forwarded path is user input and must never become a label).
Timeouts: flat `EARENDIL_TIMEOUT_LUMEN[_<OP>]` env keys (ms), same
missing/empty = default rule. The observability seam is INJECTED into
the shared `client.ts` (the browser bundle stays prom-client-free).

## mellon (src/lib/server/metrics.js)

| family | labels | answers |
| :-- | :-- | :-- |
| `outbound_request_total` | dependency, operation, result | the desks' lumen calls, PER PLANE |
| `outbound_request_duration_seconds` | dependency, operation | each plane's latency as the desk sees it |
| `outbound_inflight` | dependency | hung desks |
| `http_request_total` | method, route, status | inbound RED — SvelteKit ROUTE IDs |
| `http_request_duration_seconds` | method, route | page-render latency |
| plus prom-client defaults | — | event-loop lag, GC, process |

Dependencies: the DUAL UPSTREAM — `lumen-admin` (control plane) and
`lumen-cms` (content), mapped from routing.ts's `upstreamFor`. Ops: 40
enumerated verbs in the registry's `OP` (session.*, setup.*, users.*,
posts.*, photos.*, collections.*, tags.*, search.query, bao.*) — typed
as `OpName` at every call site: a misspelled op is a compile error.
Timeouts: flat `MELLON_TIMEOUT_LUMEN_ADMIN/_CMS[_<OP>]` env keys (ms);
`photos.upload` carries the 30s budget (multi-MB bodies are slow by
nature).

## The queries that matter

```promql
# any dep failing or hanging, across the estate?
sum by (service, dependency, result) (rate(outbound_request_total[5m])) > 0 and on()
  label_replace(sum by (service, dependency) (rate(outbound_request_total{result="timeout"}[5m])), "result", "timeout", "", "")
# hung right now
outbound_inflight > 0
# pool saturation (lumen)
rate(db_pool_acquire_empty_total[5m]) > 0
# inbound error rate per route
sum by (service, route, status) (rate(http_request_total[5m]))
```

## Provenance & history

- **2026-11-15** — the round that landed all three: lumen `a9d71f9`
  (DESIGN §11), earendil `7b872ad`, mellon `c86c9cd`; the scrape opt-in
  (vortex annotations) same day. The catalog extracted here from the
  per-repo notes so the inventory has ONE home.
- The label doctrine and the registry rule are the owner's rulings of
  the same date; the register-share bug (Node apps) is ledgered in both
  apps' LEARNING notes.
