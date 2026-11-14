---
tags: [vortex, gitops]
updated: 2026-11-15
---

# vortex — the GitOps source of truth

Everything running in the cluster (except Argo CD itself) is declared here and
synced by Argo CD via app-of-apps: four hub entrypoints (foundation →
observability-gate → production → staging), `bases/` (ESO-free, no image pins)
+ `environments/{foundation,staging,production}/` overlays + `components/`
(single-node, config-gate).

## Its own docs (authoritative for this repo)

- [AGENTS.md](https://github.com/kanatabi/vortex/blob/main/AGENTS.md) — new
  2026-11-15: the three-environment axis, the naming contract, the ES render
  contract, the epoch TRIO values, bootstrap order, conventions, hard-won
  traps.
- [README.md](https://github.com/kanatabi/vortex/blob/main/README.md) —
  slimmed 2026-11-15: orientation + pointers.

## Estate facts an outsider needs

- One cluster can host any hub-set combination; moving an environment between
  clusters is a destination edit — zero manifest changes.
- Values live in OpenBao, never in Git; ESO renders per env; seeding order is
  structural (ESO fails the whole render on one missing key).
- Architecture explainers live in this vault:
  [../architecture/gitops.md](../../architecture/gitops.md) and friends — the
  rationale is the root INFRA doc.
- The in-repo INFRA copy was retired 2026-11-15 (stale fork; link, don't
  copy).

Lesson ledger: [LEARNING.md](LEARNING.md).
