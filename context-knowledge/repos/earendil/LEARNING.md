---
tags: [earendil, lessons]
updated: 2026-11-15
---

# earendil — lesson ledger

The repo's standing lesson list lives in its own
[AGENTS.md §10](https://github.com/kanatabi/earendil/blob/main/AGENTS.md)
(ten entries, each minted by a real bug fix). This ledger records the walked
events that minted entries there and anything newer. Newest first.

- **2026-11-11 — `adapter-node` builds ship landmines without explicit
  bundling decisions.** The deploy container broke on the markdown family
  until deps were bundled/externalized deliberately (`8609828`, fix/ssr-dep-bundling).
  Standing rule: DESIGN.md deployment section + AGENTS §10.
- **2026-11-13 — platform semantics are learnable only live.** The per-bump
  environments + glob tag filter (`0f95cb4`) repaired two GitHub behaviors
  that no doc states plainly (environment approval scope; `on.push.tags`
  glob-vs-regex). Ledgered here because the fix rode this repo's release
  wiring; the full ruling lives in anvil AGENTS §5.
- **2026-11-15 — the correlation id is MINTED per call, never adopted.**
  earendil's seam (`requestid.ts`) mints a UUID per outbound call and
  echoes lumen's RESPONSE id when it answers — the echo wins, the minted
  id is the fallback (a caller that predates the echo still chains).
  Standing rule: one vocabulary file per app (`requestid.ts`), `request_id`
  in log fields, `X-Request-Id` on the wire — never `rid`, never a second
  spelling; the id rides error objects for logs but UI copy renders the
  wire message verbatim (ghost-field).
- **2026-11-09 — real-first replaced mock-first** (owner ruling). The runtime
  always fetches lumen; the fixture twin is test-only. Standing rule: AGENTS
  §6.4. The trap it guards: any new "mock mode" runtime path.
- The ten §10 lessons (SSR paint vs hydration, scroller-absolute positioning,
  View Transition element split, SVG intrinsic size, touch reveals, Tailwind
  scanning, autofocus, hover-preload storms, script-adjacent gotchas) are
  dated by their fix commits in `git log` — `git log --oneline --grep` is the
  fastest way to date any of them.
