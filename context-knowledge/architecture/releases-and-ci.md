---
tags: [architecture, releases, ci]
updated: 2026-11-15
---

# Releases and CI — the approval ladder

## The doctrine (owner rulings 2026-11-13/14)

**Branch merges gate and NEVER deploy.** A release exists only because a
human approved one of three waiting bump jobs; the tag that approval pushes is
the only deployable artifact. Because a referenced-but-missing environment is
AUTO-CREATED UNPROTECTED (the 2026-11-13 v3.0.0 incident), every release
pipeline ships a fail-closed `gate-audit` job: no environment OR no
required_reviewers = deploy chain RED.

## The ladder, end-to-end

```
merge to main → ci.yml gates
  → THREE waiting jobs, EACH on its OWN protected environment:
      semver-patch [release-patch] · semver-minor [release-minor] ·
      semver-major [release-major]
    approving ONE job IS the release decision; siblings auto-decline (settle)
  → semver-release: next-version.sh → annotated tag → push via RELEASE_BOT_PAT
    (a GITHUB_TOKEN-pushed tag NEVER triggers a workflow — the silent
    no-deploy trap, proven via the events API 2026-11-13)
  → release.yml: publish-image · deploy-plan (evidence-only rehearsal) ·
    deploy-<env> chains — ONE per environment, EACH parking on its own
    protected deploy-<env> environment; the ladder is the APPROVAL ORDER
    (staging before production)
  → that env's bump PR (born-validated) → merge → Argo syncs
```

Rollback = a human-merged git revert (or re-dispatch with an older tag:
redeploy = release).

## What a bump diff may contain (and nothing else)

- The `images:` stanza lines for the app in the bump's OWN env (same-env
  lockstep; a production bump never re-pins staging).
- The `omicron/config.epoch` TRIO — pod-template annotation + gate
  `--declared` arg + ES annotation, byte-equal, in the SAME commit (a bump may
  be CONFIG-ONLY: same tags, trio flips).
- The fence accepts line SHAPES, never app names; the branch grammar
  (`bump/<app>-<env>-<tag>`) carries the env. Auto-merge additionally requires
  `DEPLOY_AUTOMERGE=on` (absent = off, fail-safe) and validate-green.

The full contract with the fail-open trap ledger:
[anvil AGENTS.md §5–§6](https://github.com/kanatabi/anvil/blob/main/AGENTS.md);
the epoch gate's cluster side: [gitops.md](gitops.md) +
[vortex AGENTS.md §7](https://github.com/kanatabi/vortex/blob/main/AGENTS.md).

## The four-repo pin dance (why a bump is a choreography)

anvil's SHA is pinned by the four consumer repos; vortex pins CI refs back.
Upgrading either is a reviewed PR, never a renovate auto-bump. When a
structure change moves expected kinds, the consumer bumps the pin in the SAME
PR (the retired expected-kinds table taught this the hard way — anvil AGENTS
§2 note, 2026-11-14).

## Environment ladder status (walked)

- The first live bump (#17) proved the ladder: staging before production,
  evidence-first. Staging Application CRs + the staging hub are LANDED.
- What remains open per the runbook §5: Part B/VPS ordering, observability
  sizing — see [`runbook/`](../../runbook/00-overview.md).
