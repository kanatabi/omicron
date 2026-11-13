---
tags: [runbook, releases]
updated: 2026-11-13
status: PROVEN live (lumen v2.0.0, mellon v1.0.1 rode the full chain; the
  auto-merge guard merged its first PR after the env-door fix)
---

# 08 · Releases — the ritual, end to end

> **Why so many gates:** a merge is a *quality* decision (gates prove the
> code good). A release is a *deploy* decision (a human owns the version).
> A deploy is a *production* decision (a human reads the evidence first).
> Three different questions — three different clicks. And only **released
> v-tags** ever reach the cluster: the deployed world reads like a
> changelog, every pin is immutable, and rollback is always possible.

## 1. The machine (all parts already built — this is how it behaves)

```
merge PR → ci.yml: gates run (+ the live API contract suite on earendil)
  → THREE jobs park amber, each on its own protected environment:
       semver-patch [release-patch] · semver-minor · semver-major
  → you approve EXACTLY ONE                 ← the release decision
       · version = highest reachable v-tag + your literal bump
         (version-order, never date-order — a real bug class, fixed)
       · the tag rides RELEASE_BOT_PAT      ← why: a GITHUB_TOKEN tag-push
         the GitHub Release + settle          never fires any workflow —
         (siblings auto-decline*)             silent no-deploy is the worst
                                             failure mode we know
  → the TAG PUSH triggers release.yml:
       build → ghcr.io/kanatabi/<app>:vX.Y.Z (+ :latest for tooling only)
       deploy-plan → the EVIDENCE job: pin now→proposed, exact diff,
                     full manifest validation, writes NOTHING
       deploy → parks on the `deploy` environment   ← the deploy decision
  → you approve it → bump PR into vortex opens, BORN VALIDATED
       → vortex CI validates independently
       → auto-merge: all six guards green + DEPLOY_AUTOMERGE=on → merged
  → Argo syncs within its poll (~3 min) → pods roll. Done.
```

\* settle declined its siblings in rehearsal but FAILED in production (POST
refused, warn-only caught it — releases still shipped). Until its deferred
diagnostics round lands, the habit is: **approve one, decline two by hand**.
They expire in 24h anyway; a forgotten sibling just holds the run "Waiting"
and can stall the ci queue behind it.

## 2. First release of a fresh repo

No tags yet: `minor` or `patch` → **v0.1.0**; `major` → **v1.0.0**. Pick
your birth number by which job you approve (this is a human ceremony, on
purpose — the estate's software is exactly as versioned as you want).

## 3. What is NOT in this chain (common confusion, both directions)

- **Editing a manifest in `vortex`** (replicas, resources, ingress):
  PR + merge → **Argo syncs it directly, GitHub is not involved at all**.
  The deploy job's only power is the image PIN. Your review evidence is
  the PR's *rendered* diff (`validate-manifests` posts the output Argo
  will apply, not the YAML you wrote).
- **Redeploying an OLD version** (incident rollback): two doors —
  (a) `git revert` the bump commit → human PR → Argo (the honest audit
  trail), or (b) "Run workflow" on `release.yml` with the old `vX.Y.Z`
  typed in (redeploy = release; the image still exists, it's immutable).
  Never `kubectl`-patch an image tag: selfHeal reverts you (ch.07).

## 4. The guards' fine print (why the auto-merge is safe to leave ON)

`auto-merge.sh` merges ONLY if: head ref is `bump/<app>-<tag>`, label
`deploy-bump`, **every changed file is a kustomization.yaml**, every
changed *line* lives inside the `images:` stanza, `validate-manifests`
reached **SUCCESS** (polls up to 15 min — a not-yet-created check counts
as NOT green, fail-safe), and the repo variable reads exactly `on`.
Anything doubtful hands the PR to a human. **Kill switch:** delete the
variable → every bump PR is manual again, instantly.

## 5. Owner one-timers this machine assumes (already done — keep them true)

1. Environments per app repo: `release-patch/minor/major` + `deploy`,
   **required reviewer = you**, one env per job (sharing one batch-approves
   all its jobs — an incident, printed here so nobody rediscovers it).
2. `RELEASE_BOT_PAT` (Contents+Workflow+Actions RW, 3 app repos, 90-day
   expiry — calendar the rotation, ch.12) · `VORTEX_BOT_PAT` (vortex-only).
3. `DEPLOY_AUTOMERGE=on` variable on vortex.
4. GHCR packages **public** for apps that deploy (`ghcr.io/kanatabi/<app>`
   inherits repo visibility on first push — private repos produced private
   packages that made pods `ImagePullBackOff` until flipped).
5. **The fail-open check, forever:** if bump jobs ever EXECUTE without an
   amber Waiting badge, that environment lost its reviewers — fix
   Settings→Environments before trusting any release.

Next → [09 Observability](09-observability.md)
