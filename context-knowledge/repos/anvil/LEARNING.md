---
tags: [anvil, lessons]
updated: 2026-11-15
---

# anvil — lesson ledger

The standing contracts and trap ledger live in the repo's
[AGENTS.md](https://github.com/kanatabi/anvil/blob/main/AGENTS.md) (§5 traps,
§6 environment model); this ledger records the walked incidents behind them.
Newest first.

- **2026-11-13 — a GITHUB_TOKEN-pushed tag never triggers a workflow.** The
  tag landed green and nothing deployed; the events API proved ReleaseEvents
  with zero PushEvents. Minted `push-release.sh` (REFUSES without
  `RELEASE_BOT_PAT`) and the Workflow-permission requirement. Standing rule:
  AGENTS §5 trap 2.
- **2026-11-13 — approving one shared environment released two versions.**
  v0.1.0 AND v1.0.0 pushed by one approval; the patch job died red on the
  duplicate-tag guard. Minted job-per-environment. Standing rule: AGENTS §5.
- **2026-11-13 — `git describe` sorts equidistant tags by TAGGER DATE.** The
  next-version line was wrong live; `sort -V` over merged tags replaced it
  and the semver-tool vendoring became doctrine. Standing rule: AGENTS §2
  (`next-version.sh`) + §4.
- **2026-11-13 — get-helm-3's CDN pointer is mutable.** The "pinned" helm
  install wasn't one until the tarball+sha256 form landed (verified against
  the CDN behavior). Standing rule: AGENTS §2 (`validate-manifests/`).
- **2026-11-14 — a stored truth table ages into phantom reds.**
  `expected-kinds.txt` made anvil's SHA a four-repo coordination point; the
  merge-base derived baseline replaced it (stateless, strictly stronger).
  Standing rule: AGENTS §2 note.
- **2026-11-14 — non-canonical kustomization files reflow under
  `kustomize edit`.** The env-model fixture battery showed one `set image`
  turning a hand-indented overlay into whole-file churn. Standing rule: keep
  landed overlays canonical (AGENTS §5 bump-diff anatomy).
- **Standing — cross-repo checkout of a private repo answers 404, not 403.**
  "Repo not found" in CI = a missing token. Standing rule: AGENTS §6 (the
  404 lesson).
- **Standing — renovate-style auto-bumps of anvil SHAs are a hard NO.**
  Deploy-capable code changes are reviewed as such. Standing rule: AGENTS §3.
