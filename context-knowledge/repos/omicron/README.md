---
tags: [omicron, workspace]
updated: 2026-11-15
---

# omicron (the superproject)

The workspace itself: pins the five submodules, holds the root docs, and now
this vault. Not an application — the connective tissue.

## Its own artifacts

- [`AGENTS.md`](../../../AGENTS.md) — the workspace-wide non-negotiables (values
  never in Git; two sanctioned public surfaces + the dashboard door; explicit
  placement; pinned v-tags; app-of-apps shape; the observability contract).
- [`INFRA_ARCHITECTURE.md`](../../../INFRA_ARCHITECTURE.md) — the decision record:
  3-node K3s phases, secrets design §5, amendment ledger with dates.
- [`runbook/`](../../../runbook/00-overview.md) — THE operating procedure
  (milestones M0–M6); `RUNBOOK.md` at the root is the archived rehearsal log.
- [`context-knowledge/`](../../INDEX.md) — this vault.

## What the workspace owns operationally

- Submodule pins: bumping a child = push the child, then commit the new
  gitlink here (granular; Conventional Commits).
- The config.epoch TRIO and release gates bind via the runbook + vortex; see
  [../architecture/releases-and-ci.md](../../architecture/releases-and-ci.md).

Lesson ledger: [LEARNING.md](LEARNING.md).
