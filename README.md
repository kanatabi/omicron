# omicron — blog stack superproject & local run guide

This repo is a **git submodule superproject**. Each piece lives in its own repo
under `kanatabi/` and is pinned here by commit:

| Piece | Submodule | What it is |
| :--- | :--- | :--- |
| Blog frontend (SvelteKit SSR) | [`earendil/`](https://github.com/kanatabi/earendil) | The site itself — dev mode standalone (against a local lumen), or containerized via adapter-node (`Dockerfile`) for cluster deploys |
| REST backend (LIVE — M1–M6 merged) | [`lumen/`](https://github.com/kanatabi/lumen) | Go API: read API on Meilisearch, admin API, media relay, Bao passthrough. ONE binary, role-split: `LUMEN_ROLE=admin` (the Control Plane: sessions, users, relay) \| `cms` (content planes) |
| Admin portal (LIVE) | [`mellon/`](https://github.com/kanatabi/mellon) | Private UI for content + secrets management; UI-only doctrine (`mellon/DESIGN.md`) — relays to lumen, holds no credentials. Its routing table (`src/lib/api/routing.ts`) picks the upstream per path |
| GitOps manifests | [`vortex/`](https://github.com/kanatabi/vortex) | The app-of-apps repo: `bases/` (shape-only kustomize bases) + `environments/{foundation,staging,production}/` overlays (the env axis, the image-version homes) + three hub entrypoints |
| Deployment toolkit | [`anvil/`](https://github.com/kanatabi/anvil) | Shared CI: validate-all (the structural truth battery), auto-merge fence, bump/semver/release actions — pinned by SHA in every consumer |

The infra blueprint lives in this repo: [`INFRA_ARCHITECTURE.md`](INFRA_ARCHITECTURE.md)
(the decision record — where conflicts arise, the **runbook/** folder is the
current operating procedure and supersedes the blueprint's older draft
sections), and the day-2 operations live in [`runbook/`](runbook/00-overview.md)
— start at `runbook/00-overview.md`, work from `runbook/00a-run-order.md`.

### Submodule workflow

```bash
git clone --recursive git@github.com:kanatabi/omicron.git     # fresh clone
# or, on an existing clone:
git submodule update --init --recursive

# update a pin after the child repo moved:
git -C earendil pull origin main        # (or push from here when working on it)
git add earendil && git commit -m "chore(earendil): bump to <sha>"
```

Edits inside a submodule are commits in **that** repo — push the child first,
then bump the pin here.

You can (and should) rehearse the whole production stack **locally with
[k3d](https://k3d.io)** before touching a VPS — the mandatory walk is
[`runbook/00a-run-order.md`](runbook/00a-run-order.md) Track A: the same hub
entrypoints, the same `environments/*` trees, the same vault bootstrap, and
it deliberately runs **staging and production together** so you rehearse
their isolation, not just their YAML.

---

## 0. Prerequisites

- Docker (with **≥ 8 GB RAM allocated** for the full stack; the runbook's
  single-node Track A fits ~4 GB and wants headroom)
- [`k3d`](https://k3d.io/getting-started/) — `wget -qO - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
- `kubectl`, `helm`, `kustomize` (or `kubectl kustomize`, built into kubectl)
- the pinned tool versions per `runbook/01-prerequisites.md`

Version check:

```bash
k3d version && kubectl version --client && helm version --short
```

---

## 1. Frontend only (fastest)

No cluster needed for day-to-day blog work — earendil is **real-by-default**
(it fetches a running lumen; unset env = the `http://localhost:8080` dev
fallback):

```bash
cd lumen && make dev            # or: docker compose up — the local backend
cd ../earendil
npm install
npm run dev          # http://localhost:5173
```

Checks/lint/tests:

```bash
npm run check        # svelte-check
npm run lint
npm run test:unit    # vitest — runs against the TEST-ONLY fixture twin, zero backend
```

---

## 2. Local cluster — the two rehearsals

**A. The canonical one (Track A, runbook/00a):** one server, no agents —
the SHIPPED shape:

```bash
k3d cluster create omicron \
  --servers 1 --agents 0 \
  --k3s-arg "--disable=servicelb@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  -p "80:80@loadbalancer" -p "443:443@loadbalancer"
kubectl label node k3d-omicron-server-0 node-pool=platform --overwrite
```

Then walk `runbook/00a` A3→A10: Argo, the **foundation hub**, the vault
ritual, then the staging + production hubs together. This is the rehearsal
that mirrors what ships.

**B. The 3-node topology exercise (optional):** mirrors the future
scale-out blueprint (`vortex/bootstrap/apps-hub.yaml` — the flat `apps/`
hub), with node pools labeled so every `nodeSelector`/anti-affinity rule in
the BASE manifests is exercised:

```bash
k3d cluster create fzr-blog \
  --servers 1 --agents 2 \
  -p "80:80@loadbalancer" -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

kubectl label node k3d-fzr-blog-server-0 node-pool=platform
kubectl label node k3d-fzr-blog-agent-0  node-pool=data
kubectl label node k3d-fzr-blog-agent-1  node-pool=edge
```

> **What's different from production on both:** no Cloudflare proxy/challenges
> (or rehearse them for real via a named tunnel — runbook 00a A11), and no
> host-level hardening (runbook ch. 02 is VPS-only). Certificates are NOT a
> delta anymore: DNS-01 works from a laptop, so the `certificates` app and
> real Let's Encrypt certs run everywhere — the self-signed rehearsal
> component was retired with the env model.

---

## 3. Deploy — minimal path (verify GitOps plumbing)

Runs **Traefik + Argo CD + the foundation plane** only. Real images come
from ghcr (public — the packages are released `vX.Y.Z` tags, no local builds
needed; `k3d image import` is only for testing unrebuilt changes).

### 3a. Traefik (edge router — the pinned chart, runbook/03 §6)

```bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
helm install traefik traefik/traefik --version 42.3.2 -n ingress --create-namespace \
  --set providers.kubernetesCRD.enabled=true \
  --set 'additionalArguments[0]=--metrics.prometheus'
```

### 3b. Argo CD via the platform overlay (exactly what the VPS walk does)

```bash
kubectl apply -k vortex/platform/argocd/ --server-side --force-conflicts
kubectl -n argocd wait --for=condition=Available sts/argocd-application-controller --timeout=300s

# Dashboard: https://localhost:8080 (user: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
```

### 3c. Sync the fleet — the entry order IS the design

The GitOps path needs the PUBLIC repo (Argo pulls from GitHub — no
credentials, because no values live in Git):

```bash
kubectl apply -f vortex/bootstrap/apps-hub-foundation.yaml
# → run runbook ch. 05 against it (init/unseal/AppRole/SEED), then:
kubectl apply -f vortex/bootstrap/apps-hub-staging.yaml      # or -production, or both
```

Verify:

```bash
curl -sk https://localhost/ | grep -o '<title>.*</title>'   # SSR'd HTML from SvelteKit
# (or the /etc/hosts → 127.0.0.1 trick with real hosts: gofar.id / staging.gofar.id)
# The API is cluster-internal (no ingress) — reach it through the SSR same-origin proxy:
curl -sk "https://localhost/api/search/suggest?q=a"         # proxied to lumen
```

> Manifest-only checks without any cluster: `kubectl kustomize
> vortex/environments/staging/lumen` (etc.) renders what Argo would apply;
> `anvil/bin/validate-all.sh` is the full battery.

---

## 4. Deploy — full path (the data layer rides along now)

The foundation hub already brings the data plane: Patroni PostgreSQL
(needs the Zalando operator CRD applied once — runbook 04 §2's table),
Meilisearch, OpenBao + ESO + the `bao` store, observability, and
lumen-admin. Nothing here is manual beyond the three pinned bootstrap
installs (Argo, the operator, cert-manager).

```bash
kubectl -n db get pods                      # lumen-pg-0 (1 instance via the single-node
                                            # component; 2 on the 3-node topology)
kubectl -n search get pods                  # meilisearch (ONE engine, per-env indexes)
kubectl -n lumen get deploy                 # lumen-admin here; cms fleets arrive with
                                            # the env hubs, suffixed -staging/-production
```

The **secrets plane** (ESO + OpenBao) is no longer optional or manual —
it's the render contract (runbook ch. 05: ESO fails the whole render on a
missing property; seed before any hub syncs).

---

## 5. Test checklist (drills that mirror the go-live checklist)

| # | Test | Command | Expect |
| :-- | :--- | :--- | :--- |
| 1 | Placement (3-node topology) | `kubectl get pods -A -o wide` | Argo pods on `server-0`; data pods on the `data` pool; Traefik/edge on `edge` — on Track A (1 node) everything lands on the one node via `components/single-node` |
| 2 | PG failover (3-node topology) | `kubectl -n db delete pod <lumen-pg-# leader>` | Other replica promoted within ~30 s (`patronictl list`) |
| 3 | selfHeal | `kubectl -n lumen scale deploy/lumen-http-server-production --replicas=0` | Argo (GitOps path) reverts within ~3 min |
| 4 | Prune | Delete a non-hub resource, sync | removed on next automated sync |
| 5 | Config-gate bite | flip ONE side of an env's epoch trio in a vortex branch PR | `validate-manifests` red on the TRIO class; a deployed mismatch blocks that env's sync only (runbook 06 §4) |
| 6 | Env isolation | write a post via staging-console | appears on `staging.gofar.id` only; index `posts-staging` ≠ `posts`; media under `staging/`; Grafana env filter splits the fleets (runbook 00a A10) |
| 7 | Frontend dev (no cluster) | `cd earendil && npm run dev` | real-by-default: point at a local lumen (`http://localhost:8080` fallback); tests use the fixture twin |
| 8 | Metrics contract | `kubectl -n lumen port-forward pod/… 9090:9090 && curl localhost:9090/metrics \| head` | `http_requests_total`, `go_goroutines`, `process_cpu_seconds_total` present — Alloy scrapes this via the pod annotations and stamps `omicron/env` |

Cleanup: `k3d cluster delete omicron fzr-blog`. Remember to remove any
`/etc/hosts` lines.

---

## 6. Troubleshooting

- **`Pending` pods** — most likely the node-pool labels from §2 are missing, or
  Docker is out of memory; check `kubectl describe pod <x> | tail -20` events.
- **Argo shows `Unknown` repo** — the GitOps path needs the correct
  `repoURL`; the kustomize fast-path (`kubectl kustomize`) doesn't need Argo at all.
- **`ImagePullBackOff` on `ghcr.io/kanatabi/...`** — the GHCR package
  inherited PRIVATE repo visibility on first push (the classic one-timer —
  flip the package public; runbook 09 §5.4). Local builds instead:
  `k3d image import <image> -c <cluster>`.
- **ES red `key not found`** — a path the render contract demands isn't
  seeded (wrong env, or `shared` skipped) — runbook ch. 05 §6, seed first,
  then `kubectl delete externalsecret …` to force a re-render.
- **PG pods stuck** — operator must be Ready first:
  `kubectl -n postgres-operator get pods`.
- **`curl` to a host returns 404 from Traefik** — the Host header matched no
  Ingress: production names are `gofar.id`/`www`/`console`/`anor`, staging
  `staging.gofar.id`/`staging-console.gofar.id` (plus the `/etc/hosts` or
  `--resolve` trick locally). The API has no ingress — `/api/...` on a site
  host is the SSR proxy route.
