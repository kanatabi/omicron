---
tags: [lumen, lessons]
updated: 2026-11-15
---

# lumen — lesson ledger

The standing rulings live in the repo's
[AGENTS.md](https://github.com/kanatabi/lumen/blob/main/AGENTS.md); the wire
contract in its DESIGN.md. This ledger records walked events that minted
them. Newest first.

- **2026-11-13 — the battery owns an `itest/` prefix, never the human path.**
  An old worker + shared queue reseeded `kv/lumen/dev` mid-walk (a human was
  browsing the same path) — the collision class. Minted the integration-path
  isolation rule (C5). Standing rule: AGENTS test-battery section.
- **2026-11-13 — a pin is a LOCK, not intent.** The redefinition walk
  (`230783b` + lumen `28e7811`) found "intent" unenforceable at the only
  write path that matters; pins now refuse writes (403) until unpinned, and
  mellon renders the wire copy verbatim. Standing rule: DESIGN §9 + the
  vault's [secrets-control-plane decision log](../../decisions/secrets-control-plane.md).
- **2026-11-13 (C1) — the estate matrix feed exists because drift was
  invisible.** `GET /admin/bao/summary` (lumen `9544ce4`) answers app×env
  head/pin/key-counts so mellon's matrix can surface empty-key and shape
  drift without exposing values.
- **2026-11-13 (A5) — two wire truths found only against REAL OpenBao.** The
  control-plane integration round (`98563b9`) caught live semantics the unit
  layer could not (policy `patch` capability; create-only write behavior on
  the wire). Standing rule: test battery tiering (`make test` vs
  `test-integration`).
- **2026-11-09 — layered HTTP is enforced by review, not by compiler.** The
  handler→service→store split (owner ruling) exists because a handler
  importing store was the actual drift vector; keep handlers
  decode/call/map/encode ONLY.
- Redaction is TESTED, not promised: `bao_integration_test.go` captures the
  slog stream and demands the marked value's absence — the guard exists
  because "we never log values" had to be proven at least once.
