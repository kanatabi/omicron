---
tags: [architecture, gitops]
updated: 2026-11-15
---

# GitOps — how a git push becomes a cluster state

## The one diagram

```
git push ──► hub (bootstrap/apps-hub-*) ──► per-app Application ──► environments|bases/<path> ──► cluster
```

Argo CD itself is applied by hand once (`kubectl apply -k platform/argocd/`,
pinned upstream + overlays) and then self-hosts its own config from Git. Every
other workload is declared in [vortex](https://github.com/kanatabi/vortex) and
synced through **app-of-apps**: a hub Application syncs a folder of per-app
Application CRs, **non-recursively**, so hub folders never see each other's
CRs.

## The four entrypoints (bootstrap order = the seed-before-apps invariant)

1. `apps-hub-foundation.yaml` — values + data plane (openbao, ESO,
   secrets-plane wave 0; lumen-db + meilisearch wave 1; lumen-admin wave 2,
   structurally gated on the `bao` store being Ready after M3 seeds).
2. `apps-hub-observability.yaml` — **THE manual gate**: apply only after the
   grafana four-key seed verifies; an ES errors on any missing declared key,
   so an early apply wedges the sync-op forever (runbook ch.12 card 11).
3. `apps-hub-production.yaml` — production plane (lumen wave 0, earendil +
   mellon + certificates wave 1).
4. `apps-hub-staging.yaml` — staging plane (same or another cluster;
   destination-only difference).

Sync waves restart per hub. Adding an app = a CR in the folder its hub syncs +
a `bases/<name>` base (+ overlays) — never a hub edit.

## What syncs and what doesn't

- Argo default: `prune + selfHeal`. The **DB app is the exception**
  (`apps/lumen-db-app.yaml`, blueprint shape): `selfHeal: false` so
  incident-time failovers aren't stomped by Git; the single-instance VPS
  overlay keeps selfHeal on (nothing to stomp).
- **CI never touches the cluster.** Release CI opens bump PRs; humans (or the
  guarded auto-merge) merge; Argo notices. See
  [releases-and-ci.md](releases-and-ci.md).
- The root workspace repo (omicron) only ever holds submodule pins — the
  gitlink bump after a child push.

## The validation habit (no cluster needed)

`kubectl kustomize <dir>` after ANY manifest edit; the full battery
(anvil `validate-all.sh`) adds the rendered-loss baseline + structural
invariants. `bases/external-secrets` and its chains need `--enable-helm`.

Authoritative details: [vortex AGENTS.md §4–§7](https://github.com/kanatabi/vortex/blob/main/AGENTS.md);
the rationale: [`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) §9–§10.
