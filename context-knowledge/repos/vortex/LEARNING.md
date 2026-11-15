---
tags: [vortex, lessons]
updated: 2026-11-15
---

# vortex — lesson ledger

The standing traps live in the repo's
[AGENTS.md §9](https://github.com/kanatabi/vortex/blob/main/AGENTS.md); this
ledger records walked events, newest first.

- **2026-11-15 — the doors opened: the full first-boot chain walked.**
  cf-token seeded (ch.07 §3.2) → ES rendered → challenges presented →
  DNS-01 propagation → all four certs issued → Traefik claimed the routes
  → Ingress addresses (via `ingressEndpoint.hostname=localhost` — see
  below) → the wave-2 hold lifted → **earendil + mellon rolled; gofar.id
  answered 200 with the real cert; console 303; anor 302.** Two sub-lessons
  minted on the way:
  - **`ingressEndpoint.hostname` must be a DNS NAME, not an IP** — the API
    server rejects `127.0.0.1` (`must be a DNS name, not an IP address`);
    AND the chart's `publishedService` default (copy the address from the
    traefik Service — PENDING here) silently wins over the hostname unless
    disabled in the SAME helm upgrade (helm upgrades replace values — a
    flag from a previous upgrade doesn't survive).
  - **Every `helm upgrade traefik` on this cluster deadlocks** — the new
    pod can't schedule while the old holds hostPort 80/443 (the chart
    ignores the Recreate override); delete the old pod after upgrading.
- **2026-11-15 — the epoch's witness is the vault HEAD.** The production
  hub's first apply wedged a THIRD way: the gate refused
  `declared 7; vault head 1` — the trio's 7 was the owner's
  seeding-experiment alignment (each experimental write had bumped
  `kv/lumen/production`'s head; the re-seed reset it to 1), not a
  dev-vault carryover as first written up. Re-declared to the number the
  matrix shows (`3e1de06`). The rule: experiments on the seeds move the
  head and re-wedge the gate — re-dispatch the trio to match, or
  experiment on `kv/lumen/dev`; real config bumps move the vault write
  and the trio TOGETHER.
- **2026-11-15 — the k3d edge needs hostPort, and the Ingress address is a
  health gate.** With `--disable=servicelb`, a LoadBalancer Service never
  gets an address; the chart's `ports.web.hostPort: 80/443` binds the
  Traefik pod to the node ports (the k3d LB's target). And Argo's Ingress
  health wants `status.loadBalancer` populated — which Traefik writes only
  once it can CLAIM the route — which needs the TLS secret — which waits
  on ch.07's `cf-token` seed. Chain: no cert → no router → no address →
  earendil/mellon park at the Ingress wave, Deployments (wave 2) never
  roll, by design until go-public. The first "fleet is up" check must be
  staged accordingly.
- **2026-11-15 — `argocd.argoproj.io/hook-weight` does not exist.** The
  config-gate's RBAC trio + the janitor's Job/RBAC were annotated with it
  ("walked 2026-11-14" — but the walk had been saved by the manual
  `kubectl create serviceaccount` workaround, not the annotation). Argo
  silently ignored it: the gate Job (real `sync-wave: -1`) sorted BEFORE its
  own ServiceAccount (implicit wave 0), and the production-hub apply wedged
  in all three app namespaces — `pods "config-gate-production-" is
  forbidden: serviceaccount "config-gate-production" not found`. The fix
  (`e817cf8`) moved hook RBAC to PreSync sync-wave -2/-4 under their Jobs'
  -1/-3 — and the failed sync self-healed on the next automated pass. Two
  lessons in one: (1) the ordering key within a phase is SYNC-WAVE (Helm's
  `helm.sh/hook-weight` maps onto it; no argocd-prefixed hook-weight
  exists); (2) **an annotation fix that never applied looks identical to one
  that did** — verify against Argo's `syncResult` (the hook list), not
  against "the app went green" (the manual workaround makes it green).
- **2026-11-15 — evaluate the SHIPPED expr against the live store before
  calling an alert rule done.** Alert #1 shipped an always-true expr
  (`rate()` against a gauge) because it was reasoned, not evaluated. The
  drift test (10800s over 3h on all 22 series + no zero in 7d history +
  k3s source) proved `k3s_certificate_expiration_seconds` is a
  REMAINING-seconds gauge; the fix is a bare threshold
  (`min(...) < 1814400`, `1b2d7b7`). Grafana restart + mounted-expr verify +
  0 provisioning errors + functional no-fire ×2 closed it. The bad expr
  lived ~15m < `for: 30m` — never paged.
- **2026-11-15 — cert expiry has no per-cert gauge in cert-manager.**
  `cert-manager` v1.16.2 exports no per-cert remaining-lifetime metric; the
  LIVE signal is k3s's control-plane cert gauge. k3s renews leaf certs on
  startup <120d (90d pre-2025-05); CAs are never auto-renewed. The gauge
  refreshes ~every 30m.
- **2026-11-14 — log app-label precedence: the fallback stomped the short
  app label** (`0e18f0b`); fixed so the app label wins.
- **2026-11-14 — the OTLP semconv door is live at the edge** (traefik), same
  round (`1a353e7`).
- **2026-11-14 — a base `images:` stanza silently outranks every overlay.**
  Fixture-proven with kustomize v5.8.1; minted the pin-free-bases
  convergence. Standing rule: AGENTS §9.1.
- **2026-11-14 — `applications/` → `bases/` rename: counts unchanged, paths
  move.** The rename was prose-true (the docs always said "bases"); tooling
  followed the glob. Standing rule: AGENTS §8 step 4 + anvil's transition
  window.
- **2026-11-13 — an ES missing ONE key wedges the sync-op forever.** The
  observability hub became a manual gate because of exactly this (ch.12 card
  11). Standing rule: AGENTS §9.4.
