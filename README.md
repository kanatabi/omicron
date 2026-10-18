# fzr-blog — Local Run & Test Guide

This repo holds three things:

| Piece | Path | What it is |
| :--- | :--- | :--- |
| Blog frontend (SvelteKit SSR) | [`sv-fzr/`](sv-fzr/) | The site itself — dev mode standalone, or containerized via adapter-node (`Dockerfile`) for cluster deploys |
| Infra blueprint | [`INFRA_ARCHITECTURE.md`](INFRA_ARCHITECTURE.md) | Production K3s + GitOps design (Biznet Gio VPS fleet) |
| GitOps manifests | [`k8s-platform-manifests/`](k8s-platform-manifests/) | Scaffolded app-of-apps repo (Argo CD overlay, lumen, lumen-db) |

You can (and should) rehearse the whole production stack **locally with [k3d](https://k3d.io)**
before touching a VPS. NetBird and Let's Encrypt can't run locally, so this guide
substitutes equivalents where noted.

---

## 0. Prerequisites

- Docker (with **≥ 8 GB RAM allocated** for the full stack; ~4 GB for the minimal path)
- [`k3d`](https://k3d.io/getting-started/) — `wget -qO - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
- `kubectl`, `helm`
- `kustomize` (or `kubectl kustomize`, built into kubectl)

Version check:

```bash
k3d version && kubectl version --client && helm version --short
```

---

## 1. Frontend only (fastest)

No cluster needed for day-to-day blog work:

```bash
cd sv-fzr
npm install
npm run dev          # http://localhost:5173
```

Checks/lint/tests:

```bash
npm run check        # svelte-check
npm run lint
npm run test:unit    # vitest
```

---

## 2. Local cluster (mirrors the production topology)

`1 server + 2 agents`, labeled exactly like the VPS nodes so every `nodeSelector`
and anti-affinity rule in the manifests is actually exercised:

```bash
k3d cluster create fzr-blog \
  --servers 1 --agents 2 \
  -p "80:80@loadbalancer" -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

# Map local nodes onto the production pools (master / worker-1 / worker-2)
kubectl label node k3d-fzr-blog-server-0 node-pool=platform
kubectl label node k3d-fzr-blog-agent-0  node-pool=data
kubectl label node k3d-fzr-blog-agent-1  node-pool=edge
```

> **What's different from production:** no NetBird (direct API access instead of mesh),
> no Let's Encrypt (ingress TLS below uses Traefik's self-signed default cert — browser
> warnings are expected, use `curl -k`), and no swapfile/systemd ordering (those are
> host-level concerns). Everything inside the cluster behaves the same.

---

## 3. Deploy — minimal path (verify GitOps plumbing)

Runs **Traefik + Argo CD + lumen** only. ~4 GB RAM.

### 3a. Traefik (edge router, pinned to the `edge` node like production)

```bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
helm install traefik traefik/traefik -n ingress --create-namespace \
  --set nodeSelector.node-pool=edge
```

(Drop `redirectTo=websecure` locally so plain HTTP works; production installs it per
Phase 3 of `INFRA_ARCHITECTURE.md`.)

### 3b. Build the placeholder images and load them into the cluster

```bash
# Backend (Go placeholder API — see test/local-backend/)
docker build -t ghcr.io/cavadevop/fzr-backend:sha-local test/local-backend/
k3d image import ghcr.io/cavadevop/fzr-backend:sha-local -c fzr-blog

# Frontend (real SvelteKit SSR build via sv-fzr/Dockerfile + adapter-node)
docker build -t ghcr.io/cavadevop/earendil:sha-local sv-fzr/
k3d image import ghcr.io/cavadevop/earendil:sha-local -c fzr-blog
```

### 3c. Argo CD via the platform overlay (exactly what Phase 6 does on the VPS)

```bash
kubectl apply -k k8s-platform-manifests/platform/argocd/
kubectl -n argocd wait --for=condition=Available deploy/argocd-server --timeout=300s

# Dashboard: https://localhost:8080 (user: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
```

### 3d. Sync the app

The full app-of-apps hub needs a *pushed* Git repo (Argo pulls from GitHub). For a
local-only run, sync directly with kustomize — same output, no repo needed:

```bash
kubectl apply -k k8s-platform-manifests/applications/lumen/
kubectl apply -k k8s-platform-manifests/applications/earendil/
```

For the **real GitOps path**: create/push `k8s-platform-manifests/` to GitHub, replace
`cavadevop` in `bootstrap/apps-hub.yaml` + `apps/*-app.yaml`, then
`kubectl apply -f k8s-platform-manifests/bootstrap/apps-hub.yaml` and watch the hub
cascade in the dashboard.

Verify:

```bash
echo "127.0.0.1 ainurrofiq.com" | sudo tee -a /etc/hosts   # ingress Host routing
curl -s http://ainurrofiq.com/ | grep -o '<title>.*</title>'   # SSR'd HTML from SvelteKit
# The API is cluster-internal (no ingress) — reach it through the SSR same-origin proxy:
curl -s "http://ainurrofiq.com/api/search/suggest?q=a"     # proxied to lumen, or 503 if mocks mode
```

---

## 4. Deploy — full path (add the data layer)

### 4a. PostgreSQL (Patroni via Zalando operator)

```bash
kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/v1.13.0/manifests/operator-manifests.yaml
kubectl apply -k k8s-platform-manifests/applications/lumen-db/

kubectl -n db get pods -o wide      # blog-pg-0 and blog-pg-1 on DIFFERENT nodes (anti-affinity)
kubectl -n db exec blog-pg-0 -- patronictl list
```

### 4b. Observability + search (optional locally — watch your Docker RAM)

Meilisearch and the observability stack (Loki, VictoriaMetrics, Alloy DaemonSet,
Grafana — Phases 4–5) are scaffolded in Git and sync like any other app:

```bash
kubectl apply -k k8s-platform-manifests/applications/observability/
kubectl apply -k k8s-platform-manifests/applications/meilisearch/
kubectl -n observability get pods -o wide   # alloy x1-per-worker; loki/vm/grafana pinned
```

They add ~2–2.5 Gi of pod memory on top of the minimal path — fine on an 8 GB Docker
setup, tight on 4 GB (scale Grafana/Loki down or skip). The **secrets plane**
(ESO + OpenBao, architecture doc §5) is intentionally NOT in the local path yet —
until then Meilisearch runs keyless locally and backend creds come from
`lumen-secrets` created manually at bootstrap.

---

## 5. Test checklist (drills that mirror the go-live checklist)

| # | Test | Command | Expect |
| :-- | :--- | :--- | :--- |
| 1 | Placement | `kubectl get pods -A -o wide` | Argo pods on `server-0`; API + frontend pods one per agent; PG replicas split |
| 2 | PG failover | `kubectl -n db delete pod <blog-pg-0/leader>` | Other replica promoted within ~30 s (`patronictl list`) |
| 3 | selfHeal | `kubectl -n lumen scale deploy/lumen --replicas=1` | Argo (GitOps path) reverts to 2 within ~3 min |
| 4 | Prune | Delete a non-hub resource, sync | removed on next automated sync |
| 5 | Ingress HA/edge pin | `kubectl -n ingress get pods -o wide` | Traefik only on the `edge` node |
| 6 | Node loss | `docker stop k3d-fzr-blog-agent-0` | API/PG pods reschedule to surviving nodes; cluster stays up |
| 7 | Frontend dev (no cluster) | `cd sv-fzr && npm run dev` | mock fixtures render when `API_BASE` is unset; point at the local backend with `API_BASE=http://127.0.0.1:8081` + `kubectl -n lumen port-forward svc/lumen 8081:80` |
| 8 | Metrics contract | `kubectl -n lumen port-forward pod/… 9090:9090 && curl localhost:9090/metrics \| head` | `http_requests_total`, `go_goroutines`, `process_cpu_seconds_total` present — Alloy (once deployed) scrapes this same endpoint via the pod annotations |

Cleanup: `k3d cluster delete fzr-blog`. Remember to remove the `/etc/hosts` line.

---

## 6. Troubleshooting

- **`Pending` pods** — most likely the node-pool labels from step 2 are missing, or
  Docker is out of memory; check `kubectl describe pod <x> | tail -20` events.
- **Argo shows `Unknown` repo** — the GitOps path needs a real GitHub repo + correct
  `repoURL`; the kustomize fast-path (3d) doesn't need Argo sync at all.
- **`ImagePullBackOff` on `ghcr.io/cavadevop/...`** — the placeholder image wasn't
  imported; rerun `k3d image import`.
- **PG pods stuck** — operator must be Ready first:
  `kubectl -n postgres-operator get pods`.
- **curl to `ainurrofiq.com` returns 404** — Host header must be `ainurrofiq.com` (the only
  public ingress rule), hence the `/etc/hosts` entry or `curl --resolve ainurrofiq.com:80:127.0.0.1`.
  The API itself has no ingress — `/api/...` on `ainurrofiq.com` is the SSR proxy route.
