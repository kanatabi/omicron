---
tags: [omicron, lessons]
updated: 2026-11-15
---

# omicron — lesson ledger

Workspace-level lessons. Each entry: the incident, the ruling it minted, and
where the standing rule now lives. Newest first.

- **2026-11-15 — forks rot, single-home the truth.** The in-vortex INFRA copy
  had diverged ~350 lines stale in weeks (old domain, superseded tag scheme);
  a diff-vs-root fold found ZERO unique content. Ruling: one blueprint, one
  home — child repos link to the root doc, never fork it; superseded docs get
  vault archives (this vault's `archive/`), local-only journals stay local.
  Standing rule: [doc-map.md](../doc-map.md) + vortex AGENTS §9.8.
- **2026-11-13 — referenced-but-missing environments are auto-created
  UNPROTECTED.** v3.0.0 fired with no park and five bump PRs opened
  unattended. Minted the fail-closed `gate-audit` job (no environment OR no
  required_reviewers = chain RED) and the runbook's protected-environment
  preflight. Standing rule: anvil AGENTS §5 trap 1.
- **2026-11-13 — one environment approval releases EVERY job waiting on that
  environment.** A shared `release` env pushed two tags in one approval (the
  patch job died red on the duplicate-tag guard). Minted job-per-environment
  (`release-patch|minor|major`) and the settle-decline. Standing rule: anvil
  AGENTS §5.
- **2026-11-13 — a fine-grained PAT without `Workflow:` permission pushes
  refs that never trigger workflows.** Proven via the events API: ReleaseEvents,
  zero PushEvents — GitHub never recorded the ref creation. `RELEASE_BOT_PAT`
  needs Contents + Workflow + Actions. Standing rule: anvil AGENTS §5 trap 2.
- **2026-11-13 — a base `images:` stanza outranks every env overlay**
  (kustomize override order, fixture-proven). Minted the convergence: bases
  carry NO pins; env trees are the only version homes. Standing rule: vortex
  AGENTS §9.1.
- **2026-11-11 — claims become proof only by walking.** The production
  ingress cutover was "done" in manifests days before it was verified live;
  the runbook's `status:` promotion ritual (ch.12) exists for exactly this.
  Standing rule: runbook ch.12 + ch.13 walk ledger.
