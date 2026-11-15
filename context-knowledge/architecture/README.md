---
tags: [architecture, index]
updated: 2026-11-15
---

# Architecture explainers

This folder is the estate's **learning home**: prose-first explanations of
how the system works, written so a new maintainer (human or agent) can
understand it — and so a returning one can re-find anything in minutes.
Diagrams are mermaid fenced blocks (GitHub and Obsidian render them
natively).

## Reading order (first visit)

1. [system-overview.md](system-overview.md) — the estate end-to-end: the
   big picture, the repos, the three planes, and three request walkthroughs
   (a reader, a publish, a secret edit).
2. [gitops.md](gitops.md) — how a git push becomes a cluster state; the hub
   tree; the validation habit.
3. [secrets-and-vault.md](secrets-and-vault.md) — OpenBao → ESO → pod env;
   why seeding order is structural; who may touch values.
4. [network-and-doors.md](network-and-doors.md) — the three zones, the four
   doors, the no-public-API rule, TLS/DNS, the admin mesh.
5. [environments-model.md](environments-model.md) — staging vs production
   vs foundation; co-tenancy; the naming contract; where versions live.
6. [releases-and-ci.md](releases-and-ci.md) — the approval ladder and every
   incident-shaped rule it carries.
7. [observability.md](observability.md) — the no-sidecars contract, the
   opt-in scraping pattern, what's watched and what's off.
8. [metrics-catalog.md](metrics-catalog.md) — the ONE inventory: every
   metric family the three apps publish, labels, budgets, queries.

## The contract these notes serve

Every note is EXPLANATION — the binding statements live in their
authoritative homes, and these notes link to them rather than re-stating:

| Authority | Home |
| :-- | :-- |
| the WHY for every infrastructure decision | [`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) (root decision record) |
| the step-by-step for every operation | [`runbook/`](../../runbook/00-overview.md) — `00a-run-order` is the execution map; `03-k3s` · `04-gitops` · `05-vault` · `06-apps-first-release` · `07-go-public` are the build-out chapters; `08`–`14` are day-2 |
| per-repo rules and contracts | each repo's own AGENTS.md / DESIGN.md (linked from the [repo cards](../repos/omicron/README.md)) |
| the frozen cross-repo contract | [decisions/secrets-control-plane.md](../decisions/secrets-control-plane.md) |
| vocabulary | [glossary.md](../glossary.md) |
| the incidents behind the rules | [repos/*/LEARNING.md](../repos/omicron/README.md) ledgers |

When a note and an authority disagree, the authority wins and the note gets
fixed — these are explainers, not spec.
