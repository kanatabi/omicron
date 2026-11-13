---
tags: [runbook, apps, first-release]
updated: 2026-11-13
status: rehearsal-proven shape (walk ledger); VPS = first real instance —
  every check below is written to be run for the first time, not trusted
---

# 06 · Apps Land & First Release — the cluster earns its keep

Chapters 04–05 built the machine: foundation hub synced, its waves 0–1
healthy, vault seeded, store Ready. This chapter applies **the second
hub** and watches the application plane land, proves each app actually
works *before* the world can see it, and ships the first released version
of each. Nothing here publishes a public door — that's chapter 07, on
purpose: you get to debug with the firewall still the only audience.

## 1. Apply hub #2 and watch the apps land

The `ClusterSecretStore bao` is Ready and seeded (ch. 05 §8 just said Go —
and nothing here existed while the vault was empty; that's the two-hub
order working). Second manual apply:

```bash
kubectl apply -f bootstrap/apps-hub-apps.yaml
kubectl -n argocd get applications -w   # lumen w0, then earendil+mellon+certificates w1, then observability w2 → Synced/Healthy
kubectl get pods -A                     # no CrashLoopBackOff, no ImagePullBackOff
```

The five apps of `vortex/apps/applications/` sync in — everything rolls
onto real values on its very first sync, because the seed happened at the
entrypoint boundary, not by wave-number luck.

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
`rollout restart`).

## 2. The private smoke test (four doors, none public yet)

Reach things the way an operator does at this stage — `kubectl port-forward`
over the admin road (the Access-from-Laptop chapter's tunnels; never a DNS
record, never a firewall hole):

```bash
kubectl -n lumen port-forward svc/lumen-http-server 8080:80
curl -s localhost:8080/api/posts | head -c 200       # API answers with JSON (contract: /api/posts)
kubectl -n earendil port-forward svc/earendil-web-server 3000:80
curl -s localhost:3000/ | grep -o '<title>[^<]*'     # SSR renders the blog shell
```

✅ **Checklist — all four before "first release" means anything:**

- [ ] **Pods run released tags:**
      `kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u`
      shows `ghcr.io/kanatabi/<app>:v…` pins — tags, never `:latest`
      (`:latest` is tooling-only; the releases chapter explains why).
- [ ] **The feed renders:** the earendil home page lists posts (SSR'd —
      `curl` output contains article markup, not just a skeleton).
- [ ] **Search returns the published post:** publish one test post through
      the portal (or the seed content if the backend ships it), then
      `curl -s 'localhost:8080/api/search?q=<a word only that post has>'`
      hits. This proves the whole chain: lumen → meilisearch index →
      query — the foundation's wave-1 stateful pair (lumen-db + meilisearch)
       doing exactly their jobs.
- [ ] **Portal matrix green:** mellon's configs/vault page (via
      port-forward to `svc/mellon-web-server`) lists a row for **every**
      `kv/<app>/production` path ch. 05 seeded — including **grafana** and
      **cert-manager**. That's the `/admin/bao` relay (lumen `ListPaths`
      over `kv/metadata`) proving the vault and the portal agree. A missing
      row = off-contract seed path spelling, fixed in the vault (ch. 05 §7).

The certificates + observability apps are *present but not yet meaningful*
here: no cert-manager objects issue until the DNS token + public domains
exist (ch. 07), and Grafana's door needs Access. Both park in a
**visibly-waiting** state (Order pending / pod up, host unreachable), which
is honest, not broken.

## 3. The first release of each app — pointer, not repetition

You may be running dev-built images; from now on the cluster only ever
moves by **released `vX.Y.Z` tags** pushed through the chain: approve one
bump job → tag → evidence job → deploy gate → auto-merged pin PR → Argo
syncs in ~3 min. The full ritual — the four protected environments per
repo (three bump + `deploy`, **one env per job**),
`RELEASE_BOT_PAT` and why GITHUB_TOKEN tags are silent no-deploys, the
"approve one, decline two by hand" habit, the auto-merge guards and its
kill switch, the fail-open reviewer check — lives in
**[09 · Releases](09-releases.md)**. Read it before your first approve
click; it's short and every paragraph is scar tissue.

First-release specifics for this chapter:

1. **Birth numbers are a human ceremony** (releases §2): no tags yet →
   `minor`/`patch` approves to **v0.1.0**, `major` to **v1.0.0**. Pick the
   birth number per app; earendil/mellon/lumen each ship their first pin
   this way.
2. **GHCR packages must be public** for anything the cluster pulls —
   the §1 `ImagePullBackOff` story is the release-chain one-timer; do it
   before the first tag lands.
3. After each app's bump PR merges, ✅ re-run §1's watch commands:
   pod age resets, image tag matches the release, all four §2 checks still
   pass. Three apps rolling to tags = the estate is *released*, not just
   *assembled*.

> **Why release before going public:** the traffic-anatomy chapter (07)
> opens real doors at real domains. Debugging a mis-seeded env var on your
> own laptop over port-forward costs nothing; doing it with the whole
> internet watching costs readers. And the released-tag trail means if you
> find a bug at the door, rollback is a `git revert` in vortex, not an
> incident archaeology dig.

## 4. The config-only bump — when only the *values* moved

A portal save to `kv/<app>/production` creates head vN — but Git's
**declared** config epoch (the `omicron/config.epoch` pod-template
annotation + the gate's matching `--declared` arg in
`overlays/production/<app>/`) still says N−1, and nothing rolls to pick
the rendered config up. The config-only bump exists for exactly that:
**no new image** — values and their declared epoch land together.

1. GitHub → `release.yml` → **Run workflow**: dispatch from the EXISTING
   latest tag and fill the optional `config-epoch` input with the number
   the portal matrix shows (leave it empty for normal image releases).
2. The job opens a PR that flips the **epoch pair** — BOTH lines in one
   commit — and bumps the `lumen`-tag LOCKSTEP lines in every
   `overlays/production/*/images:` stanza. Why restated per overlay: the
   gate container runs the lumen binary at deliberately the SAME tag
   the lumen app itself ships (a gate reading config with a stale
   decoder is how drift starts), and kustomize base image mappings do
   **not** reach component-rendered Jobs — so each overlay re-states the
   mapping in its own `images:` stanza, and CI asserts the pair's
   equality: a half-bump is red.
3. Merge. At the next sync the **PreSync gate** (`components/config-gate`
   — wired into the three production app overlays; ch. 07's config-epoch
   section documents it) validates with the same binary the app ships:
   `lumen config check-epoch --app <app> --env production --declared N`
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
   template carries the new epoch.

The auto-merge fence rides this flow too, widened by **PATTERN only**:
files `applications/*/kustomization.yaml` + `overlays/production/<app>/*.yaml`
(the app parsed from the bump branch), lines inside the `images:` stanza ∪
a `config.epoch` line ∪ a `--declared` line. No app is ever enumerated.

> **Why this is safe to leave to habit:** the four contracts close every
> lie path — the lock refuses writes behind your back, head is whatever
> the vault actually serves, restore is the only way to speak the pinned
> content forward, and the gate refuses to sync a Git that disagrees.
> In the design's own words: **pin = lock, head = truth, restore = the
> only road back, gate = where you can't lie.**

## 5. What this chapter deliberately did NOT do

- **No public records, no DNS, no certificates issued** — chapter 07, in
  the order it says (GATE #10, quoted from `apps/applications/mellon-app.yaml`'s
  binding note: "DNS first, real cert, GATE #10 before the first login").
- **No backups wired yet** — [08 · Backups](08-backups.md) owns restic → R2;
  it should run before you pour real posts in, and the calendar says when.
- **No dashboards looked at yet** — Grafana waits for its Access door
  (ch. 07's Act 4), then the Observability chapter decorates it.

Next → [07 · Go Public](07-go-public.md)
