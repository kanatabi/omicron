---
tags: [runbook, setup]
updated: 2026-11-13
---

# 01 · Prerequisites — what to buy, prepare, install (and why each)

> **Why this chapter exists:** every item here is a dependency of something
> later. Buying/creating them up front means the install chapters stay
> copy-paste, and nothing stalls mid-build waiting for an email verification.

## 1. The server (VPS)

**Spec floor: 4 vCPU / 8 GB RAM / 80 GB SSD / IPv4 + IPv6.**

| Spec | Why the number |
|---|---|
| 4 vCPU | Kubernetes + Postgres + search + vault + *monitoring* all on one box; 2 CPUs works but the monitoring stack feels it |
| 8 GB RAM | the app stack asks ≈ 2–3 GB (limits); Grafana+Loki+VictoriaMetrics add ~1 GB comfortably — 4 GB is survivable, 8 GB is calm |
| 80 GB SSD | databases, logs retention, VM images: disks fill quietly; 40 GB is how outages start |
| Static IPv4 | DNS records need a stable address; some hosts bill per IP change |

**Providers (owner shortlist, 2026-11-13):** Contabo (SG/EU, ~$12–15 for
this tier, cheap snapshots) first; sumopod / helipod (ID payment-friendly,
helipod has EU too) are valid. **Choose KVM virtualization, any region in
{Singapore, EU}.** Provider-neutral from here on — nothing in this runbook
depends on the vendor's panel except buying the machine.

> **Why NOT Oracle free tier / waiting for Hetzner restock:** a $12 machine
> working today beats a free one that takes weeks of registration pain.
> (Hetzner remains fine when available; commands are identical.)

**Buy:** Ubuntu **24.04 LTS** image, re-installable at will. Set the
provider's root password, keep snapshots OFF for now (they return in ch.10).

## 2. The accounts

| Account | Why it's needed | Cost |
|---|---|---|
| Domain `gofar.id` + registrar login | DNS is moving under Cloudflare; the registrar is the one key that can undo that | owned |
| Cloudflare (free plan) | DNS + proxy/DDoS + challenges + Access + **R2 buckets** — one vendor for the whole front of the house | $0 |
| GitHub + the repo family | code, YAML truth, images (ghcr), release machinery — already exists | — |
| Backblaze/others: **none** | backups go to Cloudflare R2 (ch.10) — no second storage vendor | — |

## 3. Your laptop's toolbelt

Install these four now (ch. 3+11 assume them):

```bash
# Ubuntu/Debian — adjust for macOS (brew) or ask the package manager you use.
sudo apt update && sudo apt install -y kubectl helm restic age
# kustomize (v5.8+): single static binary
curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.8.1/kustomize_v5.8.1_linux_amd64.tar.gz" \
  | tar xz && sudo mv kustomize /usr/local/bin/
```

| Tool | What we use it for |
|---|---|
| `kubectl` | talk to the cluster (over a tunnel, ch.11) |
| `helm` | install the pinned charts (Traefik, cert-manager) — *version matters*: the manifests are tested against helm 3.x |
| `kustomize` | render the YAML folder that *is* the truth; `kubectl kustomize` also works |
| `restic` + `age` | encrypted backups and any file encryption (ch.10) |

## 4. The rehearsal VM (strongly recommended, ~15 min)

> **Why:** the install chapters (02→07) should be typed twice: once on a
> throwaway machine, once on the real one. Mistakes on the VM cost a
> `destroy`; on the VPS they cost an afternoon.

Any of: **VirtualBox/UTM VM, `multipass launch 24.04`, or a $2 hour-long
hourly-vps instance.** Give it ≥ 4 GB RAM. It must be plain Ubuntu 24.04,
because ch. 03 runs *the same commands* there and on production — the VM
rehearses the real install, not the minikube toy (minikube is the app
playground; see the archived rehearsal log).

```bash
multipass launch 24.04 --name omicron-rehearsal --cpus 4 --memory 8G --disk 40G
multipass shell omicron-rehearsal   # now follow ch. 02 onward
```

## 5. Before continuing — checklist

- [ ] VPS exists, Ubuntu 24.04, you can `ssh root@<ip>`
- [ ] Registrar login works; `gofar.id` zone is reachable to edit
- [ ] Cloudflare account added the site (nameservers pending or done — ch.04)
- [ ] laptop toolbelt installed (`helm version` reads 3.x)
- [ ] rehearsal VM up (or consciously skipped)
- [ ] an *offline* place for keys: password manager and/or paper — used in ch.05 and ch.10

Next → [02 VPS Hardening](02-security.md)
