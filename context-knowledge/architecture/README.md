---
tags: [architecture, index]
updated: 2026-11-15
---

# Architecture explainers

One concern per note, written to be READ (prose first, links to the
authoritative specs second). These synthesize; they do not re-spec — when a
note and a repo doc disagree, the repo doc wins and the note should be fixed.

| Note | One line |
| :-- | :-- |
| [system-overview.md](system-overview.md) | the estate end-to-end on one page |
| [gitops.md](gitops.md) | how a git push becomes a cluster state |
| [environments-model.md](environments-model.md) | the three-environment axis and co-tenancy |
| [network-and-doors.md](network-and-doors.md) | what is public, what is never, and how TLS/DNS ride |
| [secrets-and-vault.md](secrets-and-vault.md) | OpenBao, ESO, the render contract, seeding order |
| [observability.md](observability.md) | metrics/logs/dashboards and their doors |
| [releases-and-ci.md](releases-and-ci.md) | the approval ladder from merge to running pod |

The decision record behind all of them:
[`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) at the workspace root.
