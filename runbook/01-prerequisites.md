---
tags: [runbook, setup]
updated: 2026-11-14
status: M0 · prepare — the buy/create list for both tracks; every item here
  is a dependency of a later milestone, and nothing public is pointed yet.
---

# 01 · Prerequisites — what to buy, create, install (and why each)

> **Why this chapter exists:** every item here is a dependency of something
> later. Creating them up front means the build chapters stay copy-paste,
> and nothing stalls mid-milestone waiting for an email verification.
> **M0 is the *prepare* milestone: buy and create, point nothing.** The
> public records, the challenges, the Access policy and the img domain all
> happen at M5 ([07 Go Public](07-go-public.md)) — deliberately, so the
> cluster is fully rehearsed before anything faces readers.

## 1. The server (VPS)

**Spec floor: 4 vCPU / 8 GB RAM / 80 GB SSD / IPv4 + IPv6, Ubuntu 24.04 LTS.**

| Spec | Why the number |
|---|---|
| 4 vCPU | Kubernetes + Postgres + search + vault + *monitoring* all on one box; 2 CPUs works but the monitoring stack feels it |
| 8 GB RAM | the app stack asks ≈ 2–3 GB (limits); Grafana+Loki+VictoriaMetrics add ~1 GB comfortably — 4 GB is survivable, 8 GB is calm |
| 80 GB SSD | databases, logs retention, image cache: disks fill quietly; 40 GB is how outages start |
| Static IPv4 | DNS records need a stable address; some hosts bill per IP change |
| Ubuntu 24.04 | the image [02](02-security.md) and [03](03-k3s.md) are written against — re-installable at will |

**Providers (owner shortlist, 2026-11-13):** Contabo (SG/EU, ~$12–15 for
this tier, cheap snapshots) first; **sumopod / helipod** (ID
payment-friendly, helipod has EU too) are valid. **Choose KVM
virtualization, any region in {Singapore, EU}.** Provider-neutral from here
on — nothing in this runbook depends on the vendor's panel except buying
the machine. Set the provider's root password; leave snapshots OFF
(they return in [08](08-backups.md)).

> **Why NOT Oracle free tier / waiting for a restock:** a $12 machine
> working today beats a free one that takes weeks of registration pain.
> (Hetzner remains fine when available; the commands are identical.)
> **Why you can buy this LAST:** Track A needs only your laptop. If cash or
> time is tight, do M0 §2–§5, run the whole rehearsal, and buy the VPS when
> it has already earned its keep.

## 2. Cloudflare: the account, the site, the buckets, the tokens

One vendor for the whole front of the house — DNS + proxy/DDoS + challenges
+ Access + **R2** (photos and backups). Free plan. Do these four things now
and nothing else:

**a. Create the account and add the site.**
Cloudflare → **Add a site** → `gofar.id` → **Free plan**. Note the two
nameservers it hands you; **do not touch the registrar yet** — the zone
cutover is an M5 act in [07](07-go-public.md), next to the records that
depend on it. Keeping registrar access in §3 below is the one key that can
undo the whole move, so it is a prerequisite even though the edit waits.

**b. Create both R2 buckets** (R2 → Create bucket). One bucket per purpose:
different lifecycles, different blast radius.

| Bucket | Holds | Public? |
|---|---|---|
| `omicron-media` | every photo, uploaded through lumen | **private** — the only public face is the `img.gofar.id` custom domain, bound at M5 |
| `omicron-backups` | restic snapshots (encrypted client-side) | private, always |

> **Why two, and why now:** a single accident can then never eat both your
> photos and your photos-about-your-photos, and creating them at M0 means
> the M6 backup loop and the media relay each have a home the day they are
> written. Buckets cost nothing empty, and R2's egress is free — that last
> part is why photos live here at all.

**c. Create the two scoped API tokens** (R2 → Manage R2 API Tokens). Both
**Object Read & Write**, each scoped to ONE bucket:

| Token | Scoped to | Feeds |
|---|---|---|
| media token | `omicron-media` | `LUMEN_MEDIA_ACCESS_KEY` / `_SECRET_KEY` in `kv/lumen/staging` AND `kv/lumen/production` (one token may serve both paths — the envs share the bucket and separate objects by `LUMEN_MEDIA_PREFIX`) |
| backup token | `omicron-backups` | the restic S3 keys in [08](08-backups.md) |

> **Why scoped:** a bucket-scoped token can replace your photos; it cannot
> touch DNS, other buckets, or anything else in the account. One leaked
> token should cost you an afternoon, not the estate.

**Store both token pairs in your offline place NOW** — password manager
and/or paper, same drawer as the future unseal keys. They are **seeded into
the vault in [05](05-vault.md)**, not typed into any manifest or commit; the
ExternalSecret CRs in `vortex` declare the *shape*, Bao holds the *value*.

**d. Nothing else on Cloudflare.** No records, no proxy decisions, no TLS
mode, no Access application — that is one M5 sitting, in order, in
[07](07-go-public.md). (DNSSEC belongs there too, not here.)

## 3. The rest of the accounts

| Account | Why it's needed | Cost |
|---|---|---|
| Domain `gofar.id` + registrar login | DNS moves under Cloudflare at M5; the registrar is the key that makes that reversible | owned |
| GitHub + the repo family (`kanatabi/*`: earendil, lumen, mellon, vortex, anvil) | code, YAML truth, ghcr images, the release machine — already exists; all **public**, safe because values live only in Bao ([00](00-overview.md)'s iron law) | — |
| The `gofar.id` mailbox | Access login identity for `anor` (M5) and the single contact inbox for Let's Encrypt + Grafana alerts | — |
| Backblaze / any second storage vendor | **none** — photos and backups both ride R2 | — |

## 4. Your laptop's toolbelt

Install these before Track A (ch. 03 + 11 assume them):

```bash
# Ubuntu/Debian — adjust for macOS (brew) or the package manager you use.
sudo apt update && sudo apt install -y kubectl helm restic age
# kustomize (v5.8+): single static binary
curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.8.1/kustomize_v5.8.1_linux_amd64.tar.gz" \
  | tar xz && sudo mv kustomize /usr/local/bin/
# k3d — the local rehearsal runtime (needs Docker running)
wget -qO - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

| Tool | What we use it for |
|---|---|
| `kubectl` | talk to the cluster (laptop-direct in Track A; over a tunnel in production, ch.11) |
| `helm` | install the pinned charts (Traefik) — *version matters*: the manifests are tested against helm 3.x |
| `kustomize` | render the YAML folder that *is* the truth; `kubectl kustomize` also works |
| `restic` + `age` | encrypted backups and any file encryption (ch.08) |
| `k3d` | the mandatory local cluster — same k3s engine as the VPS ([03](03-k3s.md)) |

## 5. The rehearsal runtime: k3d (mandatory, not a suggestion)

> **Why:** the build chapters should be typed twice — once where a mistake
> costs `k3d cluster delete`, once on the real box. And the rehearsal must
> run the **shipped shape** (the hub set:
> `bootstrap/apps-hub-foundation.yaml` first, the vault ritual, then
> `apps-hub-production.yaml` and/or `apps-hub-staging.yaml`), not
> a dev sketch — otherwise the first time you meet the real waves, the real
> secrets-plane gating and the `certificates` app is production day. The
> execution map is [00a](00a-run-order.md).

k3d is the sanctioned runtime: it runs the **same k3s image** in containers
on a Docker daemon, on the owner's 32 GB box. Create it with the command
written in full in [03 §1](03-k3s.md) — that block is reused there, so don't
fork a variant; the flags (`--disable=servicelb --disable=traefik` plus the
80/443 port mappings) are the point.

Two demotions, so the history stays honest:

- **separate-VM rehearsal** (`multipass launch 24.04`, a $2 hourly VPS):
  **optional-advanced** now. Worth it only if you specifically want to
  rehearse ch.02's host locks on a machine you can destroy; everything
  inside the cluster is already covered by k3d.
- **minikube**: the historical playground. It produced the archived
  rehearsal log (`../RUNBOOK.md`) and its quirks (the `standard`
  StorageClass alias) are *not* part of the production procedure. Owner
  ruling 2026-11-14 gives it one redo: it currently runs the RETIRED tree
  (Argo errors about `overlays/local/…` — expected) and holds only
  disposable `kv/*/dev` scratch, and it gets **repointed to STAGING**
  (foundation hub → seed → staging hub) as the first live walk of the env
  model. Don't build the FIRST Track A on it — k3d is that — but don't
  read its current redness as estate breakage either.

## 6. Before continuing — checklist

- [ ] VPS exists (or consciously deferred until Track A is green), Ubuntu
      24.04, you can `ssh root@<ip>`
- [ ] Registrar login works; `gofar.id` zone is reachable to edit (the
      edit itself waits for ch.07)
- [ ] Cloudflare account created, **site added**, nameservers NOT yet
      changed
- [ ] `omicron-media` + `omicron-backups` buckets exist; both scoped
      Object Read & Write tokens minted and stored **offline** (seeded in
      ch.05)
- [ ] the `gofar.id` mailbox is reachable (LE + alert recipient)
- [ ] toolbelt installed: `helm version` reads 3.x, `k3d version` prints,
      Docker running
- [ ] the rehearsal cluster is up — run [03 §1](03-k3s.md)'s command block,
      `kubectl get nodes` shows `Ready`
- [ ] an *offline* place for keys: password manager and/or paper — it now
      holds both R2 tokens and will hold the unseal keys, the restic
      password, and the AppRole pairs (ch.05, ch.08)

Next → [02 VPS Hardening](02-security.md) (VPS track) or straight to
[03 §1](03-k3s.md) to start the local rehearsal. The order for both lives
in [00a Run Order](00a-run-order.md).
