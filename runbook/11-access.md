---
tags: [runbook, access]
updated: 2026-11-13
---

# 11 · Access from Your Laptop — the admin roads

> **Why dedicated roads:** ch.02 closed every admin port to the internet on
> purpose. That means *you* need a defined way in, and the way in should be
> boring, logged, and revocable. Two roads: SSH tunnels (day one, zero new
> software) and Tailscale (optional comfort upgrade).

## 1. The SSH tunnel pattern (learn once, use forever)

A tunnel = "pretend a cluster-only door is on my laptop." One terminal per
road, Ctrl-C closes it. Template:

```bash
ssh -N -L <local-port>:<in-cluster-target> ops@<server-ip> &
```

…but the in-cluster target isn't reachable by `ssh -L` alone (ClusterIP is
node-internal), so each recipe runs port-forward **on the server** and
tunnels **to it**. Helper on the server (`/usr/local/bin/tunnel`, one-time):

```bash
#!/usr/bin/env bash
# usage: tunnel <svc> <ns> <node-bind-port> <svc-port>  — localhost-bound
kubectl -n "$2" port-forward "svc/$1" "127.0.0.1:$3:$4" &
FPID=$!; trap "kill $FPID" EXIT INT TERM; wait $FPID
```

The three doors:

| Want | Server runs | Laptop runs | Then open |
|---|---|---|---|
| **Argo UI** | `tunnel argocd-server argocd 8443 443` | `ssh -N -L 8443:127.0.0.1:8443 ops@ip` | https://localhost:8443 (self-signed warning = honest: this hop isn't the public door) |
| **kubectl** | *(nothing)* | `ssh -N -L 6443:127.0.0.1:6443 ops@ip` + a **laptop kubeconfig** built once from `sudo cat /etc/rancher/k3s/k3s.yaml` with `server: https://127.0.0.1:6443` | `kubectl get nodes` over the tunnel |
| **Grafana fallback** (edge-down day) | `tunnel grafana observability 3000 80` | `ssh -N -L 3000:127.0.0.1:3000 ops@ip` | http://localhost:3000 with the **break-glass admin** (ch.09 §4) |

> **Why this is enough:** kubectl-over-tunnel keeps 6443 firewalled
> (ch.02), and every session is SSH-key-authenticated and logged in
> `/var/log/auth.log`. Two commands per work session is the honest cost
> of a small attack surface.

## 2. Optional comfort: Tailscale (mesh VPN)

> **Why optional:** it removes the two-terminal dance forever — the server
> and your laptop join a private WireGuard network, admin ports bind to
> that, and "being on the tailnet" *is* the credential. Owner ruling
> 2026-11-13: Tailscale replaces the INFRA doc's NetBird plan (client is
> open source, free for personal use, zero ops; Headscale exists as the
> later self-host escape hatch). NetBird remains the choice *if*
> self-hosting the control plane is a requirement, not a preference — you'd
> be operating that coordinator forever.

Setup, both machines:

```bash
curl -fsSL https://tailscale.com/install.sh | sh && tailscale up   # opens browser login once
tailscale ip -4   # gives e.g. 100.x.y.z — a stable private address
```

Server firewall then allows the tailnet and you can tighten further:

```bash
ufw allow in on tailscale0
tailscale set --advertise-accept-routes=false   # admin road only, not a router
```

- **kubectl:** copy the kubeconfig once, change server to
  `https://<tailscale-ip-of-server>:6443`. No tunnels, ever again.
- **Argo/Grafana:** reachable at their node ports over the tailnet — or
  keep the URLs you already have; Access still fronts `anor` for phones.
- **ACLs (the zero-trust bit):** Tailscale admin → ACLs → default-deny,
  then allow `laptop:* → server:22,6443` only. A stolen laptop that isn't
  on your tailnet learns that those ports don't exist.
- **A device mesh is NOT a service mesh** (question worth answering in
  the docs, in one line): service meshes (Istio-style) reroute traffic
  *between your own pods* — a 3-app single node doesn't have that problem
  yet. This estate adds a private *network*, not a second architecture.

**Rollback:** `tailscale down` + uninstall — SSH roads (this chapter's §1)
keep working independently, which is why they're written first.

## 3. House rules

- New machine/phone needs access? Add it to the tailnet (or issue an SSH
  key — treat `authorized_keys` like IAM).
- Lost laptop → remove the device from Tailscale **and** delete its SSH
  key, both, same minute. Small estate, fast revocation is a feature.
- `ssh ops@<server>` is the only login mode; never enable passwords back
  "just for now" — every "just for now" becomes someone else's foothold.

Next → [12 Operations Calendar](12-operations.md)
