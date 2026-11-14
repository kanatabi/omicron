---
tags: [anvil, release]
updated: 2026-11-15
---

# anvil — the release toolkit

The estate's shared deployment toolkit: scripts (`bin/`) + composite GitHub
Actions (`actions/`) used by lumen, earendil, mellon, and vortex CI. Public by
design — nothing here holds secrets or values.

## Its own docs (authoritative for this repo)

- [AGENTS.md](https://github.com/kanatabi/anvil/blob/main/AGENTS.md) — new
  2026-11-15: the full action/script catalog, the end-to-end release contract,
  the fail-open trap ledger, the environment model (branch grammar, epoch
  TRIO, lockstep), secrets & variables, local-test recipes.
- [README.md](https://github.com/kanatabi/anvil/blob/main/README.md) —
  slimmed 2026-11-15: identity, scope rule, consumption rule (pin by SHA,
  never by tag), one-breath summaries.

## Estate facts an outsider needs

- Branch merges gate and NEVER deploy; a release exists only because a human
  approved one of three protected-environment bump jobs.
- Tags are pushed with `RELEASE_BOT_PAT` (a `GITHUB_TOKEN`-pushed tag never
  triggers a workflow — the silent no-deploy trap, proven via the events API
  2026-11-13).
- Rollback = a human-merged revert (or re-dispatch with an older tag).
- The release explainer: [../architecture/releases-and-ci.md](../architecture/releases-and-ci.md).

Lesson ledger: [LEARNING.md](LEARNING.md).
