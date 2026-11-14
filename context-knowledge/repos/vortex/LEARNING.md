---
tags: [vortex, lessons]
updated: 2026-11-15
---

# vortex — lesson ledger

The standing traps live in the repo's
[AGENTS.md §9](https://github.com/kanatabi/vortex/blob/main/AGENTS.md); this
ledger records walked events, newest first.

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
