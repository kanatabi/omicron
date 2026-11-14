---
tags: [runbook, apps, first-release]
updated: 2026-11-14
status: rehearsal-proven shape (walk ledger); VPS = first real instance —
  every check below is written to be run for the first time, not trusted;
  re-cut for the three-plane env model (2026-11-14)
---
# 06 · Apps Land & First Release — the cluster earns its keep

Chapters 04–05 built the machine: foundation hub synced, its waves 0–1
healthy, vault seeded, store Ready — which also let foundation **wave 2**
(observability + lumen-admin) roll: the Control Plane is up BEFORE this
chapter, by construction. This chapter applies **the env hubs** and watches
the application planes land, proves each app actually works *before* the
world can see it, and ships the first released version of each. Nothing
here publishes a public door — that's chapter 07, on purpose: you get to
debug with the firewall still the only audience.

> **Playground state (owner ruling, 2026-11-14):** the minikube box still
> runs the RETIRED tree — its Argo reports `overlays/local/lumen: app path
> does not exist`, which is the deleted shape talking (expected, not estate
> breakage). Its vault holds only disposable `kv/*/dev` scratch — nothing
> to rescue. The ruling: repoint it to **staging** (foundation hub → seed →
> staging hub) as the first live walk of the new model. On that box, the
> env hub below is `apps-hub-staging.yaml`; on the VPS it is
> `apps-hub-production.yaml` (± staging). (The observability hub, #2, is
> already applied by then — 00a A8.5.)

## 1. Apply the env hub(s) and watch the apps land

The `ClusterSecretStore bao` is Ready and seeded (ch. 05 §8 just said Go —
and nothing here existed while the vault was empty; that's the entry
order working). Manual applies #2/#3:

```bash
kubectl apply -f bootstrap/apps-hub-production.yaml   # lumen w0 → earendil+mellon+certificates w1
kubectl apply -f bootstrap/apps-hub-staging.yaml      # lumen w0 → earendil+mellon w1  (if this cluster runs staging too)
kubectl -n argocd get applications -w                 # every hub's waves restart at 0 → Synced/Healthy
kubectl get pods -A                                   # no CrashLoopBackOff, no ImagePullBackOff
```

The production hub's four Applications and the staging hub's three sync in
— everything rolls onto real values on its very first sync, because the
seed happened at the entrypoint boundary, not by wave-number luck. In the
pods you should SEE the env model: suffixed names everywhere
(`lumen-http-server-production`, `…-staging`, `earendil-web-server-staging`
…) co-tenanting the same namespaces with the cms fleets, while the one
Control Plane — `lumen-admin` — answers from the foundation plane
unsuffixed.

> **If a pod sits `ImagePullBackOff`:** the classic cause is a **private
> GHCR package** — images inherit repo visibility on first push, and pods
> carry no registry credentials by design (public surfaces are the only
> doors, and ghcr public pulls need none). Fix = flip the GHCR package to
> public (owner one-timer, releases chapter §5). Do not "fix" it by adding
> pull secrets to the manifests.

If an app is Synced but its pods loop with empty-config errors, the vault
story from ch. 05 isn't finished — `kubectl describe externalsecret -n
<ns>` tells you which one never materialized (and remember §8 there:
**envFrom binds only at container start**, so post-seed pods need a
`rollout restart`). One env-model signature to recognize: an ES red with
*"key not found"* while the app is otherwise healthy = a path seeded for
the WRONG env (or the shared path skipped) — ESO fails the whole render on
one missing property, which is exactly why ch. 05's tables are the law.

## 2. The private smoke test (doors none of the world can see yet)

Reach things the way an operator does at this stage — `kubectl port-forward`
over the admin road (the Access-from-Laptop chapter's tunnels; never a DNS
record, never a firewall hole). Note the SUFFIXED names — the Naming
contract says `nameSuffix` rewrites metadata.name only, and these are the
rendered results:

```bash
# the cms plane (production shown; staging = the -staging twins):
kubectl -n lumen port-forward svc/lumen-http-server-production 8080:80
curl -s localhost:8080/api/posts | head -c 200       # API answers with JSON (contract: /api/posts)
# the Control Plane (foundation, unsuffixed — and NO ingress, ever):
kubectl -n lumen port-forward svc/lumen-admin 8081:80
curl -s -o /dev/null -w '%{http_code}\n' localhost:8081/api/posts   # 404: admin serves NO content routes
# the readers:
kubectl -n earendil port-forward svc/earendil-web-server-production 3000:80
curl -s localhost:3000/ | grep -o '<title>[^<]*'     # SSR renders the blog shell
```

✅ **Checklist — all five before "first release" means anything:**

- [ ] **Pods run released tags:**
      `kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u`
      shows `ghcr.io/kanatabi/<app>:v…` pins — tags, never `:latest`
      (`:latest` is tooling-only; the releases chapter explains why).
      Gate containers carry the SAME tag as their env's lumen (lockstep,
      §4).
- [ ] **The feed renders:** the earendil home page lists posts (SSR'd —
      `curl` output contains article markup, not just a skeleton).
- [ ] **Search returns the published post:** publish one test post through
      the portal (or the seed content if the backend ships it), then
      `curl -s 'localhost:8080/api/search?q=<a word only that post has>'`
      hits. This proves the whole chain: cms lumen → meilisearch index (by
      its SEEDED name — `posts` on production, `posts-staging` on staging)
      → query — the foundation's wave-1 stateful pair (lumen-db +
      meilisearch) doing exactly their jobs.
- [ ] **The role split holds:** a portal login mints its session ONLY
      through lumen-admin (`/admin/session*` routes to `ADMIN_URL` per
      mellon's routing table); a cms pod asked to verify answers via
      `POST /admin/session/verify` (≤30 s verdict cache); scale
      `lumen-admin` to zero and a fresh cms admin call answers **503 —
      fail closed**, never "probably still valid". And a cms DB has NO
      `users` table (role-split migrations — structurally impossible to
      diverge).
- [ ] **Portal matrix green:** mellon's configs/vault page (via
      port-forward to `svc/mellon-web-server-production`) lists a row for
      **every** path ch. 05 seeded — `lumen/shared`, `lumen/staging`,
      `lumen/production`, `earendil` + `mellon` per env, plus **grafana**
      and **cert-manager**. That's the `/admin/bao` relay (lumen-admin's
      `ListPaths` over `kv/metadata`) proving the vault and the portal
      agree. A missing row = off-contract seed path spelling, fixed in the
      vault (ch. 05 §7).

The certificates objects and the observability stack are *present but not
yet meaningful* here: no cert-manager object issues until the DNS token +
public domains exist (ch. 07), and Grafana's door needs Access. Both park
in a **visibly-waiting** state (Order pending / pod up, host unreachable),
which is honest, not broken. And per [00a A10](00a-run-order.md): if this
cluster runs BOTH env hubs, this is where the isolation proof lives — a
staging post appears on staging's door only.

## 3. The first release of each app — pointer, not repetition

You may be running dev-built images; from now on the cluster only ever
moves by **released `vX.Y.Z` tags** pushed through the chain: approve one
bump job → tag → **gate-audit** + evidence job → per-env deploy park →
auto-merged (or hand-merged) pin PR → Argo syncs in ~3 min. The full
ritual — the protected environments per repo (three bump environments +
**one deploy environment PER TARGET ENVIRONMENT**: lumen parks on
`deploy-foundation|deploy-staging|deploy-production`, earendil/mellon on
`deploy-staging|deploy-production` — and they must be protected BEFORE
the first tag, because gate-audit fails the chain closed otherwise),
`RELEASE_BOT_PAT` and why GITHUB_TOKEN tags are silent no-deploys, the
auto-merge guards and its kill switch — lives in
**[09 · Releases](09-releases.md)**. Read it before your first approve
click; it's short and every paragraph is scar tissue (one paragraph is
now literally an incident record).

First-release specifics for this chapter:

1. **Birth numbers are a human ceremony** (releases §2): no tags yet →
   `minor`/`patch` approves to **v0.1.0**, `major` to **v1.0.0**. Pick the
   birth number per app; earendil/mellon/lumen each ship their first pin
   this way.
2. **GHCR packages must be public** for anything the cluster pulls —
   the §1 `ImagePullBackOff` story is the release-chain one-timer; do it
   before the first tag lands.
3. After each app's bump PR merges, ✅ re-run §1's watch commands:
   pod age resets, image tag matches the release, all §2 checks still
   pass. Three apps rolling to tags = the estate is *released*, not just
   *assembled*. A lumen release parks ONE job per environment it should
   reach — approving `deploy-staging` but not `deploy-production` is a
   legitimate, deliberate half-release (that's what the ladder is).

> **Why release before going public:** the traffic-anatomy chapter (07)
> opens real doors at real domains. Debugging a mis-seeded env var on your
> own laptop over port-forward costs nothing; doing it with the whole
> internet watching costs readers. And the released-tag trail means if you
> find a bug at the door, rollback is a `git revert` in vortex, not an
> incident archaeology dig.

## 4. The config-only bump — when only the *values* moved

A portal save to `kv/<app>/<env>` creates head vN — but Git's **declared**
config epoch still says N−1, and nothing rolls to pick the rendered config
up. The declared epoch is the **TRIO**, per environment: the pod-template
`omicron/config.epoch` annotation + the PreSync gate's `--declared` arg +
the ExternalSecret's `omicron/config.epoch` annotation, all three in the
same overlay files, **byte-equal** (anvil's structural class-4 check fails
any half-bump — 2-of-3 is red). The config-only bump exists for exactly
that: **no new image** — values and their declared epoch land together.

1. GitHub → the app's `release.yml` → **Run workflow**: dispatch from the
   EXISTING latest tag, choose the target environment(s), and fill the
   optional `config-epoch` input with the number the portal matrix shows
   (leave it empty for normal image releases). The input is honored **only
   for a single-environment dispatch** — a trio value is env-scoped (the
   values legitimately differ: production's lumen trio sits at `7`,
   everything else at `0`), so a multi-env dispatch refuses it.
2. The chain opens one bump PR **per environment** on branch
   `bump/<app>-<env>-<tag>`, each editing ONLY `environments/<env>/**`:
   the epoch TRIO flips — all three lines, one commit — and the `lumen`
   image `newTag` LOCKSTEP lines in that env's overlay dirs move in the
   same commit (the gate container runs the lumen binary at deliberately
   the SAME tag the lumen app itself ships — a gate reading config with a
   stale decoder is how drift starts; and since the bases pin nothing,
   every overlay states its own `images:` stanza). Overlays are
   canonicalized, so a bump diff reads as single `newTag` lines — review
   the diff, it IS the change.
3. Merge (auto-merge if `DEPLOY_AUTOMERGE=on`; by hand otherwise). At the
   next sync the **PreSync gate** (`components/config-gate`, wired into
   every env overlay — foundation included, where it runs
   `--app lumen --env shared`) validates with the same binary the app
   ships: `lumen config check-epoch --app <app> --env <env> --declared N`
   — pass iff **N == head AND (pin unset OR pin == head)**. A declared
   `0` is the not-yet-under-contract shape: it passes iff NO pin is set.
   Failure prints exactly one remedy line and **blocks the sync** until
   aligned — the machine tells you which road:
   - declared ≠ head → *"align the epoch bump with the vault (materialize
     the pin via unpin→restore→save, or re-dispatch with the number the
     matrix shows)"*
   - pinned below head → *"pin is a lock and it disagrees with head:
     unpin to release the head, or restore the pinned version's content
     as new head"*
4. Gate green → the rollout restarts onto the new pod-template annotation
   and picks up the rendered config. ✅ check:
   `kubectl -n <app> get jobs config-gate` → Complete, and the deployment's
   template carries the new epoch. And because the flip was env-scoped,
   ✅ the OTHER environment's pods sit untouched — an epoch flip gates
   ONLY that env's rollout (00a A10's fourth proof).

The auto-merge fence rides this flow too, and it is **env-scoped from the
branch name**: files `environments/<env>/**` ONLY (the env parsed from
`bump/<app>-<env>-<tag>`), lines inside the `images:` stanza ∪ a TRIO line
(`config.epoch` or `--declared`). No app is ever enumerated; an unparseable
env makes the merger BAIL to a human.

> **Why this is safe to leave to habit:** the four contracts close every
> lie path — the lock refuses writes behind your back, head is whatever
> the vault actually serves, restore is the only way to speak the pinned
> content forward, and the gate refuses to sync a Git that disagrees.
> In the design's own words: **pin = lock, head = truth, restore = the
> only road back, gate = where you can't lie.**

## 5. What this chapter deliberately did NOT do

- **No public records, no DNS, no certificates issued** — chapter 07, in
  the order it says (GATE #10, quoted from `apps/production/mellon-app.yaml`'s
  binding note: "DNS first, real cert, GATE #10 before the first login").
- **No backups wired yet** — [08 · Backups](08-backups.md) owns restic → R2;
  it should run before you pour real posts in, and the calendar says when.
- **No dashboards looked at yet** — Grafana waits for its Access door
  (ch. 07's Act 4), then the Observability chapter decorates it.

Next → [07 · Go Public](07-go-public.md)
