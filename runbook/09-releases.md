---
tags: [runbook, releases]
updated: 2026-11-14
status: PROVEN live (lumen v2.0.0, mellon v1.0.1 rode the full chain); the
  per-env deploy chains + fail-closed gate-audit are the post-incident
  shape (2026-11-13/14) — the incident record in §6 is required reading
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
       gate-audit → FAIL-CLOSED check (§6's scar): every deploy-* env of
                    this repo EXISTS and carries required_reviewers,
                    else the whole chain goes RED before anything parks
       then ONE CHAIN PER TARGET ENVIRONMENT —
       lumen: foundation | staging | production · earendil/mellon: staging | production:
         deploy-plan-<env> → the EVIDENCE job: pin now→proposed, exact
                            rendered diff, full manifest validation,
                            writes NOTHING
         deploy-<env> → PARKS on protected environment deploy-<env>  ← the
                        deploy decision, ONE environment per chain —
                        sharing one env batch-approves all parks at once
                        (a real incident; never do it)
  → you approve a chain's park → bump/<app>-<env>-<tag> PR opens, BORN
    VALIDATED, editing ONLY environments/<env>/** (§4's fence)
       → vortex CI validates independently (job `validate-manifests`)
       → auto-merge: all guards green + DEPLOY_AUTOMERGE=on → merged
         (variable off/absent = the human merges each bump PR by hand)
  → Argo syncs within its poll (~3 min) → that env's pods roll. Done.
```

**The ladder is the approval ORDER, not a different machine:** the tag
lights every chain's park at once; you walk them bottom-up —
`deploy-staging` approved before `deploy-production` is the doctrine
(foundation parks whenever the shared plane's shape changes). Approving
one chain is *only* a decision about that environment; a lumen release
you approve for staging and not production leaves production on the old
tag, legitimately and visibly.

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
> is the image PIN (and, on a `config-epoch` dispatch, the epoch TRIO —
> ch.06 §4). Your review evidence is the PR's *rendered* diff —
> `validate-manifests` posts the output Argo will apply, not the YAML
> you wrote.

- **Redeploying an OLD version** (incident rollback): two doors —
  (a) `git revert` the bump commit → human PR → Argo (the honest audit
  trail), or (b) "Run workflow" on `release.yml` with the old `vX.Y.Z`
  typed in and ONE environment chosen (redeploy = release; the image
  still exists, it's immutable). A `config-epoch` input is honored only
  on a SINGLE-environment dispatch — the trio's value is env-scoped and
  the chains' values legitimately differ (production's lumen trio is at
  `7`, the rest of the estate at `0`). Never `kubectl`-patch an image
  tag: selfHeal reverts you (ch.04).

## 4. Where versions live, and what the fence accepts

**The bases pin NOTHING** (`applications/<app>/kustomization.yaml` carries
no `images:` stanza — a fixture-proven kustomize fact: a base stanza
OUTRANKS every env overlay, because the inner transform rewrites the
image name before the outer one can match it, silently overriding the env
trees). **The env overlays are the ONLY version homes**: each
`environments/<env>/<app>/kustomization.yaml` states its own `images:`
stanza, and the overlays are canonicalized so a bump diff is exactly one
`newTag` line per dir. A lumen bump moves **every `name: lumen` stanza of
that env** — including the config-gate's own container, whose image tag
must equal the app's (same-env lockstep, ONE commit; half-moves are
structurally red).

`anvil/bin/auto-merge.sh` merges ONLY if all guards hold: head ref parses
an ENV — `bump/<app>-<env>-<tag>` (the legacy `bump/<app>-<tag>` grammar
means production and is **DEPRECATED**; an unparseable env makes the
merger **BAIL** to a human) — label `deploy-bump`, every changed file is
inside **`environments/<env-from-branch>/`** (the fence is env-scoped from
the branch, and its line grammar accepts SHAPES, never app names: lines
inside an `images:` stanza ∪ a TRIO line, `config.epoch` or `--declared`),
`validate-manifests` reached **SUCCESS**, and the variable
`DEPLOY_AUTOMERGE` reads exactly `on`. Anything doubtful prints
`NOT eligible:` and hands the PR to a human — silence is the safe
answer. (The transition-era legacy fence legs — `applications/*/kustomization.yaml`
and `overlays/production/**` for legacy-shaped branches only — are anvil
fossils marked "do not extend"; with `overlays/` deleted from vortex main,
no NEW bump should ever need them.) **Kill switch:** delete the
`DEPLOY_AUTOMERGE` variable → every bump PR is manual again, instantly
(absent = off, fail-safe).

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
- **The epoch TRIO is class-4 in CI.** validate-all asserts STRUCTURALLY
  that wherever `omicron/config.epoch` / `--declared` appear in a render,
  ALL THREE sides (pod annotation, gate `--declared`, ES annotation)
  exist and are EQUAL. A 2-of-3 flip is red before merge — the reason
  §1's bump PR flips all three lines in one commit.

## 5. Owner one-timers this machine assumes (keep them true)

1. **Environments per app repo, ALL created AND protected BEFORE the
   first tag rides the chain** (required reviewer = you, one env per
   job):
   - every app repo: `release-patch`, `release-minor`, `release-major`
   - lumen: `deploy-foundation`, `deploy-staging`, `deploy-production`
   - earendil, mellon: `deploy-staging`, `deploy-production`
   Sharing one environment batch-approves all its parks at once — a real
   incident, printed here so nobody rediscovers it. And per §6: a
   *referenced-but-missing* environment is auto-created UNPROTECTED, so
   "I'll protect it later" is exactly how v3.0.0 shipped itself.
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
   the kill switch; off/absent means a human merges every bump PR — a
   legitimate posture, not a malfunction).
4. GHCR packages **public** for apps that deploy (`ghcr.io/kanatabi/<app>`
   inherits repo visibility on first push — private repos produced
   private packages that made pods `ImagePullBackOff` until flipped;
   ch.12's incident card).
5. **gate-audit replaced the eyeball check.** The old habit — "if bump
   jobs ever EXECUTE without an amber Waiting badge, the environment lost
   its reviewers" — was HUMAN vigilance over a fail-open design. It now
   has a machine: every release pipeline's `gate-audit` job queries the
   environments API with `GITHUB_TOKEN` and fails the chain RED if any
   referenced `deploy-*` environment is missing OR lacks
   required_reviewers. Keep the habit anyway (§6 explains why one silent
   afternoon was expensive enough).

## 6. Incident record — the gate that wasn't (2026-11-13)

**What happened:** lumen `v3.0.0` and mellon `v2.0.0` fired their release
pipelines while the `deploy-*` environments **did not exist yet** (the
env-model rework had renamed the single `deploy` environment into the
per-env set; creation had not). GitHub's behavior when a workflow
references a missing environment: it **auto-creates it UNPROTECTED**. So
the deploy parks silently no-oped — nothing ever waited for a human —
and **five bump PRs (#14–#18) opened unattended**, each a legitimate
shape with an illegitimate approval trail.

**Why it was load-bearing:** the entire release doctrine (§1's "three
clicks") rests on the deploy park being a HUMAN door. A park that parks
nowhere converts the machine from approval-gated to push-to-deploy —
silently, greenly.

**The fix (shipped 2026-11-13/14, lumen `dc187ce` + `b70343e`, mellon
`5680849` + `850072e`, earendil `a8dfaaf` + `7b73c81`):** the
fail-closed `gate-audit` job described in §5.5 — every chain's deploy
job `needs: gate-audit`; the audit demands existence AND
`required_reviewers` per environment; absence of config must be RED,
never an implicit yes.

**Owner PENDING TASK (this is the one thing you must do by hand):**
create + protect, in each app repo → Settings → Environments → required
reviewers = you: `deploy-foundation`, `deploy-staging`,
`deploy-production` (lumen); `deploy-staging`, `deploy-production`
(mellon, earendil). Until then every release of those repos stops at a
RED gate-audit — which is the design protecting you.

**The open tails:** PRs **#14–#18** (vortex) remain **unmerged** from the
incident run — they await either a deliberate human merge (their content
is valid) or supersession by a protected re-run. Don't merge them by
reflex; merging is the deploy decision the machine never got to ask for.

Next → [10 Observability](10-observability.md)
