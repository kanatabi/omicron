---
tags: [runbook, apps, first-release]
updated: 2026-11-13
status: rehearsal-proven shape (walk ledger); VPS = first real instance —
  every check below is written to be run for the first time, not trusted
---

# 06 · Apps Land & First Release — the cluster earns its keep

Chapters 04–05 built the machine: hub synced, waves 0–1 healthy, vault
seeded, store Ready. This chapter watches **wave 2 un-park**, proves each
app actually works *before* the world can see it, and ships the first
released version of each. Nothing here publishes a public door — that's
chapter 07, on purpose: you get to debug with the firewall still the only
audience.

## 1. Watch wave 2 land

The moment `ClusterSecretStore bao` reports Ready (ch. 05 §3.5's ✅), the
five wave-2 apps from `vortex/apps/production/` sync in:

```bash
kubectl -n argocd get applications -w        # lumen, earendil, mellon, certificates, observability → Synced/Healthy
kubectl get pods -A                          # no CrashLoopBackOff, no ImagePullBackOff
```

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
      query — the two wave-1 stateful apps doing exactly their jobs.
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
syncs in ~3 min. The full ritual — the three protected environments,
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

## 4. What this chapter deliberately did NOT do

- **No public records, no DNS, no certificates issued** — chapter 07, in
  the order it says (GATE #10, quoted from `apps/production/mellon-app.yaml`'s
  binding note: "DNS first, real cert, GATE #10 before the first login").
- **No backups wired yet** — [08 · Backups](08-backups.md) owns restic → R2;
  it should run before you pour real posts in, and the calendar says when.
- **No dashboards looked at yet** — Grafana waits for its Access door
  (ch. 07's Act 4), then the Observability chapter decorates it.

Next → [07 · Go Public](07-go-public.md)
