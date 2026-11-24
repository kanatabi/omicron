---
tags: [docs, doctrine]
updated: 2026-11-15
---

# Doc map — which document lives where, and why

The estate has a doc tier. Knowing it answers "where do I record this?" and
"where do I look this up?" without guessing.

## The tier (rulings 2026-11-15 unless noted)

| Doc | Audience | Rules |
| :-- | :-- | :-- |
| `README.md` (every repo) | humans landing in the repo | clean, simple, focused; never a copy of AGENTS.md — depth belongs below |
| `AGENTS.md` (every repo) | AI agents + contributors | orientation, load-bearing rules, hard-won traps; git history is the source of truth for WHY; this file is the index |
| `DESIGN.md` (code repos) | everyone | the living spec / contract; tracked; atomic with the code it describes |
| `PLAN.md` (earendil, mellon) | **the owner only** | **LOCAL-ONLY** — gitignored, on the owner's disk, never in Git, never recreated in a repo. Append-only journals with decision records |
| `INFRA_ARCHITECTURE.md` (root) | everyone | the decision record for the estate's shape — **single-homed at the workspace root**; child repos link to it, never fork it (the vortex copy was retired 2026-11-15 as a stale fork) |
| `runbook/` (root) | everyone operating | THE operating procedure — VPS-first, milestone-ordered; claims become proof when a chapter walks green |

## Where each doc lives now

| Repo | README | AGENTS | DESIGN | PLAN |
| :-- | :-- | :-- | :-- | :-- |
| [omicron](https://github.com/kanatabi/omicron) | ✔ | ✔ (workspace non-negotiables — untouched by the 2026-11-15 round) | — (INFRA doc fills this role) | — |
| [earendil](https://github.com/kanatabi/earendil) | ✔ (light-touch) | ✔ | ✔ | local-only (2026-11-15) |
| [lumen](https://github.com/kanatabi/lumen) | ✔ (already current) | ✔ (refreshed 2026-11-15: live M1–M6, real-first) | ✔ | — |
| [mellon](https://github.com/kanatabi/mellon) | ✔ (refreshed 2026-11-15) | ✔ (new 2026-11-15) | ✔ | local-only (2026-11-15) |
| [vortex](https://github.com/kanatabi/vortex) | ✔ (slimmed 2026-11-15) | ✔ (new 2026-11-15; absorbed the README conventions) | — (INFRA doc) | — |
| [anvil](https://github.com/kanatabi/anvil) | ✔ (slimmed 2026-11-15) | ✔ (new 2026-11-15; absorbed the README depth) | — (release contract lives in AGENTS) | — |

## Superseded docs go to the vault archive, not to oblivion

- `earendil/ARCHITECTURE.md` → [archive/earendil-ARCHITECTURE.md](archive/earendil-ARCHITECTURE.md) (superseded single-node draft; deleted from the repo 2026-11-15)
- `mellon/THREAT-NOTE.md` → [archive/mellon-THREAT-NOTE.md](archive/mellon-THREAT-NOTE.md) (GATE #5 threat detailing; deleted 2026-11-15, owner read-through pending as recorded there)
- `vortex/INFRA_ARCHITECTURE.md` → deleted 2026-11-15 with no archive: it was a stale fork of the root doc (nothing unique), and git history keeps it

Archive rule: content verbatim + a provenance header (where it came from, when
and why it moved, what supersedes it). Repo-relative links inside an archived
body are historical.

## The context-sync rule (workspace doctrine, 2026-11-15)

**Every change in a child repo is synced with `context-knowledge/` in the
SAME round.** The vault is the estate's learning home — a maintainer
(human or agent) must be able to learn the current truth about any repo
from [repos/<name>/README.md](repos/omicron/README.md) alone, and to see
the walked incidents in `repos/<name>/LEARNING.md`. A stale vault note is
a lie the next maintainer will trust.

What triggers a sync (any one suffices):

- the repo's **stack, anatomy, contract surface, commands, env vars, or
  conventions** changed → update `repos/<name>/README.md`;
- the change **minted a lesson** (an incident, a trap, a walked discovery)
  → add a dated entry to `repos/<name>/LEARNING.md`;
- the change is **decision-level** (affects placement, doors, epochs,
  release rules) → also the root INFRA doc / the relevant
  [architecture/](architecture/README.md) note / the decision record;
- the change is **operational** → also the runbook chapter that walks it.

The sync is part of the change's round (same sitting, same review), the
way tests are: "the code landed but the vault didn't" is an incomplete
round. Each repo note carries a sync-duty box naming its own checklist;
each repo's AGENTS.md states the duty for agents working there.

**File policy per repo (2026-11-15):** two files are the DEFAULT —
`README.md` (the learning note) + `LEARNING.md` (the ledger) — not a cap.
When a section outgrows its note (an API surface, a subsystem walkthrough,
a run of tables), give it a focused file in the same directory (e.g.
`repos/lumen/api-surface.md`) and link it from the note's contents; the
sync duty covers extra files the same as the note itself.

## This vault's own rule

The vault ([INDEX.md](INDEX.md)) never becomes a second home for a repo doc —
it links, synthesizes, records decisions, and archives. If you find yourself
copying a repo doc into the vault, stop: link to it.

- `decisions/rbac-spine.md` — the RBAC spine decision record (2026-11-24).
