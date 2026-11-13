---
tags: [runbook, index, checklist]
updated: 2026-11-13
status: execution map — Track A steps are the k3d-rehearsed path; Track B is
  PROVEN only when walked on the real VPS (tick it there, same ledger style).
---

# 00a · Run Order — the execution sheet

> **Why this sheet exists:** chapter numbers are the build order, but the
> estate is built **twice**: once on your laptop (free to break), once on
> the VPS (not). This page is the map of both walks — each step names its
> chapter, a checkbox, and the state that must be true before you continue.
> Track A is mandatory; Track B is the same knowledge on real metal.

## Track A — LOCAL REHEARSAL (mandatory, k3d)

Everything here runs on the laptop (the 32 GB box; k3d needs the headroom
because the full production fleet fits in ~4 GB and you want slack, not
swap). The point: **the rehearsal runs the PRODUCTION shape** — the same
hub file, the same `overlays/production/*`, the same waves, the same vault
bootstrap. See the why-box at the bottom.

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
  ✅ after: `vortex/bootstrap/apps-hub-production.yaml` exists on disk.

- [ ] **A4 · install Argo CD (pinned)** — [04 §1](04-gitops.md):
  `kubectl apply -k platform/argocd/ --server-side --force-conflicts`.
  ✅ after: argocd namespace green; the controller is a StatefulSet — check
  `sts`, not `deploy`.

- [ ] **A5 · apply the hub — production entrypoint** — [04 §2](04-gitops.md):

  ```bash
  kubectl apply -f bootstrap/apps-hub-production.yaml
  ```

  One manual apply, the documented chicken-and-egg exception (GitOps cannot
  bootstrap the cluster that hosts its own root app). It syncs
  `apps/production/` non-recursively: **10 Applications** in waves — 0:
  openbao + external-secrets · 1: lumen-db + meilisearch + secrets-plane ·
  2: lumen + earendil + mellon + certificates + observability.
  ✅ after: wave 0 healthy; wave 2 red with `could not get secret data from
  provider` — **that is the expected state** until A7, not a bug.

- [ ] **A6 · node-pool label** — [03 §3](03-k3s.md):
  `kubectl label node k3d-omicron-server-0 node-pool=platform --overwrite`.
  (The production shape collapses placement via `components/single-node`, so
  nothing Pending without it — label anyway: parity with the VPS and a
  free hedge for scale-out.) ✅ after: node shows the label.

- [ ] **A7 · vault bootstrap (M3)** — [05 §2–§8](05-vault.md): init (3
  shares, threshold 2), unseal, policies + AppRoles, mint pairs, seed
  `kv/<app>/production`, force ES sync, roll pods.
  ✅ after: `bao status` unsealed; ClusterSecretStore `bao` Ready; every
  ExternalSecret `Synced=True, Ready=True`.

- [ ] **A8 · apps + first release (M4)** — [06](06-apps-first-release.md):
  wave 2 rolls with real env; then ship one real `vX.Y.Z` through the
  release machine ([09](09-releases.md)) into *this* cluster — the bump PR,
  the pin, the Argo sync, rehearsed end to end.
  ✅ after: `kubectl -n argocd get applications` all Synced/Healthy; and
  the edge answers — `curl -s -o /dev/null -w '%{http_code}\n'
  http://localhost/` → **404 from Traefik** (edge up, no host matched; with
  `-H "Host: gofar.id"` you should get earendil instead).

- [ ] **A9 · optional Level-2 rehearsal** — a **named Cloudflare Tunnel**
  from the laptop cluster lets you rehearse the REAL public path before any
  VPS exists: proxy behavior, managed challenges, Access policies, and real
  Let's Encrypt certs (DNS-01 needs no open port — the `certificates` app
  works from a laptop). The cheaper Level-1 trick is also valid: real certs
  + `/etc/hosts` entries pointing `gofar.id`/`console`/`anor` at
  127.0.0.1. Details in [07](07-go-public.md).
  ✅ after: `https://gofar.id` green on the laptop, same Ingress rules the
  VPS will use.

### Deliberately SKIPPED on Track A

| Skipped | Why it isn't here |
|---|---|
| [02](02-security.md) hardening (SSH, ufw, swap…) | those are the *VPS's* front-door locks — the laptop cluster has no public SSH and no firewall job |
| DNS records + nameservers | nothing public is pointed; records land at M5 ([07](07-go-public.md)) |
| Managed challenges + Access | edge-layer features of the public path — M5; A9 can optionally rehearse them |
| cert issuance (default run) | the fleet tolerates certs not existing yet; A9/Level-1 makes issuance rehearsalable when you want it |
| restic → R2 ([08](08-backups.md)) | M6 "when boring" — a rehearsal cluster you can delete is not a backup target |

> **Why we rehearse the PRODUCTION shape locally, not a dev sketch:**
> the failure this protects against is *shape drift* — rehearsing
> `overlays/local` and shipping `overlays/production` means the first time
> you meet the real waves, the real `certificates` app, and the real
> secrets-plane gating is on production day. k3d runs the **same k3s
> image** and the **same YAML chain** (hub → `apps/production/` →
> `overlays/production/*` + `components/single-node`), so the only deltas
> left for the VPS are the host-level ones (02's locks, hostNetwork
> publish) — cheap, boring, and exactly what Track B walks. An accident
> here costs `k3d cluster delete omicron`; on the VPS it costs an afternoon.

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
  `bootstrap/apps-hub-production.yaml` (yes — the *production* hub; there is
  no other entrypoint now). ✅ waves up, wave 2 waiting on the vault.
- [ ] **B5 · M3** — [05](05-vault.md): init/unseal/AppRole/seed — **freshly
  generated values**, reuse nothing from the rehearsal. ✅ all ES Synced.
- [ ] **B6 · M4** — [06](06-apps-first-release.md): apps green; the first
  production release rides the machine rehearsed in A8. ✅ four Ingress
  routes exist, still no DNS pointing at the box.
- [ ] **B7 · M5** — [07](07-go-public.md): records, proxy ON, challenges,
  real certs settle, Access on anor, img custom domain. ✅ public doors
  open; Traffic Anatomy verified with your own eyes.
- [ ] **B8 · M6** — [08](08-backups.md): restic init into
  `omicron-backups`, nightly timers, first restore drill. ✅ "when boring."

One rule for both tracks: **never continue from a step whose ✅ is a wish.**
Each expected state is a command you can run and read.

Next → [01 Prerequisites](01-prerequisites.md) (M0) — or straight to
[03 §1](03-k3s.md) if M0 is already done and you just want Track A rolling.
