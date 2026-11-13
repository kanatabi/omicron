# RUNBOOK.md — bringing the omicron estate up on ONE node

One document, two destinations: **Part A** runs the whole infra on your local
minikube (the rehearsal), **Part B** runs it on the single VPS (production), and
**Part C** is the later scale-out to the 3-node blueprint. The cluster SHAPE is
identical in A and B — that's deliberate: rehearsing here IS validating there.

Mental model (INFRA_ARCHITECTURE.md is the WHY; this is the HOW):

```
merge (app repo) → CI gates ONLY — a merge never deploys anything
merge to main parks THREE approval jobs (semver-patch|minor|major), EACH on
its own protected environment (release-patch|release-minor|release-major —
NEVER shared: one environment approval releases every job waiting on it)
→ the human approves EXACTLY ONE → that job
pushes the v-tag via RELEASE_BOT_PAT (a default-token tag never cascades) →
the tag push triggers release.yml: build → ghcr.io/kanatabi/<app>:vX.Y.Z →
bump PR in vortex (deploy-bump label, fenced) → merge → Argo CD syncs vortex
→ ESO reads kv/{app}/{env} from OpenBao → renders ConfigMaps/Secrets → pods
roll. Only RELEASED TAGS reach the cluster — never branch builds, never
:latest. Values live ONLY in Bao; Git ONLY templates.
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
  --set service.spec.type=NodePort \
  --set 'ports.web.nodePort=30080' \
  --set providers.kubernetesCRD.enabled=true \
  --set 'additionalArguments[0]=--metrics.prometheus'

# WALK-PROVEN (2026-11-10): chart 42.x moved Service knobs under service.spec
# (bare service.type = schema-rejected); quote the bracket args — zsh globs
# [0]. Verified render: NodePort 80:30080/443:<random>, class name traefik.
```

No `redirectTo`/tls here: the local chain uses `components/selfsigned` (TLS
stripped); forcing https to a self-signed cert would only train you to ignore
warnings. Class name is the default `traefik` — matches every Ingress in Git.

### A4. Build + load the three app images (bare names = the local trick)

The base deployments reference `image: lumen` / `earendil` / `mellon` — in prod
a release dispatch rewrites those to `ghcr.io/kanatabi/<app>:vX.Y.Z` via
`kustomize edit set image` (anvil's deploy-bump). Locally, build UNDER the bare
name so `IfNotPresent` finds them node-side with zero Git edits (same trick as
the old k3d placeholder flow, now with real images) — this local regime
coexists with the ghcr regime until the first v-tag bump merges:

```bash
cd omicron
for app in lumen earendil mellon; do
  docker build -t $app ./$app
  minikube -p minikube image load docker.io/library/$app:latest
done
```

WALK-PROVEN gotcha: load with the FULLY-QUALIFIED name. `minikube image load
lumen:latest` exits 0 but the image lands where the kubelet's containerd (k8s.io
namespace) cannot find it; `docker.io/library/lumen:latest` is what the runtime
resolves `image: lumen` to. Verify with:
`docker exec minikube ctr -n k8s.io images ls -q | grep library/lumen`.

Verified on this machine (2026-11-10): all three Dockerfiles build clean;
earendil serves real lumen content, mellon serves the authed dashboard against
the dev plane. Images ~35 MB (distroless Go) / ~260 MB (node SSR) each.

### A5. Manual platform pieces (before the hub)

```bash
# 1. ESO's namespace is NO LONGER manual — the kustomize wrapper owns it (2026-11-10
#    restructure; see applications/external-secrets/. Nothing to do here.)

# 2. Zalando operator: v2.0.3 (the v1.13.0 single-file URL in the old scaffold
#    404s — no such artifact ever shipped in that shape). CRDs cluster-scoped,
#    the rest namespace-scoped (default is the upstream shape; the operator
#    config MUST carry watched_namespace '*' to reach the db namespace):
Z=https://raw.githubusercontent.com/zalando/postgres-operator/v2.0.3/manifests
cd /tmp && mkdir zal && cd zal
for f in postgresql.crd.yaml operatorconfiguration.crd.yaml configmap.yaml \
         operator-service-account-rbac.yaml postgres-operator.yaml api-service.yaml; do
  curl -sfO $Z/$f
done
kubectl --context minikube apply -f postgresql.crd.yaml -f operatorconfiguration.crd.yaml
kubectl --context minikube apply -f operator-service-account-rbac.yaml -f configmap.yaml \
  -f postgres-operator.yaml -f api-service.yaml
kubectl --context minikube get cm postgres-operator -o jsonpath='{.data.watched_namespace}'; echo
# expect '*' — if empty, the operator only sees `default` and lumen-pg (ns db)
# will never be created:
#   kubectl -n default patch cm postgres-operator --type=merge -p '{"data":{"watched_namespace":"*"}}'
#   kubectl -n default rollout restart deploy/postgres-operator
kubectl --context minikube -n default wait --for=condition=Available \
  deploy/postgres-operator --timeout=180s

# 3. Meilisearch master key — generate ONCE, reuse in A8's seed (they must match)
MEILI_KEY=$(openssl rand -hex 16)
kubectl --context minikube create namespace search --dry-run=client -o yaml |
  kubectl --context minikube apply -f -
kubectl --context minikube -n search create secret generic meilisearch-master-key \
  --from-literal=master-key=$MEILI_KEY

# 4. Argo CD (pinned v3.6.1 — raised from v2.13.2 on walk evidence, see
#    platform/argocd/kustomization.yaml header; --server-side is MANDATORY:
#    Argo's CRDs exceed the 256KiB last-applied-configuration ceiling in BOTH
#    kubectl and Argo client-side paths)
cd vortex
kubectl --context minikube apply -k platform/argocd/ --server-side --force-conflicts
kubectl --context minikube -n argocd wait --for=condition=Available \
  deploy/argocd-server --timeout=300s
# NOTE: application-controller is a STATEFULSET (argocd-application-controller) —
# waiting on deploy/ for it fails. argocd-cm now carries kustomize.buildOptions:
# --enable-helm (in the overlay) — required for the ESO chart wrapper; after
# CHANGING that config: kubectl -n argocd rollout restart deploy/argocd-repo-server.
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

WALK NOTES on propagation (2026-11-10): (1) repo-server manifest caching is
stubborn — after pushing a fix that a stuck app won't pick up, the proven
sequence is `rollout restart deploy/argocd-repo-server` + `refresh":"hard"` on
the app (one app even needed its child Application deleted to shake a wedged
operation — hub selfHeal recreates it). (2) CRDs first applied CLIENT-side
carry a huge `kubectl.kubernetes.io/last-applied-configuration` annotation the
SSA sync now fights; one-time purge:
`kubectl annotate crd clustersecretstores.external-secrets.io secretstores.external-secrets.io kubectl.kubernetes.io/last-applied-configuration-`.

### A7. OpenBao bootstrap (the §5.6 manual one-time — init, unseal, mount, roles)

Follow the header checklist in `applications/openbao/openbao.yaml`; concretely:

```bash
# WALK-PROVEN CLI shape: the bao binary insists on VAULT_ADDR (defaults to
# https; our listener is tls_disable) and heredocs need `exec -i`. Define:
X() { kubectl --context minikube -n secrets exec -i deploy/openbao -- \
  sh -c "export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$${VAULT_TOKEN:-}; $1"; }
B="X bao"   # every call below goes through X()
INIT=$(X 'bao operator init -key-shares=1 -key-threshold=1 -format=json')
echo "$INIT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('UNSEAL='+d['unseal_keys_b64'][0]); print('ROOT='+d['root_token'])"
# >>> COPY BOTH LINES OUT NOW — the unseal key lives OFFLINE (password manager /
#     printed paper). Losing it = losing every value in the estate, DR doc §5.6. <<<
# extract with sed, NOT cut -d= : base64 keys CONTAIN '=' padding (cut truncates!)
K=$(sed -n 's/^UNSEAL=//p' keys.txt); R=$(sed -n 's/^ROOT=//p' keys.txt)
$B operator unseal "$K"
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

> **AppRole lifetimes, settled by pain** (2026-11-10/11): issue roles with
> `secret_id_num_uses=0` (unlimited) BEFORE ever minting ids — a single-use
> secret-id is consumed by the first login and the consumer (ESO or lumen)
> dies silently when its 1h token refreshes: `ClusterSecretStore ... unable
> to create client` / relay 500 `{"error":"internal error"}` are that corpse.
> Rotation later = write a new Secret value + rollout restart (selfHeal never
> reverts Secrets it doesn't track). And extraction hygiene: `bao read
> -format=json -field=role_id` returns a QUOTED string — `tr -d '\r\n" '`
> or you paste `"abc…"` into the Secret and get `invalid role or secret ID`
> (both traps walked live). PROVE every pair by logging in with it before
> declaring done (the walk's own final proof line):
> `bao write -format=json -field=token auth/approle/login role_id=… secret_id=…`

Role creation notes from the walk: `bao write auth/approle/role/...` succeeds
SILENTLY re role_id — read it back with `-field=role_id`; secret-ids need
`bao write -force -format=json -field=secret_id auth/approle/role/<r>/secret-id`
(-force: empty K=V body is otherwise rejected). NEVER extract pretty-JSON with
`sed s/.*"token":"..."/` over MULTILINE output — pipe the value through
tr -d '\r\n' and VERIFY length==36 (a mangled UUID became a Secret of garbage
and a lost sync cycle); prove each pair by actually logging in:
`bao write -format=json -field=token auth/approle/login role_id=.. secret_id=..`

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
# WALK-PROVEN v2.0.3 naming: secrets are `{user}.{cluster}.credentials.postgresql.acid.zalan.do`
# (dots IN the name); the Patroni master Service is `{cluster}.{namespace}.svc` —
# lumen-pg.db.svc, NOT the old lumen-pg-postgres the scaffold comments claimed.
kubectl --context minikube -n db get secrets --no-headers | awk '{print $1}' | grep credentials
STAGING_PW=$(kubectl --context minikube -n db get secret \
  'db-user-staging.lumen-pg.credentials.postgresql.acid.zalan.do' \
  -o 'jsonpath={.data.password}' | base64 -d)
JWT=$(openssl rand -hex 32)

curl -sS -X PUT -H "X-Vault-Token: $ROOT" -H 'Content-Type: application/json' \
  http://127.0.0.1:8200/v1/kv/data/lumen/dev -d '{ "data": {
    "LUMEN_DB_URL": "postgres://db_user_staging:'$STAGING_PW'@lumen-pg.db.svc:5432/lumen_staging",
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
rehearsal axis; prod would seed `lumen/production` with `db_user_production`.
CLI gotcha: `bao kv put` REPLACES the whole map — write ALL keys of one path in
SINGLE invocation (a mid-list failure silently stripped the rest; verify with
`bao kv get -format=json kv/<path>` and diff the key list against the CR.)

MATERIALIZE TIMING (walk-proven, matters): ExternalSecrets created BEFORE the
kv seed (the normal first-boot order — waves gate creation, ESO syncs
immediately, finds nothing, schedules its next try at refreshInterval = 1h
away) look Ready-but-empty. Force the refresh honestly: `kubectl delete
externalsecret -n <ns> <name>` — Argo selfHeal recreates it within seconds and
the fresh object reconciles on creation. Then `kubectl rollout restart
deploy/...` in every consumer namespace: envFrom binds ONLY at container start,
so pods that booted blind must be recycled once the Secret/ConfigMap exists.

### A8b. Schema + admin: what is automatic vs manual now

Schema is a DEPLOYMENT PROPERTY, not an operator step: the lumen Application
ships a PreSync hook Job (`applications/lumen/migrate-job.yaml`) running
`lumen migrate` (store SQL + river queue tables) before any workload syncs —
every sync, idempotent; a failed migration BLOCKS the rollout (old pods keep
serving). Nothing to do.

THE PRIMARY PATH (since 2026-11-11): there is no admin-bootstrap step at all.
With the users table empty, the portal itself opens as `/setup` — the first
visitor claims the estate (TOFU: one registration, ever; 410 Gone behind it,
advisory-lock atomic in lumen). Nothing to run, nothing to remember, no
password transiting any terminal. The Job below is RECOVERY-ONLY (headless
re-set when the portal itself is the thing that's broken):

```bash
kubectl --context minikube -n lumen create secret generic lumen-admin-password \
  --from-literal=password="$(openssl rand -hex 16)"
echo "admin password: $(kubectl --context minikube -n lumen get secret lumen-admin-password -o 'jsonpath={.data.password}' | base64 -d)"  # write it down NOW
kubectl --context minikube apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata: { name: lumen-bootstrap, namespace: lumen }
spec:
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: lumen
          image: lumen
          imagePullPolicy: IfNotPresent
          args: ["user", "--username", "gofar"]
          envFrom: [{ secretRef: { name: lumen-secrets } }]
          env:
            - name: LUMEN_PASSWORD
              valueFrom: { secretKeyRef: { name: lumen-admin-password, key: password } }
EOF
```

If the vault must be REBORN (lost unseal key — the walk proved it happens):
delete the pod-mount, PVC **and the node-side data dir** — the minikube
hostpath provisioner names directories by `<ns>/<pvc>` (`/tmp/hostpath-
provisioner/secrets/openbao`) and Retain + PV deletion does NOT wipe it;
re-seed via A8; every consumer Secret/credential is re-issued from A7.

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
echo "$(minikube ip) gofar.id www.gofar.id console.gofar.id" | sudo tee -a /etc/hosts   # once. NODE IP, not 127.0.0.1 — NodePorts live on the node. (The earendil ingress was cut over to gofar.id/www 2026-11-11; ainurrofiq.com is no longer routed — a plain-text "404 page not found" from Traefik means the Host matched no rule.)

# 1. blog renders FROM THE BACKEND (no mock anywhere in the runtime):
curl -s http://gofar.id:30080/ | grep -c 'gofar;'                       # ≥1
curl -s http://gofar.id:30080/api/posts | head -c 80                     # proxy → lumen → engine
# THE DEEPEST-ROUTE RULE (learned twice): the listing 200'd while /posts/[slug]
# 500d — only the post page RUNS the markdown pipeline (anchors, Shiki fences,
# mermaid placeholders, task-lists). Smoke the route that does the work:
curl -s http://gofar.id:30080/posts/<any-slug> | grep -c 'h1 id'        # ≥1, and no MODULE_NOT_FOUND in pod logs
# curl quirk on the portal proxy: SvelteKit guards state-changing requests by
# Origin — send -H "Origin: http://console.gofar.id:30080" on POST/DELETE
# tests (browsers always do; its absence is a 403 "Cross-site ... forbidden",
# NOT an auth problem).
# 2. portal answers and the session flow works (fresh cluster: /login will
#    REDIRECT to /setup until a human claims the estate — that bounce IS the
#    success signal; claiming here, once, is the owner's manual act)
curl -s -o /dev/null -w '%{http_code}\n' http://console.gofar.id:30080/login   # 200
# PORTAL ACCESS LAW (learned the hard way, twice): reach mellon ONLY via the
# edge — http://console.gofar.id:30080 (hosts alias -> `minikube ip`, NOT
# 127.0.0.1; NodePort lives on the node). kubectl port-forward BREAKS form
# POSTs (origin reconstruction sees neither the name nor, pre-fix, the
# protocol) and the session cookie cannot be Secure over plain http on a
# non-localhost name. Both are now enforced correctly in code (cookieTrust +
# PROTOCOL_HEADER), so the edge path is not just "the way that works" — it is
# the way that is TRUE.
# 3. the estate matrix sees the kv tree (log into console.gofar.id:30080 first):
#    /secrets → read lumen/dev → /configs shows the matrix
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
- **Sealed-after-reboot** (PROVEN LIVE, uninvited, 2026-11-13: a host reboot
  re-sealed Bao): symptom chain = every ExternalSecret red with
  `could not get secret data from provider`, apps fine until they restart,
  then CrashLoops arrive as Secrets/ConfigMaps go stale-render... the fix is
  the A7 ritual, not an investigation: `bao operator unseal <key>` x3 from
  `~/bao-rehearsal/keys` (non-tty: pass key as ARGUMENT, stdin piping fails),
  ESO re-auths within ~a minute (bounce the controller to skip its backoff).
  ES `get`'s "last sync" timestamps read like 30h — trust
  `describe`'s `Last Transition Time` for WHEN it broke.
- **Engine-bump recipe (derived data)** — meili v1.10→v1.56 taught it: the
  engine REFUSES old data volumes (refuses, does not reindex, does not
  migrate — crash loop on boot). And minikube local-path keys host
  directories by `ns/pvc-name`: **delete the PVC, and the recreated one
  remounts the SAME old directory** (async reclaim never wins the race).
  The honest wipe: `docker exec minikube rm -rf
  /tmp/hostpath-provisioner/<ns>/<pvc>/*` → pod restarts empty → run
  `cmd/seed` with port-forwards at the cluster DB + engine (its reconcile
  mode leaves rows alone, enqueues index_post per PUBLISHED post, drains).
  Verified: engine stats 1 doc = the 1 published post; 2 drafts correctly
  absent. lumen worker bootstrap creates the index; seed fills it — no
  reindex verb exists yet (logged gap: admin "reindex all" is the
  proper fix; portal needs a button).

### A12. Day-2 — shipping a release (the only way anything deploys)

Prerequisite owner one-timers (once, DONE as of 2026-11-13 except #1):

1. **GHCR package visibility** (still open for earendil/mellon). First push to
   `ghcr.io/kanatabi/<app>` creates the package inheriting repo visibility;
   lumen is public → its package is public → cluster pulls anonymously.
   earendil/mellon are PRIVATE repos → their first packages land private →
   `ImagePullBackOff: unauthorized` the moment a v-tag pin syncs. Either flip
   each package to public (recommended — images are non-secret artifacts) or
   wire `ghcr-pull` docker secrets + `imagePullSecrets` per namespace (B5).
2. **Twelve per-purpose environments with required-reviewer = self**:
   `release-patch`, `release-minor`, `release-major` AND `deploy` in each
   app repo. NEVER share one environment between jobs: environment
   approvals are BATCHED PER ENVIRONMENT (proven live 2026-11-13 — one
   approval of a shared `release` env pushed v0.1.0 AND v1.0.0 at once).
   PROVEN fixed the same day: lumen run #5 parked all three jobs `waiting`
   independently. Re-check protection on any new repo (or use the deferred
   provisioning design in anvil's README Backlog).
3. **`RELEASE_BOT_PAT`** (Contents:RW + **Workflow:RW** + **Actions:RW** on
    the three app repos ONLY, 90-day expiry) + **`VORTEX_BOT_PAT`** — both
    configured as repo secrets. Without Workflow: the PAT's tag pushes create
    NO event and nothing ever deploys (first incident, proven via the events
    API). Without Actions: the settle step cannot post sibling-decline reviews
    (warn-only — releases still work, the human declines by hand). Revoking
    RELEASE_BOT_PAT is the emergency brake on ALL releasing.
4. **`DEPLOY_AUTOMERGE`** repo Variable on vortex: LEAVE ABSENT until you have
   watched ≥1 clean manual bump cycle; absent = off = every bump PR merges by
   human hands.

The flow (per release):

1. Merge a PR to main (or push) → `ci.yml` runs gates (+ contract on earendil)
   → **three jobs park, EACH on its own environment: `semver-patch` on
   `release-patch`, `semver-minor` on `release-minor`, `semver-major` on
   `release-major`, all amber "Waiting".** The merge itself deploys
   nothing and releases nothing.
2. Open the run, **approve ONE bump job** (Review deployments → the card
    IS the job now; the released job then SETTLES — its siblings' pending
    reviews are auto-declined under hard fences (`release-*` of this run
    only, never `deploy`), so the whole pipeline goes terminal on your one
    click. If settle ever warns, decline them by hand (else they expire at
    24h). Double-approve of DIFFERENT envs = double-release, last merge
    wins, nothing corrupts). Approving the job IS the release decision;
    the version = **highest-version reachable tag** + that literal bump —
    version-ordered, NEVER `git describe` (it sorts equidistant tags by
    creation DATE: lumen's v0.2.0-minted-after-v1.0.0 made major compute
    an EXISTING tag; the collision guard now refuses loudly instead).
    No tags yet: patch|minor -> v0.1.0, major -> v1.0.0.
3. The approved job pushes the annotated tag **via RELEASE_BOT_PAT** — never
   with the default token: `GITHUB_TOKEN` events don't cascade, so a
   "green" run would silently deploy nothing (`push-release.sh` refuses to
   run without the PAT for exactly this reason).
4. The tag push TRIGGERS `release.yml`: `publish-image` (ghcr `:vX.Y.Z` +
   `:latest` alias — tooling only, a deploy pin must never reference it) →
   `deploy-plan` runs AUTOMATICALLY and is the evidence: rehearses the bump
   against real vortex main, prints current-pin → proposed-pin, the exact
   diff, and a full manifest validation — pushing nothing. Read that job's
   log (or the run summary) NOW, not later.
5. `deploy` PARKS on the protected `deploy` environment. Approving it is
   the deploy decision; the job re-validates BEFORE pushing and opens the
   vortex PR (label `deploy-bump`, diff = `images:` stanza only —
   born-validated). Vortex CI validates independently; **merge only when
   `validate-manifests` is GREEN** (or make it a required status check on
   vortex main — admin-enforcement off — and physics replaces discipline).
   Argo (targetRevision HEAD) syncs within its poll interval.

**Manifest edits do NOT ride this chain.** A replicas/resources/yaml change
merged to vortex main syncs by ARGO ALONE (auto-sync, ~3 min) — nothing in
GitHub needs retriggering; the deploy job's only power is the image PIN.
The diff gate for manifest changes is the vortex PR itself (validate-
manifests posts the RENDERED diff); live-vs-new is Argo's own Diff tab.
PROVEN 2026-11-13: bump PR #4 (`lumen → v1.0.0`) merged via UI, Argo
synced, pods read `ghcr.io/kanatabi/lumen:v1.0.0` — the estate's first ghcr
deploy; a `v0.2.0` bump branch appeared from a tag push alone, proving the
PAT+Workflow cascade fires on its own.

**The fail-open check, every time you touch this machinery:** if those three
jobs ever EXECUTE without a Waiting badge, the environment protection is
gone — decline nothing, fix Settings → Environments first, trust no release
in the meantime.

- **Rollback** = `git revert` the bump commit in vortex, human PR, human
  merge — or re-run `release.yml` via "Run workflow" with the older tag
  typed in (redeploy = release; the tag is immutable and still in ghcr).
- **Verify** after sync: `kubectl --context minikube -n <ns> get pod -o
  jsonpath='{.items[*].spec.containers[*].image}'` reads `…:vX.Y.Z`, and lumen
  `/healthz` reports the stamped version (it now equals the tag).
- Watch the first cycle pod-by-pod: this cluster has never pulled from ghcr —
  the local bare-name regime (A4) retires one deployment at a time.

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

### B5. Images — release pipeline or manual push (no more bare-name trick)

- The release pipeline EXISTS and is the sanctioned path (A12): dispatch
  `release.yml` → gates → v-tag → ghcr push → fenced bump PR → merge → sync.
  On the VPS this needs nothing new except the package-visibility choice made
  once (A12 pre-flight #1 — public packages need zero cluster-side acts;
  private needs the pull-secret PR below per cluster).
- Private GHCR packages → per-namespace pull secret (deployments' headers
  already carry the comment):
  `kubectl -n <ns> create secret docker-registry ghcr-pull --docker-server=ghcr.io --docker-username=kanatabi --docker-password=<PAT: read:packages>` + add `imagePullSecrets` in the base pods (one PR).
- Manual escape hatch (incidents only, still tag-shaped): build + push
  `ghcr.io/kanatabi/<app>:vX.Y.Z` by hand, then a HUMAN vortex PR editing
  `applications/<app>/kustomization.yaml` `images:` via `kustomize edit set
  image` — same lines the bot fence guards; human PRs never auto-merge.

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

## 5. Walk ledger — what the live rehearsal has proven / still open

PROVEN on minikube 2026-11-10 (each entry was a §5 unknown until it ran):
- Argo v3.6.1 on k3s v1.37 healthy (v2.13.2 ROLLED OUT FINE TOO but cannot do
  OCI charts: wrong helm args; the pin bump was about capability, not compat).
- kustomize helmCharts path: ESO 2.15.0 renders 25 CRDs + controller/webhook/
  cert-controller all Ready through the repo-server's helm binary — while BOTH
  of Argo's own OCI paths 403 against ghcr's anonymous policy. The policy nuance
  (which clients the token endpoint admits) belongs to ghcr day-to-day, but the
  architecture no longer cares.
- fat-CRD SSA requirement (kubectl AND Argo paths, identical 256KiB wall).
- Traefik 42.3.2 values shape (service.spec.type, quoted nodePort args).
- Zalando v2.0.3: file set, watched_namespace '*', typed Patroni fields,
  required spec.postgresql(+version), secrets naming, lumen-pg.db.svc.
- ESO CRD strictness: vault.version lowercase enum; template.type is a NO-OP
  (target.type is the materialization switch — apiserver prunes the unknown);
  webhook spec-defaults (creationPolicy etc.) require ignoreDifferences or
  selfHeal thrashes (patched into the hub CRs).
- OpenBao liveness must be tcpSocket (exec-probe killed sealed pods; the
  unseal drill needs a live sealed pod).
- AppRole extraction pitfalls (sed-not-cut, -field, -force, login-proof).

ADDITIONALLY PROVEN across 2026-11-10/11 (the walk finished):
- Full estate Synced/Healthy; blog + portal + matrix + preview all live through
  Traefik; login proven on BOTH postures: http origin -> cookie WITHOUT
  Secure, https origin (websecure NodePort) -> Set-Cookie WITH Secure.
- PreSync migrate hook executed on real syncs; pin-drift demo end-to-end
  (write v3, pin v1, matrix renders the amber `pin v1` cell, unpin clears).
- Vault reborn after lost-unseal-key: A8b reinit recipe + the node-dir trap
  (hostpath provisioner keys directories by ns/claim — PV delete is NOT
  enough) + roles re-issued with unlimited-use secret-ids.
- Production-build-only bug class EXTERNALIZED for mellon (jsdom/shiki are
  package-layout resolvers; the runtime image now carries pruned prod
  node_modules — "self-contained build/" remains true for earendil).

- Chrome mouse drag in the real browser: PROVEN by the owner (2026-11-12)
  after the drag-image-lifetime + deferred-lift fixes; T-dragm pins it.
PROVEN (tooling): anvil validate-all/diff-render/set-image-pr exercised
  against the real vortex tree (25-dir table GREEN; bump dry-run = 2-line
  diff passing the fence).
- Informed deploy chain PROVEN live end to end (2026-11-13): bump approval
  -> tag -> cascade -> build -> deploy-plan evidence -> deploy gate ->
  born-validated PR -> merge -> Argo. lumen runs v2.0.0 from ghcr; pods,
  feed, and search verified after the meili incident (A11 engine-bump
  recipe executed under fire: host-dir wipe + seed reconcile = 1 published
  post indexed, drafts correctly absent).
- Node-reboot/sealed-Bao drill: PROVEN UNINVITED (A11 ritual restored the
  estate in minutes; ES Last-Transition-Time was the honest clock).
- Auto-merge blockers audited BEFORE enabling (the guard had never run in
  anger; poll-early-bug + read-only-merge-perm both real, both fixed:
  anvil@9128181, vortex@b1f6789).

STILL OPEN:
- DEPLOY_AUTOMERGE: ENABLED (variable exists; env door shipped — anvil
  0b90ba4, vortex d77d4b2). Watch the FIRST auto-merge live: PR #8
  (bump/earendil-v1.1.0) after (a) earendil package made PUBLIC and (b) a
  remove+re-add of the deploy-bump label. Kill switch = delete variable.
- Close the stale bump PRs in vortex: bump/lumen-v0.2.0 (downgrade-bait)
  + the three sha-era pre-doctrine ones.
- earendil's release.yml mystery: two released tags, zero deploy attempts —
  read its (private) Actions logs at its next release before trusting it.
- earendil/mellon GHCR packages must go PUBLIC (or pull-secrets wired)
  before their first bump PR merges — their repos are private, so the
  packages inherited private on first push.
- settle POST declined silently in production (warn-only did its job:
  releases completed, siblings needed manual decline). Diagnostics round
  shelved by owner 2026-11-13 — suspects S1 (mid-run review writes refused)
  vs S2 (per-deployment-reviewer payload shape); frozen evidence + plan
  live in the session notes file DEFERRED-settle-diagnostics.md.
- Reindex verb gap: backfill currently = run cmd/seed reconcile; the
  proper fix is an admin `reindex all` + a portal button (follow-up).
- ~~meili version drift~~ RESOLVED 2026-11-13: manifests bumped to v1.56.1
  (vortex 7e32ad4) to match compose/CI — what dev+CI test is what prod runs.
- Part B (VPS) ordering — inherits every A lesson but has not run yet.
- Observability overlays on one node (excluded from the hub by design).
- staging twin host (still `staging.ainurrofiq.com` in overlays/staging — prod
  earendil is gofar.id now; the staging name is an open owner call).
- ~~gofar.id ingress cutover~~ DONE 2026-11-11 (owner commit 7b2c5cc; verified
  live: gofar.id + www route, old names correctly 404 at the edge).
- Portal + earendil SSR externals settled: shiki/jsdom-chain external, runtime
  images carry pruned prod node_modules (both SSR apps); lumen runtime is pinned
  alpine (kubectl exec works; uid 65532 kept) — walk-proven.
