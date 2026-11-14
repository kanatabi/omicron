---
tags: [decisions, index]
updated: 2026-11-15
---

# Decision records

This directory holds the estate's **tracked, binding decision records** — the
kind that carry a frozen contract code and multiple repos implement against.

## What belongs here (and what doesn't)

- **Belongs:** cross-repo contracts whose home is neither repo (splitting them
  into one repo would orphan the others). Current:
  [secrets-control-plane.md](secrets-control-plane.md) — the frozen
  apps-are-data contract + D1–D5 rulings + the §8 append-only decision log,
  referenced by lumen DESIGN §9, mellon DESIGN §6.1, INFRA §5.6/§10, and
  runbook ch.13's walk ledger. Moved here 2026-11-15 (was
  `PLAN-SECRETS-CONTROL.md` at the workspace root).
- **Doesn't (and where those live instead):**
  - Infrastructure-shape rulings → amendments are recorded inline in
    [`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) (the single-homed
    decision record) with their dates.
  - Per-repo design decisions → each repo's `DESIGN.md` (tracked, atomic with
    code).
  - Round-by-round journals → the owner's LOCAL-ONLY `PLAN.md` files
    (gitignored; see [doc-map.md](../doc-map.md)).

## Format

A decision record is a whole document moved into place (never split), keeps
its own status/decision-log sections, and states which repos implement it.
When reality forces a change to a frozen part: update the record's log BEFORE
the code ships (the record itself says this — it's the point).
