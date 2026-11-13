---
tags: [runbook, gitops]
updated: 2026-11-13
status: fully proven on the rehearsal cluster (walk ledger) — VPS identical
---

# 07 · GitOps & Argo CD — how software arrives

> **Why GitOps:** "SSH in and kubectl apply" leaves no memory, no undo, and
> no answer to "why does prod differ from yesterday?". Here the **YAML repo
> is the truth**, and a robot (Argo CD) keeps reality equal to it, forever,
> in the visible way. Rollback = `git revert`. That's the whole philosophy.

The apps' YAML already exists in `vortex` (bases + `overlays/production`).
This chapter is: install the robot, point it at the folder, understand the
order things wake up in.

## 1. Install Argo (pinned v3.6.1)

```bash
cd vortex
kubectl apply -k platform/argocd/ --server-side --force-conflicts
kubectl -n argocd wait --for=condition=Available deploy/argocd-server --timeout=300s
kubectl -n argocd get sts argocd-application-controller   # it's a STATEFULSET — deploy/ would miss it
```

> **Why `--server-side`:** Argo's own CRDs exceed the 256 KiB
> `last-applied-configuration` annotation limit — client-side apply dies
> with a confusing "metadata.annotations too long". Both kubectl and Argo
> hit this wall; SSA is the walk-proven answer. `platform/argocd/` also
> pins the upstream install manifests by commit (exact versions; the
> renovate lesson applies to our plumbing too).

Admin bootstrap (UI creds exist only at first boot; this is one of the
"three never-losables" — record it offline in the same place as unseal keys):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
# after first login: change it, and (recommended) disable the local admin:
kubectl -n argocd patch cm argocd-cm -p '{"data":{"admin.enabled":"false"}}'
# real admin logins afterwards ride the tunnels (ch.11) + your SSO choice;
# GATE #10 keeps this door non-public forever regardless.
```

## 2. The app-of-apps (one pointer starts the fleet)

```bash
kubectl apply -f bootstrap/apps-hub-single-node.yaml
```

> **Why the hub shape:** `bootstrap/` contains ONE Application pointing at
> `vortex/apps/single-node/`, whose files are themselves Argo Applications.
> The hub can't manage itself (chicken-and-egg) — that single manual apply
> is the intended, documented exception. Adding an app = new YAML file in
> `applications/<app>/` + new Application CR in `apps/single-node/`; the
> hub never gets raw manifests (its sync would delete them).

## 3. What wakes up in what order (and why the waits are features)

The wave numbers are STRUCTURAL (commit `f64f731`), not cosmetic:

| Wave | Apps | Depends on |
|---|---|---|
| 0 | openbao, external-secrets | the vault Pod exists (then ch.05 bootstrap unlocks it) |
| 1 | lumen-db (Patroni), meilisearch, secrets-plane | storage |
| 2 | **lumen, earendil, mellon** | **cannot sync until the `bao` ClusterSecretStore is Ready — which waits for ch.05 seeding** |

**During the bootstrap this looks broken:** wave-2 apps OutOfSync / red
ExternalSecrets / apps "Progressing" forever. The order to make it green:
vault unseal (§ch.05) → seed values → force ES sync (`kubectl delete
externalsecret …`, Argo recreates it) → pods roll with real env.

> **Why wave 2 gates on the store instead of "just start":** starting apps
> with empty config means they boot, crash-loop on `""` passwords, and
> hide the real problem (unseeded vault) under app-shaped errors. The
> PreSync migrate Job (`lumen migrate`, schema-gates-deploy ruling) is the
> same idea one level in: **a rollout blocked by a failed prerequisite is
> the design working.**

## 4. The rules of the road (selfHeal = the robot always wins)

- **Never `kubectl patch/edit/apply` the cluster directly** to "fix"
  something — Argo reverts it within minutes, and you've now got a drift
  story nobody can read. Fix the YAML in `vortex`, open the PR, let the
  robot copy it. *(One exception class: k8s-native debug commands —
  `get`, `describe`, `logs`, `exec` — are always fine.)*
- **Manual pods/jobs** (like ch.05's bootstrap job) live outside Git's
  love; they're fine as one-off `kubectl create` — Argo simply doesn't
  know them.
- Verify the steady state any day with:

```bash
kubectl -n argocd get applications                    # all Synced/Healthy = quiet
kubectl get events -A --sort-by=.lastTimestamp | tail # what moved, when
```

- Production seeding note: `overlays/production/*` paths are what
  `apps/single-node/` CRs must point at on the VPS (the rehearsal used
  `overlays/dev`). If a CR still says dev, the PR is one `source.path`
  line — check at first boot: `kubectl -n argocd get app -o
  jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.source.path}{"\n"}{end}`.

Next → [08 Releases](08-releases.md)
