---
tags: [mellon, lessons]
updated: 2026-11-15
---

# mellon — lesson ledger

The standing doctrine lives in the repo's
[DESIGN.md §2](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) and its
[AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md). This
ledger records walked events. Newest first.

- **2026-11-13 — one broken lazy-chunk killed the ENTIRE relay.** The
  markdown stack wasn't bundled deliberately until a single bad chunk took
  every portal page down (`499d595`). Standing rule: AGENTS §5 (keep the
  chunk boundary; it is load-bearing).
- **2026-11-13 — mobile split must STACK, not shrink.** The compare view
  collapsed to unusable at phone widths until panes were stacked with a wrap
  toggle (`4783059`). Standing rule: DESIGN §11 view anatomy.
- **2026-11-13 — pin-as-lock needs UI honesty.** When lumen redefined pins
  (intent → lock), the portal's copy went verbatim-on-wire: 403 rendered as
  lumen wrote it, plus a re-pin affordance. Standing rule: ghost-field
  doctrine (§6.1) — never decorate relayed server copy.
- **2026-11-13 — the dual-upstream split is ONE auditable table.** The
  role-split round moved every call behind `routing.ts` (session/users/
  setup/bao → ADMIN_URL; content → CMS_URL; unknown → throw). Standing rule:
  AGENTS §4.
- **2026-11-15 — the correlation id is MINTED here, never adopted from the
  browser.** The browser renders nothing correlation-shaped; a
  client-supplied id header is a log-injection surface. The access line's
  `hop` comes free from the routing table (`upstreamFor` — the table that
  decides WHICH lumen also names the hop). The id rides error objects
  (`AdminApiError.requestId`) for logs and support escalation, never for
  UI (ghost-field doctrine — the wire copy renders verbatim).
- **2026-11-15 — one module, many copies: the register must be global.**
  The runtime executes the metrics registry's SOURCE copy (server.js) AND
  its bundled chunk (the hooks chain) — with per-instance `new Registry()`
  the observations landed in a register nobody scraped (the smoke test
  caught it: the access line spoke, the /metrics output stayed empty).
  prom-client's DEFAULT register + idempotent `define()` is the fix (the
  smoke proved it: the outbound series appear in the scrape). And the
  ops are ENUMERATED per call site with the type enforcing it — the wire
  paths embed slugs/usernames, so a path-derived label would be a
  cardinality bomb. Standing rules: the registry is ONE plain-JS file;
  ops are compiled-checked against the registry; budgets ride flat
  MELLON_TIMEOUT_* env keys (missing or empty = default).
- **2026-11-15 — two boot blockers the rollout taught (the portal stayed
  up through BOTH, which is its own trap):**
  1. **The runtime image needs package.json** — the `#lib/*` alias lives
     in its `imports` field; without it server.js dies at boot
     (`ERR_PACKAGE_IMPORT_NOT_DEFINED`, 99a7d47). The v3.1.0 pod
     crash-looped while the OLD pod kept serving — "the portal works"
     masked a stuck rolling update. Check `rollout status`/pod states,
     never just the browser.
  2. **Auth-in-layout does not gate page loads** — SvelteKit runs layout
     and page loads in PARALLEL; the kubelet's probe on `/` (unauthed)
     fired the dashboard's four lumen dials anyway: four 401s per probe
     forever (0f224b0). Every (app) page load now opens with
     `requireAuthed` (a LOCAL cookie check — no lumen dial) and the
     auth-gate guard test walks the route tree. The probes also point at
     the M0-era `/healthz` (a probe must never render a page). Standing
     rules: new page loads gate FIRST; probes aim at static doors.
- **2026-11-13 — the wizard joined the threat surface.** The setup wizard's
  unauthenticated write path earned first-class TOFU analysis (V7) after this
  note's original scope was written; the detailing lives in this vault:
  [../archive/mellon-THREAT-NOTE.md](../../archive/mellon-THREAT-NOTE.md).
