---
tags: [runbook, index, checklist]
updated: 2026-11-14
status: execution map — Track A steps are the k3d-rehearsed path (the
  dual-environment shape is walked fresh this round); Track B is PROVEN only
  when walked on the real VPS (tick it there, same ledger style).
---

# 00a · Run Order — the execution sheet

> **Why this sheet exists:** chapter numbers are the build order, but the
> estate is built **twice**: once on your laptop (free to break), once on
> the VPS (not). This page is the map of both walks — each step names its
> chapter, a checkbox, and the state that must be true before you continue.
> Track A is mandatory; Track B is the same knowledge on real metal.

> **The three-plane reality (Phase 11):** `vortex/environments/` holds
> **foundation** (shared plumbing), **staging** and **production** (per-env
> app trees). Hubs match: `apps-hub-foundation.yaml`,
> `apps-hub-observability.yaml` (the eyes — a manual GATE, applied only
> after the grafana four-key seed), `apps-hub-staging.yaml`,
> `apps-hub-production.yaml`. Entry order is always **foundation hub →
> SEED THE VAULT → GRAFANA FOUR-KEY SEED → observability hub → staging
> and/or production hubs**. One cluster can run any
> combination — moving an environment to another cluster is an Argo
> destination edit, zero manifest changes. Track A below deliberately runs
> **both** staging and production on one cluster, because the thing worth
> rehearsing is their ISOLATION (A10).

## Track A — LOCAL REHEARSAL (mandatory, k3d)

Everything here runs on the laptop (the 32 GB box; k3d needs the headroom
because the full production fleet fits in ~4 GB and you want slack, not
swap). The point: **the rehearsal runs the SHIPPED shape** — the same hub
files, the same `environments/{foundation,staging,production}/*` trees, the
same waves, the same vault bootstrap. See the why-box at the bottom.

- [ ] **A1 · install k3d** — [01 §4](01-prerequisites.md).
  `wget -qO - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
  ✅ after: `k3d version` prints, Docker daemon reachable.

- [ ] **A2 · create the cluster** — [03 §1](03-k3s.md), the full command:

  ```bash
  k3d cluster create omicron \
    --servers 1 --agents 0 \
    --k3s-arg "--disable=servicelb@server:0" \
    --k3s-arg "--disable=traefik@server:0" \
    -p "80:80@loadbalancer" -p "443:443@loadbalancer"
  ```

  ✅ after: `kubectl get nodes` → `k3d-omicron-server-0` **Ready**, and the
  printed k3s image is on the **v1.37** line (same channel as the VPS plan).

- [ ] **A3 · clone vortex** — [04](04-gitops.md): `git clone
  https://github.com/kanatabi/vortex.git`. Plain HTTPS is fine — the repo
  is **public** and Argo therefore needs **no repo credentials** (the iron
  law, [00](00-overview.md): values live only in Bao).
  ✅ after: `vortex/bootstrap/apps-hub-foundation.yaml`,
  `apps-hub-observability.yaml`, `apps-hub-staging.yaml` and
  `apps-hub-production.yaml` all exist on disk
  (the env hubs; `apps-hub.yaml` is the 3-node BLUEPRINT entrypoint, not
  used on this track), and `vortex/overlays/` does **not** (it died with the
  env model — if your clone shows one, you cloned an old ref).

- [ ] **A4 · install Argo CD (pinned)** — [04 §1](04-gitops.md):
  `kubectl apply -k platform/argocd/ --server-side --force-conflicts`.
  ✅ after: argocd namespace green; the controller is a StatefulSet — check
  `sts`, not `deploy`.

- [ ] **A5 · apply the FOUNDATION hub — entrypoint #1** —
  [04 §3](04-gitops.md):

  ```bash
  kubectl apply -f bootstrap/apps-hub-foundation.yaml
  ```

  The first of the manual applies — together with A8.5's and A9's, this is
  the documented chicken-and-egg exception (GitOps cannot bootstrap the
  cluster that hosts its own root apps). It syncs `apps/foundation/`
  non-recursively: **6 Applications** in waves — 0: openbao +
  external-secrets · 1: lumen-db + meilisearch + secrets-plane (the `bao`
  store) · 2: **lumen-admin** (the estate's single Control
  Plane; observability moved to its OWN hub — A8.5). Wave 2 waits **structurally**: the store's Ready condition gates
  it, so the admin fleet cannot boot before `kv/lumen/shared` exists.
  **Do NOT apply the env hubs yet** — the split exists precisely so the
  vault ritual (A7) happens *between* the entrypoints: seed-before-apps
  becomes structural, not a wave number.
  ✅ after: foundation wave 0 healthy; `openbao` pod Running but **SEALED**
  and the `bao` ClusterSecretStore **not-Ready** — that is the expected
  state until A7, not a bug; foundation wave 2 (lumen-admin)
  parked, waiting on that store.

- [ ] **A6 · node-pool label** — [03 §3](03-k3s.md):
  `kubectl label node k3d-omicron-server-0 node-pool=platform --overwrite`.
  (The env overlays collapse placement via `components/single-node`, so
  nothing Pending without it — label anyway: parity with the VPS and a
  free hedge for scale-out.) ✅ after: node shows the label.

- [ ] **A7 · vault bootstrap (M3)** — [05 §2–§7](05-vault.md): init (3
  shares, threshold 2), unseal, policies + AppRoles, mint pairs, then the
  FULL seed contract for this walk: `kv/lumen/shared` + `kv/lumen/staging`
  + `kv/lumen/production` + `kv/earendil/{staging,production}` +
  `kv/mellon/shared` + `kv/mellon/{staging,production}` + the foundation
  singletons (`grafana/production`, `cert-manager/production`,
  `meilisearch/production`). **ESO fails the whole render on a missing
  property** — every key the [05 §6](05-vault.md) tables name must exist
  BEFORE its hub syncs.
  ✅ after: `bao status` unsealed; ClusterSecretStore `bao` `Ready: True`;
  foundation wave 2 (lumen-admin) rolls in its wake.

- [ ] **A8 · seeded-matrix check** (before any env hub opens) —
  [05 §6–§7](05-vault.md): prove the seed matches the contract: the
  `kv/metadata` listing shows every `kv/<app>/<env>` path §6 seeded,
  and each path's key set diffs clean, key-by-key, against its
  ExternalSecret's `data:` list — nothing extra lives there. (The portal
  matrix row walk joins it after A9, once mellon exists — §7's
  conformance check.) ✅ after: paths + keys == the CRs' declarations.

- [ ] **A8.5 · apply the OBSERVABILITY hub — entrypoint #2 (the GATE)** —
  [04 §3](04-gitops.md), [10 §3](10-observability.md):

  ```bash
  kubectl apply -f bootstrap/apps-hub-observability.yaml
  ```

  Applied BY HAND, only after A7 + A8 are green **and** §6.5's grafana
  four-key put is verified (the two grafana ExternalSecrets `Ready: True`)
  — an ES errors on ANY missing declared key, so an early apply wedges
  the sync op forever (card 11's class; the hub split exists so this
  ordering is a checklist, not a race).
  ✅ after: `kubectl -n argocd get application observability` → Synced;
  the four pods (`alloy`, `grafana`, `loki-0`, `victoria-metrics`) Running;
  port-forward VictoriaMetrics and `up` is 1 for `kubelet`, `cadvisor`,
  `kubelet-resource` and the annotated pods; Grafana's **Estate overview**
  dashboard draws panels.

- [ ] **A9 · apply the ENV hubs — entrypoints #3/#4 — and first release
  (M4)** — [04 §3](04-gitops.md), [06](06-apps-first-release.md):

  ```bash
  kubectl apply -f bootstrap/apps-hub-production.yaml
  kubectl apply -f bootstrap/apps-hub-staging.yaml
  ```

  The production hub syncs `apps/production/` (4 Applications — waves
  restart per hub: 0: lumen · 1: earendil + mellon + certificates) from
  `environments/production/*`; the staging hub syncs `apps/staging/`
  (3 Applications — 0: lumen · 1: earendil + mellon) from
  `environments/staging/*`. Both co-tenant the SAME cluster on purpose —
  suffixed names + the `omicron/env` label keep them apart. Everything
  rolls onto real values because the vault was seeded *before these hubs
  existed* — that ordering is the split's whole point, not luck. Then ship
  one real `vX.Y.Z` through the release machine
  ([09](09-releases.md)) into *this* cluster — the bump PR, the pin, the
  Argo sync, and a config-only bump ([06 §4](06-apps-first-release.md)) —
  rehearsed end to end.
  ✅ after: `kubectl -n argocd get applications` lists all **fifteen**
  (6 + 1 + 4 + 3), all Synced/Healthy; and
  the edge answers — `curl -s -o /dev/null -w '%{http_code}\n'
  http://localhost/` → **404 from Traefik** (edge up, no host matched; with
  `-H "Host: gofar.id"` you get production earendil, with
  `-H "Host: staging.gofar.id"` the staging twin).

- [ ] **A10 · the isolation proof (the point of running both here)** — the
  rehearsal must SHOW, not assume, that staging and production are separate
  planes on one cluster:

  - [ ] write a post in **staging-console** (mellon-staging) → it appears
        on `staging.gofar.id` only; `gofar.id` never shows it;
  - [ ] the staging cms indexed it into **posts-staging** while production
        reads **posts** (`curl` the Meilisearch pod's index stats or use
        each site's search);
  - [ ] a media upload on staging lands under the **`staging/`** prefix in
        the shared bucket;
  - [ ] an epoch flip in ONE env's overlay gates ONLY that env's rollout
        (the other env's syncs stay green through it);
  - [ ] Grafana: every dashboard's env filter splits the two fleets (the
        `omicron/env` pod label is the attribution — [10](10-observability.md)).

  ✅ after: all five hold — you have rehearsed the model, not just the
  YAML.

- [ ] **A11 · optional Level-2 rehearsal** — a **named Cloudflare Tunnel**
  from the laptop cluster lets you rehearse the REAL public path before any
  VPS exists: proxy behavior, managed challenges, Access policies, and real
  Let's Encrypt certs (DNS-01 needs no open port — the `certificates` app
  works from a laptop, staging included). The cheaper Level-1 trick is also
  valid: real certs + `/etc/hosts` entries pointing
  `gofar.id`/`staging.gofar.id`/`console`/`anor` at 127.0.0.1. Details in
  [07](07-go-public.md).
  ✅ after: `https://gofar.id` AND `https://staging.gofar.id` green on the
  laptop, same Ingress rules the VPS will use.

### Deliberately SKIPPED on Track A

| Skipped | Why it isn't here |
|---|---|
| [02](02-security.md) hardening (SSH, ufw, swap…) | those are the *VPS's* front-door locks — the laptop cluster has no public SSH and no firewall job |
| DNS records + nameservers | nothing public is pointed; records land at M5 ([07](07-go-public.md)) |
| Managed challenges + Access | edge-layer features of the public path — M5; A11 can optionally rehearse them |
| cert issuance (default run) | the fleet tolerates certs not existing yet; A11/Level-1 makes issuance rehearsalable when you want it |
| restic → R2 ([08](08-backups.md)) | M6 "when boring" — a rehearsal cluster you can delete is not a backup target |

> **Why we rehearse the SHIPPED shape locally, not a dev sketch:**
> the failure this protects against is *shape drift* — rehearsing one old
> `overlays/local` tree and shipping another environment meant the first
> time you met the real waves, the real `certificates` app, and the real
> secrets-plane gating was on production day. k3d runs the **same k3s
> image** and the **same YAML chain** (foundation hub → seed → both env
> hubs → `environments/{foundation,staging,production}/*` +
> `components/single-node` + `components/config-gate`), and because the
> model is cluster-agnostic it can run staging AND production together —
> so the only deltas left for the VPS are the host-level ones (02's locks,
> hostNetwork publish) — cheap, boring, and exactly what Track B walks. An
> accident here costs `k3d cluster delete omicron`; on the VPS it costs an
> afternoon.

> **Playground note (owner ruling, 2026-11-14):** the old minikube
> playground currently runs the **RETIRED** tree — its Argo errors
> `overlays/local/lumen: app path does not exist`, which is the retired
> shape talking, not a bug. Its vault holds only disposable `kv/*/dev`
> scratch (the dev plane is gone) — nothing to rescue. The ruling: the next
> live walk of the new model repoints that box to **staging** (foundation
> hub → seed → staging hub), which is exactly the A5→A9 choreography with
> one env hub. Do not treat its current redness as estate breakage.

## Track B — VPS (later; same steps, real metal, nothing optional)

- [ ] **B1 · M0** — [01](01-prerequisites.md): VPS bought (4c/8G/80G,
  Ubuntu 24.04); Cloudflare site + both R2 buckets + both scoped tokens
  already exist from M0. ✅ `ssh root@<ip>` works.
- [ ] **B2 · M1-hardening** — [02](02-security.md): the chapter Track A
  skipped, first walk on the box. ✅ key-SSH only, CF-only 443, 6443 dark.
- [ ] **B3 · M1-cluster** — [03 §2](03-k3s.md): k3s installer, channel
  v1.37, label, local-path truth, Traefik hostNetwork variant. ✅ checkpoint
  green; same fleet shape A5 will recognize.
- [ ] **B4 · M2** — [04](04-gitops.md): Argo install + apply
  `bootstrap/apps-hub-foundation.yaml` (the env hubs get applied only after
  B5 — foundation first, vault ritual between, env planes after; that entry
  order IS the seed-before-apps invariant). ✅ foundation waves 0–1 healthy,
  `bao` store NOT-Ready, wave 2 parked — the vault is what's missing.
- [ ] **B5 · M3** — [05](05-vault.md): init/unseal/AppRole/seed — **freshly
  generated values**, reuse nothing from the rehearsal — for every
  environment this box will run (production at minimum; plus staging and
  `kv/lumen/shared` if the VPS hosts both), plus A8's seeded-matrix check.
  ✅ store Ready, paths + keys match the CRs, foundation wave 2 rolls.
- [ ] **B6 · M4** — [06](06-apps-first-release.md): apply
  `bootstrap/apps-hub-production.yaml` (+ the staging hub if this box runs
  it), apps green; the first production release rides the machine rehearsed
  in A9. ✅ four production Ingress routes live (`gofar.id`+`www`,
  `console`, `anor`; staging rides the same DNS-01 issuer — real certs from
  day one, no selfsigned anything), still no DNS pointing at the box.
- [ ] **B7 · M5** — [07](07-go-public.md): records, proxy ON, challenges,
  real certs settle, Access on anor, img custom domain. ✅ public doors
  open; Traffic Anatomy verified with your own eyes.
- [ ] **B8 · M6** — [08](08-backups.md): restic init into
  `omicron-backups`, nightly timers, first restore drill. ✅ "when boring."

One rule for both tracks: **never continue from a step whose ✅ is a wish.**
Each expected state is a command you can run and read.

Next → [01 Prerequisites](01-prerequisites.md) (M0) — or straight to
[03 §1](03-k3s.md) if M0 is already done and you just want Track A rolling.
