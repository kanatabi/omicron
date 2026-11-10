# RUNBOOK.md — bringing the omicron estate up on ONE node

One document, two destinations: **Part A** runs the whole infra on your local
minikube (the rehearsal), **Part B** runs it on the single VPS (production), and
**Part C** is the later scale-out to the 3-node blueprint. The cluster SHAPE is
identical in A and B — that's deliberate: rehearsing here IS validating there.

Mental model (INFRA_ARCHITECTURE.md is the WHY; this is the HOW):

```
git push (app repo) → CI builds image → GHCR sha-tag → CI bumps image in vortex
→ Argo CD syncs vortex → ESO reads kv/{app}/{env} from OpenBao → renders
ConfigMaps/Secrets → pods roll. Values live ONLY in Bao; Git ONLY templates.
```

Two public surfaces, ever: `gofar.id` (earendil) + `console.gofar.id` (mellon).
lumen, Bao, Meilisearch, the DB: cluster-internal, always. The portal relays to
lumen; lumen relays to Bao. Browser→API traffic rides same-origin proxies.

---

## 1. Prerequisites (both destinations)

| Tool | Version | Notes |
|---|---|---|
| kubectl | ≥ 1.31 | client only |
| helm | **v3.22.1** | `curl -sfL https://raw.githubusercontent.com/helm/helm/v4.3.1/scripts/get-helm-3 \| HELM_INSTALL_DIR=$HOME/bin USE_SUDO=false bash` (script pins the 3.x line; check `helm version` reads v3.22.1) |
| docker + buildx | any current | builds the three app images |
| minikube (A only) | v1.39 | docker driver; its backend is k3s |
| git | ≥ 2.40 | workspace `omicron/` with the four children cloned |

Pinned cluster components (exact versions; bump deliberately, never auto-merge —
the renovate lesson, AGENTS §4):

| Component | Pin | Where it enters |
|---|---|---|
| Argo CD | `v2.13.2` | `vortex/platform/argocd/` (pinned upstream install.yaml + overlays) |
| ESO chart+operator | `2.15.0` | `apps/*/external-secrets-app.yaml` (OCI chart; operator==chart version since the 2.x unification) |
| Traefik chart | `42.3.2` (app `v3.7.17`) | helm, steps below |
| Zalando postgres-operator | `v1.13.0` | manual `kubectl apply` (header of `applications/lumen-db/postgresql.yaml`) |
| cert-manager | `v1.16.2` | **Part B only** |
| Meilisearch image | `v1.10.0` | base deployment |
| OpenBao | `2.5.x` image | base deployment |

Cluster sizing: core stack (Argo, ESO, Bao, 1× Patroni, Meilisearch, lumen×2
roles, earendil, mellon) requests ≈ **2.0–2.3 Gi CPU·Mem in limits** — fine on
any 4 Gi node, tight-but-workable on 2 Gi (see §B6 trimming). Observability is
NOT in the single-node hub: add it only when the node is comfortable.

> ⚠️ **Context safety.** Your kubeconfig also holds a WORKPLACE context
> (`vsh@tkeg…`). Everything below pins `--context minikube` (Part A). Make it
> reflex: `export KUBECONFIG` hygiene or keep a shell alias. Never run these
> against a context you didn't name.

---

## 2. Part A — local minikube (the rehearsal)

### A1. Start the cluster and label the node

```bash
minikube start                                  # docker driver, k3s backend
kubectl --context minikube label node minikube node-pool=platform --overwrite
```

Why the label: Argo CD's own manifests (pinned in `platform/argocd/`) carry a
`nodeSelector: node-pool=platform` pinning patch — the node must satisfy it.
Workload pods don't care: `components/single-node` strips their selectors
(the whole point of the component).

### A2. Storage: `local-path` alias

The manifests ask for StorageClass `local-path` (k3s-native name; minikube
calls its hostpath class `standard`). Don't edit Git for this — register the
alias once:

```bash
kubectl --context minikube apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: local-path }
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain          # Bao/Meili/Patroni data survives PVC deletion — deliberate
volumeExpansionAllowed: false
EOF
```

`Retain` on purpose: this cluster holds a values store; silently-`Delete`
reclaim is how rehearsals teach bad habits.

### A3. Traefik (edge) — pinned chart, NodePort shape

```bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
helm install traefik traefik/traefik --version 42.3.2 -n ingress --create-namespace \
  --set service.type=NodePort \
  --set ports.web.nodePort=30080 \
  --set providers.kubernetesCRD.enabled=true \
  --set additionalArguments[0]="--metrics.prometheus"
```

No `redirectTo`/tls here: the local chain uses `components/selfsigned` (TLS
stripped); forcing https to a self-signed cert would only train you to ignore
warnings. Class name is the default `traefik` — matches every Ingress in Git.

### A4. Build + load the three app images (bare names = the local trick)

The base deployments reference `image: lumen` / `earendil` / `mellon` — in prod
CI rewrites those to `ghcr.io/kanatabi/<app>:sha-<short>` via
`kustomize edit set image`. Locally, build UNDER the bare name so
`IfNotPresent` finds them node-side with zero Git edits (same trick as the old
k3d placeholder flow, now with real images):

```bash
cd omicron
for app in lumen earendil mellon; do
  docker build -t $app ./$app
  minikube image load $app:latest
done
```

Verified on this machine (2026-11-10): all three Dockerfiles build clean;
earendil serves real lumen content, mellon serves the authed dashboard against
the dev plane. Images ~35 MB (distroless Go) / ~260 MB (node SSR) each.

### A5. Manual platform pieces (before the hub)

```bash
# 1. ESO's namespace (the OCI chart won't self-create it — accepted manual exception)
kubectl --context minikube create namespace external-secrets

# 2. Zalando operator (pinned; the lumen-db CR needs it present before it can go green)
kubectl --context minikube apply -f \
  https://raw.githubusercontent.com/zalando/postgres-operator/v1.13.0/manifests/operator-manifests.yaml
kubectl --context minikube -n postgres-operator wait --for=condition=Available \
  deploy/postgres-operator --timeout=180s

# 3. Meilisearch master key — generate ONCE, reuse in A8's seed (they must match)
MEILI_KEY=$(openssl rand -hex 16)
kubectl --context minikube create namespace search --dry-run=client -o yaml |
  kubectl --context minikube apply -f -
kubectl --context minikube -n search create secret generic meilisearch-master-key \
  --from-literal=master-key=$MEILI_KEY

# 4. Argo CD itself (pinned install + the master-pinning overlay; owns its namespace)
cd vortex
kubectl --context minikube apply -k platform/argocd/
kubectl --context minikube -n argocd wait --for=condition=Available \
  deploy/argocd-server --timeout=300s
# UI: port-forward + initial admin password
kubectl --context minikube -n argocd port-forward svc/argocd-server 8080:443 &
echo "argocd admin: $(kubectl --context minikube -n argocd get secret \
  argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
```

### A6. App-of-apps — the SINGLE-NODE hub (never both hubs at once)

```bash
kubectl --context minikube apply -f bootstrap/apps-hub-single-node.yaml
```

`apps/single-node/` CRs, wave-ordered, and the waves are STRUCTURAL (commit
f64f731): openbao+ESO wave 0 → lumen-db/meilisearch/secrets-plane wave 1 →
lumen/earendil/mellon **wave 2, which cannot sync until the `bao`
ClusterSecretStore is Ready — and it won't be Ready until A7–A8 seed Bao.**
If wave-2 apps sit OutOfSync/Progressing: that's the design working, not a bug.

### A7. OpenBao bootstrap (the §5.6 manual one-time — init, unseal, mount, roles)

Follow the header checklist in `applications/openbao/openbao.yaml`; concretely:

```bash
B="kubectl --context minikube -n secrets exec deploy/openbao -- bao"
INIT=$($B operator init -key-shares=1 -key-threshold=1 -format=json)
echo "$INIT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('UNSEAL='+d['unseal_keys_b64'][0]); print('ROOT='+d['root_token'])"
# >>> COPY BOTH LINES OUT NOW — the unseal key lives OFFLINE (password manager /
#     printed paper). Losing it = losing every value in the estate, DR doc §5.6. <<<
$B operator unseal <UNSEAL_KEY>
export VAULT_ADDR=http://127.0.0.1:8200
kubectl --context minikube -n secrets port-forward svc/bao 8200:8200 &   # for the curl steps below
ROOT=<root token>; UNSEAL=<unseal key>
CB=(curl -sS -H "X-Vault-Token: $ROOT" -H 'Content-Type: application/json')

# kv-v2 at path `kv` + approle backend
"${CB[@]}" -X POST http://127.0.0.1:8200/v1/sys/mounts/kv \
  -d '{"type":"kv","options":{"version":"2"}}'
"${CB[@]}" -X POST http://127.0.0.1:8200/v1/sys/auth/approle -d '{"type":"approle"}'

# ESO policy: READ/LIST only — the store renders, it must never write.
"${CB[@]}" -X PUT http://127.0.0.1:8200/v1/sys/policies/acl/eso -d '{"policy":
"path \"kv/data/*\" { capabilities = [\"read\"] }\npath \"kv/metadata/*\" { capabilities = [\"read\", \"list\"] }\n"}'
"${CB[@]}" -X POST http://127.0.0.1:8200/v1/auth/approle/role/eso \
  -d '{"token_policies":"eso","token_ttl":"1h","token_type":"service"}'

# Portal relay policy (lumen's Bao passthrough): kv/* ONLY, no sys (§9 doctrine).
# Same shape as lumen/scripts/dev-plane.sh — including the metadata PATCH grant
# that carries the D1 pin intent.
"${CB[@]}" -X PUT http://127.0.0.1:8200/v1/sys/policies/acl/portal -d '{"policy":
"path \"kv/data/*\" { capabilities = [\"read\", \"list\", \"create\", \"update\"] }\npath \"kv/metadata/*\" { capabilities = [\"read\", \"list\", \"patch\"] }\n"}'
"${CB[@]}" -X POST http://127.0.0.1:8200/v1/auth/approle/role/portal \
  -d '{"token_policies":"portal","token_ttl":"1h","token_type":"service"}'
```

> secret_id lifetime: dev-plane uses no-expiry for friction; a real cluster
> should issue secret-ids with a bounded `secret_id_ttl` and re-issue on a
> schedule (a v2 write of the app's `lumen-bao-credentials`/
> `bao-approle-credentials` Secret IS the rotation — Argo's selfHeal won't
> revert Secret contents it doesn't track). For the rehearsal: set
> `secret_id_ttl` to `0` (never) and note the prod hardening in GATE #10.

Now hand the credentials to the two consumers — NOTHING of this touches Git
(commit 897812f removed the last Git-side literal):

```bash
ESO_ROLE_ID=$("${CB[@]}" http://127.0.0.1:8200/v1/auth/approle/role/eso/role-id | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['role_id'])")
ESO_SECRET_ID=$("${CB[@]}" -X POST http://127.0.0.1:8200/v1/auth/approle/role/eso/secret-id | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['secret_id'])")
P_ROLE_ID=$("${CB[@]}" http://127.0.0.1:8200/v1/auth/approle/role/portal/role-id | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['role_id'])")
P_SECRET_ID=$("${CB[@]}" -X POST http://127.0.0.1:8200/v1/auth/approle/role/portal/secret-id | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['secret_id'])")

kubectl --context minikube -n external-secrets create secret generic bao-approle-credentials \
  --from-literal=role-id=$ESO_ROLE_ID --from-literal=secret-id=$ESO_SECRET_ID
kubectl --context minikube create namespace lumen --dry-run=client -o yaml | kubectl --context minikube apply -f - 2>/dev/null
kubectl --context minikube -n lumen create secret generic lumen-bao-credentials \
  --from-literal=LUMEN_BAO_ADDR=http://bao.secrets.svc.cluster.local:8200 \
  --from-literal=LUMEN_BAO_ROLE_ID=$P_ROLE_ID --from-literal=LUMEN_BAO_SECRET_ID=$P_SECRET_ID
```

Unseal again after every Bao pod restart (file storage survives; seal state
doesn't): `$B operator unseal <UNSEAL_KEY>`.

### A8. Seed the values — the CRs ARE the contract

Write `kv/data/{app}/dev` with EXACTLY the keys each ExternalSecret declares
(`vortex/overlays/dev/*/externalsecret.yaml`). Get Patroni's generated
passwords first (Zalando creates one Secret per user — discover the names):

```bash
kubectl --context minikube -n db get secrets | grep -i user     # e.g. lumen-pg-db-user-staging style
STAGING_PW=$(kubectl --context minikube -n db get secret <staging-user-secret> -o jsonpath='{.data.password}' | base64 -d)
JWT=$(openssl rand -hex 32)

curl -sS -X PUT -H "X-Vault-Token: $ROOT" -H 'Content-Type: application/json' \
  http://127.0.0.1:8200/v1/kv/data/lumen/dev -d '{ "data": {
    "LUMEN_DB_URL": "postgres://db_user_staging:'$STAGING_PW'@lumen-pg-postgres.db.svc:5432/lumen_staging",
    "LUMEN_MEILI_URL": "http://meilisearch.search.svc.cluster.local:7700",
    "LUMEN_MEILI_KEY": "'$MEILI_KEY'",
    "LUMEN_SESSION_JWT_SECRET": "'$JWT'" } }'

curl -sS -X PUT -H "X-Vault-Token: $ROOT" -H 'Content-Type: application/json' \
  http://127.0.0.1:8200/v1/kv/data/earendil/dev -d '{ "data": {
    "API_BASE": "http://lumen-http-server.lumen.svc.cluster.local" } }'

curl -sS -X PUT -H "X-Vault-Token: $ROOT" -H 'Content-Type: application/json' \
  http://127.0.0.1:8200/v1/kv/data/mellon/dev -d '{ "data": {
    "API_BASE": "http://lumen-http-server.lumen.svc.cluster.local" } }'
```

(local note: dev reuses the staging DB user — the CRs' `lumen/dev` path is the
rehearsal axis; prod would seed `lumen/production` with `db_user_production`.)

### A9. Watch it come up (the waves should fall like dominoes)

```bash
watch -n5 'kubectl --context minikube -n argocd get applications'
kubectl --context minikube get clustersecretstore bao            # Ready once seeded
kubectl --context minikube get pods -A | grep -v Completed
```

Expected order: openbao/external-secrets Running → store Ready after A8 →
lumen/earendil/mellon sync + roll with env from `lumen-secrets` / `app-config`.

### A10. Verify the estate (every check is CLI-verifiable)

```bash
echo "127.0.0.1 gofar.id console.gofar.id ainurrofiq.com" | sudo tee -a /etc/hosts   # once

# 1. blog renders FROM THE BACKEND (no mock anywhere in the runtime):
curl -s http://gofar.id:30080/ | grep -c 'gofar;'                       # ≥1
curl -s http://gofar.id:30080/api/posts | head -c 80                     # proxy → lumen → Patroni
# 2. portal answers and the session flow works:
curl -s -o /dev/null -w '%{http_code}\n' http://console.gofar.id:30080/login   # 200
# 3. the estate matrix sees the kv tree (log into console.gofar.id:30080 first):
#    /secrets → read lumen/dev → /secrets/summary shows the matrix
# 4. pin intent + drift tooling:
#    portal pin v1 on lumen/dev, then from lumen/:
go run ./cmd/lumen driftcheck            # key-set lines + pin warnings, exit 0
go run ./cmd/lumen driftcheck --strict-pin   # exits 1 while a pin is held
```

### A11. Day-2 drills (do these ONCE during the rehearsal — they're the point)

- **Unseal drill**: `kubectl --context minikube -n secrets delete pod -l app=openbao`
  (or rollout restart) → Bao comes back SEALED → store reds → re-run A7's unseal
  line → everything reconciles. 30-second drill, §7 language.
- **Pin flow**: portal pins a version, writes a new one, matrix shows
  amber `pin vN ≠ head`; unpins; driftcheck agrees.
- **Config rollout**: write a new `earendil/dev` API_BASE typo → ESO re-renders
  the ConfigMap within refreshInterval (1h — or `kubectl annotate externalsecret
  frontend-config pod-external-secrets-io/reload=true`... simplest: bump via
  portal and wait / restart the pod).

---

## 3. Part B — single VPS (production, same shape)

Do Part A first, end to end. The steps below are the DELTAS only.

### B0. Gates that must be green before real values exist (owner, non-negotiable)

- **GATE #5** — final read of `mellon/THREAT-NOTE.md` (gates seeding + #10).
- **GATE #9** — media provider picked → `LUMEN_MEDIA_*` keys: extend
  `overlays/production/lumen/externalsecret.yaml` in the same PR as the seed
  (the CR header marks the deferred families — that's the hook).
- **GATE #10** — console go-public checklist BEFORE DNS for `console.gofar.id`
  resolves publicly (surface #2 rule: TLS + gate, in that order).

### B1. Node prep — INFRA_ARCHITECTURE.md §Phase 2 "Path A" applies in full

Swap on (`failSwapOn=false`), sysctls, time sync. Single server node:
`curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable=servicelb" sh -`
(Bundled Traefik/`servicelb` stay disabled: we install the pinned chart —
same as everywhere else in this doc. Localhost labels: `node-pool=platform`
as in A1 — the Argo pinning patch demands it.)

### B2. Storage: `local-path` EXISTS on k3s — skip A2 entirely.

### B3. Traefik — same pinned chart, production flags:

```bash
helm install traefik traefik/traefik --version 42.3.2 -n ingress --create-namespace \
  --set deployment.hostNetwork=true \
  --set service.type=ClusterIP --set service.enabled=false \
  --set providers.kubernetesCRD.enabled=true \
  --set additionalArguments[0]="--metrics.prometheus" \
  --set "ports.web.redirectTo=websecure" \
  --set "ports.websecure.tls.enabled=true"
```

hostNetwork on a lone node = ports 80/443 directly (no LB exists without a
second node/MetalLB story; DNS A records point at the node IP regardless).

### B4. cert-manager + real TLS (this is the whole Part-B edge story):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl -n cert-manager wait --for=condition=Available deploy/cert-manager --timeout=180s
```

then the `letsencrypt-prod` ClusterIssuer + ACME email per INFRA Phase 3
(the snippet lives there verbatim). **Ordering rule (§3A):** `gofar.id` and
`console.gofar.id` A records must resolve to the node BEFORE first issuance —
and console only goes public AFTER GATE #10 clears.

### B5. Images — no more bare-name trick; CI contract or manual push

- Once the Phase 8 workflows exist (see §5 at the end): push a commit, CI builds
  `ghcr.io/kanatabi/<app>:sha-<short>` and PRs the `kustomize edit set image`
  bump into vortex; hub syncs.
- Private GHCR packages → per-namespace pull secret (deployments' headers
  already carry the comment):
  `kubectl -n <ns> create secret docker-registry ghcr-pull --docker-server=ghcr.io --docker-username=kanatabi --docker-password=<PAT: read:packages>` + add `imagePullSecrets` in the base pods (one PR).
- Manual path until then: `docker build -t ghcr.io/kanatabi/lumen:sha-$(git -C lumen rev-parse --short=7 HEAD) lumen && docker push ...` then edit `applications/lumen/kustomization.yaml` `images:` via `kustomize edit set image` and PR it — same names the CI hook expects.

### B6. 2-GiB-node trimming (only if the VPS is the 2 GB build in the budget table)

Skip observability (not in the hub anyway); `kubectl patch deploy` is FORBIDDEN
(selfHeal fights it) — instead fork nothing: lower the requests/limits files
under `applications/*/` via a real PR if the node genuinely can't take the
shape, or resize the VPS (blog-scale truth: the stack fits 4 Gi comfortably;
2 Gi is the multi-node master's budget, not a one-node cluster's).

### B7. Seeds: `kv/{app}/production` (+ staging later)

Same A7/A8 flow with two changes: (1) the **§5.6 policy cap** — production
portal policy grants `kv/data/{app}/{env}` scoped paths per app, not global
`*` (dev's `kv/*` shape is rehearsed here, capped in prod — that cap is the
ledger's C4 item, and its text belongs in a PR-reviewed policy file);
(2) seed `lumen/production` with `db_user_production` + a fresh
`LUMEN_SESSION_JWT_SECRET` (never reuse the rehearsal's).

### B8. Verification = A10, plus:

- `curl -I https://gofar.id/` → Traefik→cert-manager→real TLS, 200.
- matrix/driftcheck as in A10; Bao unsealed only via the offline key — keep
  §A11 drills as the ops calendar.
- Backup story (restic → object storage for Bao `/data` PVC + Patroni barman/
  volume snapshots; DR order: restore Bao PVC → unseal → ESO reconciles) —
  INFRA §5.6/DR sections; the three never-losables (unseal key, age key,
  first-boot Argo admin creds) live OUTSIDE the node, encrypted.

---

## 4. Part C — scale-out later (the blueprint reasserts itself)

When worker-2/3 arrive:

1. Join them (`INSTALL_K3S_EXEC="agent --node-name=worker-N ..."` per INFRA Phase 1).
2. Label pools: new nodes `node-pool=data|edge` (data = DB/ESO-era workloads,
   edge = SSR/portal/meili; the `platform` node keeps only Argo).
3. **Repoint the hub** (the one-line cutover): delete
   `platform-apps-hub` if the single-node one is live, apply
   `bootstrap/apps-hub.yaml` (the 3-node hub → `apps/` → bases +
   `overlays/production` once seeded). The components simply stop being
   referenced — replica pairs and anti-affinity come back with zero manifest
   edits (this is why A/B never patched the bases).
4. Re-run B8 + the failover/anti-affinity checks from root README §5.

---

## 5. Known-unverified (this doc will get honest footnotes as Phase A runs)

- Argo `v2.13.2` against k3s v1.37 (client-go compat) — check on first A5 apply.
- Traefik 42.3.2 `ports.web.nodePort` + hostNetwork key names — verify at install time.
- Zalando secret naming for generated user creds — discover via `get secrets` (A8).
- Everything else above is asserted from files/commits in the repos at these pins.
