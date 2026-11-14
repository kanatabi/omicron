---
tags: [runbook, releases]
updated: 2026-11-14
status: >-
  PROVEN live (lumen v4.0.1, mellon v3.0.1, earendil v1.2.0 rode the
  full chain 2026-11-14 — parks, approvals, auto-merged bumps, all seven
  environments protected and audited); the per-env deploy chains +
  fail-closed gate-audit are the post-incident shape (2026-11-13/14) —
  the incident records in §6 are required reading
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
         deploy-plan-<env> → the EVIDENCE job: pin now→proposed (markdown
                            summary: pin table, fenced bump diff, verdicts),
                            full manifest validation, writes NOTHING
         deploy-<env> → PARKS on protected environment deploy-<env>  ← the
                        deploy decision, ONE environment per chain —
                        sharing one env batch-approves all parks at once
                        (a real incident; never do it)
  → you approve a chain's park → bump/<app>-<env>-<tag> PR opens, BORN
    VALIDATED, editing ONLY environments/<env>/** (§4's fence)
       → vortex CI validates independently (job `validate-manifests`)
       → auto-merge: all guards green + DEPLOY_AUTOMERGE=on → merged
         (variable off/absent = the human merges each bump PR by hand)
       → the deploy job AWAITS THE MERGE (anvil 6e210f5, bounded poll):
         its green means the pin LANDED on vortex main — "PR opened" was
         never evidence (the merge rides vortex's auto-merge workflow,
         asynchronously; a flaked CI or failed guard used to leave a green
         run with no pin). A transient push rejection or a failed PR-create
         REDs immediately with the true state + recovery (card 10, ch.12)
  → Argo syncs within its poll (~3 min) → that env's pods roll. Done.
```

**Pipelines NEVER queue behind open ones (owner ruling 2026-11-14,**
*"whichever pipeline the developer wants to continue is their call"*): the
old `ci-refs/heads/main` concurrency group made every new release cycle
wait until the previous cycle's still-open run was cancelled by hand.
Fixed: main pushes get a UNIQUE concurrency group (github.sha) — runs
never queue; PR runs keep a per-PR group with cancel-in-progress (a new
commit supersedes its own run's older revision). Parks on the
`release-*`/`deploy-*` environments COEXIST by GitHub design (environments
don't serialize deployments — two chains can park on `deploy-staging` at
once, each with its own review): approve whichever chain you want to
continue. No cancelling, no reaping; the only janitor is GitHub's own
**30-day park auto-fail**. A run stays open (amber) while any of its parks
waits — that's inherent and blocks nothing.

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
is: **approve one, decline two by hand**. Unapproved siblings expire on
GitHub's own 30-day park auto-fail and — since the concurrency re-group
of 2026-11-14 — hold nothing back: their run stays amber, and no future
pipeline ever queues behind it.

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
  and ONE environment chosen (redeploy = release; the image
  still exists, it's immutable). **The tag input is OPTIONAL when you
  dispatch FROM the tag's ref** (the ref name provides it — leave the
  box empty); from a branch like `main` you must type it, and a
  fail-closed guard makes an empty box there RED before checkout —
  released `vX.Y.Z` or nothing (never a branch name). A `config-epoch`
  input is honored only
  on a SINGLE-environment dispatch — the trio's value is env-scoped and
  the chains' values legitimately differ (production's lumen trio is at
  `7`, the rest of the estate at `0`). Never `kubectl`-patch an image
  tag: selfHeal reverts you (ch.04).

## 4. Where versions live, and what the fence accepts

**The bases pin NOTHING** (`bases/<app>/kustomization.yaml` carries
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
   (Walked 2026-11-14: all seven exist and are protected now — verified
   via the environments API — with **Prevent self-review OFF**: the
   solo operator triggers and approves their own deploys.)
2. The token trio:

| Token | Grants | Lives where | Dies |
|---|---|---|---|
| `RELEASE_BOT_PAT` | Contents+Workflow+Actions (RW), the 3 app repos — the minimum that makes a tag-push fire `release.yml` | app repos' secrets | 90-day expiry — **calendar it at day ~75** (ch.12) |
| `VORTEX_BOT_PAT` | vortex-only (opens the bump PR as bot identity) | app repos' secrets | same 90-day discipline |
| `ENV_AUDIT_PAT` | fine-grained, Administration: **read-only**, the 3 app repos — what `gate-audit` reads the environments API with (read access alone suffices per docs; the PAT makes the audit's credential explicit and auditable) | app repos' secrets | same 90-day discipline |
| `GITHUB_TOKEN` (free) | per-run; deliberately **cannot** cascade workflow events or read repo variables | automatic | — it's the reason the PATs above exist |

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
   environments API with `ENV_AUDIT_PAT` and fails the chain RED if any
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

**The fix (shipped 2026-11-13/14, lumen `dc187ce` + `b70343e` + `4685e1b`
+ `3ddd65f` + `6da705a`, mellon `5680849` + `850072e` + `b63f506` +
`9c453f3` + `19db63d`, earendil `a8dfaaf` + `7b73c81` + `58c73ad`):** the
fail-closed `gate-audit` job described in §5.5 — every chain's deploy
job `needs: gate-audit`; the audit demands existence AND
`required_reviewers` per environment; absence of config must be RED,
never an implicit yes.

**Owner task — DONE (walked 2026-11-14):** all seven environments
created + protected (required reviewers = you, self-review OFF):
`deploy-foundation`, `deploy-staging`, `deploy-production` (lumen);
`deploy-staging`, `deploy-production` (mellon, earendil) — verified
live via the environments API. Protection rules are the ONE thing no
manifest can set: environments are caller-side config, owned by hand.

**Incident addendum — the machine's shakedown (2026-11-14):** getting
the fixed chain green surfaced three more failure classes, all walked:

- **`startup_failure`, zero jobs, nothing to read.** The gate-audit job
  declared `permissions: environments: read` — **not a valid
  GITHUB_TOKEN scope**. The Actions parser rejects the whole workflow
  file, so EVERY run of EVERY tag died before a single job spun up
  (lumen v3.0.0→v4.0.0's releases never built; the last "success" was
  the last commit without the key). An unrecognized permissions key
  doesn't warn — it kills the file. Fix: lumen `4685e1b`, mellon
  `b63f506`, earendil `58c73ad`.
- **The stale-pin blind alley, then the sed overreach.** `release.yml`
  still pinned anvil `728231b0` (pre-`bases/`-rename), so
  `deploy-plan`'s render validation demanded the old `applications/*`
  tree and failed with ten phantom `MISSING` lines. The re-pin sed then
  flattened every action ref to `publish-image` — the plan jobs
  docker-built the vortex checkout (`open Dockerfile: no such file`).
  Doctrine: bulk re-pins get the per-job mapping VERIFIED —
  `build=publish-image`, `deploy-plan-<env>=deploy-plan`,
  `deploy-<env>=deploy-bump`. Fix: lumen `6da705a`, mellon `19db63d`,
  earendil `58c73ad` (all refs → anvil `829fa28`).
- **An audit's first red can be the truth.** With the pipeline healed,
  gate-audit went RED on all three chains — CORRECTLY. The environments
  existed but had no required reviewers configured (a redacted-body
  theory was investigated and disproven: the environments API needs
  only read access, so the verdict was ground truth). The fix was
  Settings → Environments, not code. Configure, never suppress.

After the environments were protected, the full ladder ran green the
same day: **v4.0.1** (lumen, #21–#23), **v3.0.1** (mellon, #19–#20),
**v1.2.0** (earendil, #24–#25) — every bump PR born of a PARKED chain
and auto-merged. #14–#18 are superseded (merged 2026-11-13/14); the
unattended-PR question is closed.

Next → [10 Observability](10-observability.md)
