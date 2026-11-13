---
tags: [runbook, releases]
updated: 2026-11-13
status: PROVEN live (lumen v2.0.0, mellon v1.0.1 rode the full chain; the
  auto-merge guard merged its first PR after the env-door fix)
---

# 09 · Releases — the machine, reference edition

> **Why so many gates:** a merge is a *quality* decision (gates prove the
> code good). A release is a *deploy* decision (a human owns the
> version). A deploy is a *production* decision (a human reads the
> evidence first). Three different questions — three different clicks.
> And only **released v-tags** ever reach the cluster: the deployed world
> reads like a changelog, every pin is immutable, and rollback is always
> possible. (The doing is ch.06's first-release walk; this chapter is
> the standing reference for every release after that.)

## 1. The machine (all parts already built — this is how it behaves)

```
merge PR → ci.yml: gates run (+ the live API contract suite on earendil)
  → THREE jobs park amber, each on its own protected environment:
       semver-patch [release-patch] · semver-minor · semver-major
  → you approve EXACTLY ONE                 ← the release decision
       · version = highest reachable v-tag + your literal bump
         (version-order, never date-order — a real bug class, fixed)
       · the tag rides RELEASE_BOT_PAT      ← why: a GITHUB_TOKEN tag-push
         → GitHub Release + settle            never fires any workflow —
         (siblings auto-decline*)             silent no-deploy is the worst
                                             failure mode we know
  → the TAG PUSH triggers release.yml:
       build → ghcr.io/kanatabi/<app>:vX.Y.Z (+ :latest for tooling only)
       deploy-plan → the EVIDENCE job: pin now→proposed, exact diff,
                     full manifest validation, writes NOTHING
       deploy → parks on the `deploy` environment   ← the deploy decision
  → you approve it → bump PR into vortex opens, BORN VALIDATED
       → vortex CI validates independently (job `validate-manifests`)
       → auto-merge: all six guards green + DEPLOY_AUTOMERGE=on → merged
  → Argo syncs within its poll (~3 min) → pods roll. Done.
```

\* settle declined its siblings in rehearsal but **FAILED in production**
(POST refused; warn-only did its job — releases still shipped). Its
diagnostics round is deferred **with the failing-call evidence frozen**
(the fix will start from proof, not guesswork). Until then, the habit
is: **approve one, decline two by hand**. They
expire in 24h anyway; a forgotten sibling just holds the run "Waiting"
and can stall the ci queue behind it.

## 2. First release of a fresh repo

No tags yet: `minor` or `patch` → **v0.1.0**; `major` → **v1.0.0**. Pick
your birth number by which job you approve (this is a human ceremony, on
purpose — the estate's software is exactly as versioned as you want).

## 3. What is NOT in this chain (common confusion, both directions)

> **Manifest edits do NOT ride GitHub.** Editing a manifest in `vortex`
> (replicas, resources, ingress): PR + merge → **Argo syncs it directly,
> GitHub Actions is not involved at all**. The deploy job's only power
> is the image PIN. Your review evidence is the PR's *rendered* diff —
> `validate-manifests` posts the output Argo will apply, not the YAML
> you wrote.

- **Redeploying an OLD version** (incident rollback): two doors —
  (a) `git revert` the bump commit → human PR → Argo (the honest audit
  trail), or (b) "Run workflow" on `release.yml` with the old `vX.Y.Z`
  typed in (redeploy = release; the image still exists, it's immutable).
  Never `kubectl`-patch an image tag: selfHeal reverts you (ch.04).

## 4. The guards' fine print (why the auto-merge is safe to leave ON)

`anvil/bin/auto-merge.sh` merges ONLY if all six guards hold: head ref
is `bump/<app>-<tag>`, label `deploy-bump`, every changed file is an
`applications/<app>/kustomization.yaml`, every changed *line* lives
inside the `images:` stanza, `validate-manifests` reached **SUCCESS**,
and the switch reads exactly `on`. Anything doubtful prints
`NOT eligible:` and hands the PR to a human — silence is the safe
answer. **Kill switch:** delete the `DEPLOY_AUTOMERGE` variable → every
bump PR is manual again, instantly (absent = off, fail-safe).

The fine print that each clause earned (all real incidents):

- **The check-name contract.** A check-run is named after the *job*;
  vortex's job id was `validate`, so the guard's first production run
  (PR #7) polled for a name that never existed. The guard now accepts
  BOTH `validate-manifests` and `validate`, polls up to **15 minutes**
  for a terminal verdict (a not-yet-created or still-`IN_PROGRESS`
  check counts as NOT green — fail-safe), and **dumps the observed
  checks** when it bails, so a future rename is self-diagnosing, not
  archaeology. Renaming the vortex job without the guard silently
  strands every bump PR — the workflow carries a comment saying so.
- **The env-door truth.** The workflow passes `vars.DEPLOY_AUTOMERGE`
  into the script's environment. This is not laziness: a
  `GITHUB_TOKEN` **cannot read the variables API** — the 403 "Resource
  not accessible by integration" is BY DESIGN (proved on PR #8). The
  API fallback exists only for manual runs with a real token, and its
  output is **sanitized**: only the literal `on`/`off` counts, so an
  error body — even a JSON one — can never masquerade as a verdict.
  Absent or unreadable = off.
- **Empty checks are fatal.** The `labeled` trigger fires before
  `validate-manifests` even exists as a check-run; "no checks yet" once
  meant "proceed" — merge blind. Fixed 2026-11-13; the poll loop above
  is the replacement.

## 5. Owner one-timers this machine assumes (already done — keep them true)

1. Environments per app repo: `release-patch/minor/major` + `deploy`,
   **required reviewer = you**, **one env per job** (sharing one env
   batch-approves all its jobs at once — a real incident, printed here
   so nobody rediscovers it).
2. The token trio:

| Token | Grants | Lives where | Dies |
|---|---|---|---|
| `RELEASE_BOT_PAT` | Contents+Workflow+Actions (RW), the 3 app repos — the minimum that makes a tag-push fire `release.yml` | app repos' secrets | 90-day expiry — **calendar it at day ~75** (ch.12) |
| `VORTEX_BOT_PAT` | vortex-only (opens the bump PR as bot identity) | app repos' secrets | same 90-day discipline |
| `GITHUB_TOKEN` (free) | per-run; deliberately **cannot** cascade workflow events or read repo variables | automatic | — it's the reason the two PATs above exist |

**The 90-day symptom line (memorize it):** an expired `RELEASE_BOT_PAT`
kills a release at the *tag push* (403) and `VORTEX_BOT_PAT` kills it at
the *bump-PR step* (401) — and **nothing else breaks**, which is why
both are on the quarterly calendar, not a monitoring rule (ch.12).
Revoking `RELEASE_BOT_PAT` is the emergency brake on ALL releasing.

3. `DEPLOY_AUTOMERGE=on` repo variable on vortex (§4: deleting it is
   the kill switch).
4. GHCR packages **public** for apps that deploy (`ghcr.io/kanatabi/<app>`
   inherits repo visibility on first push — private repos produced
   private packages that made pods `ImagePullBackOff` until flipped;
   ch.12's incident card).
5. **The fail-open check, forever:** if bump jobs ever EXECUTE without
   an amber Waiting badge, that environment lost its reviewers — fix
   Settings→Environments before trusting any release.

Next → [10 Observability](10-observability.md)
