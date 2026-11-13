---
tags: [runbook, secrets, vault]
updated: 2026-11-14
status: ritual incident-proven (rehearsal walk + two unseal drills); the
  THREE-plane seed contract below is the Phase 11 shape — verified key-by-key
  against the ExternalSecret CRs on the vortex main tip; VPS = first real
  production seeding — the 3/2 key shape below is production-only
---

# 05 · Secrets Vault — OpenBao + ESO: values live only here

> **Why a vault at all:** passwords in Git are forever public (even in
> private repos, forever in backups/logs/forks). The estate's rule is
> absolute: **Git holds templates, Bao holds values.** Anything that
> renders — a database URL, a CDN token, a search key — gets its value from
> the vault at boot, and the vault is the single place to concentrate your
> paranoia.

The manifests already exist (`vortex/bases/openbao|external-secrets|
secrets-plane`, brought up by chapter 04's FOUNDATION hub). This chapter
is the **manual bootstrap** they can't self-start: the vault cannot unlock
itself (the docs call this the bootstrap paradox, INFRA §5.6).

> **🔴 THE RENDER CONTRACT — read this before you seed a single key:**
> the ExternalSecret `data:` lists ARE the contract, and **ESO fails the
> WHOLE render on ONE missing property** — not the key, the entire Secret,
> not the Secret, the whole app sync. So the rule is loud and absolute:
> **every key named in §6's tables must exist in Bao BEFORE its hub
> syncs.** That is why the entry order is foundation hub → *this chapter* →
> staging/production hubs, and why foundation's own wave 2 (lumen-admin)
> waits for the store to be Ready. For lumen the contract is
> machine-readable: `lumen config keys --role admin|cms` prints exactly what
> each plane binds; the ES lists mirror it.
>
> **The three planes you are seeding:** `shared` (foundation: the ONE
> lumen-admin Control Plane, the ONE Patroni with three logical DBs, the ONE
> Meilisearch, the ONE observability stack), `staging` and `production` (the
> cms/content planes). `dev` is GONE — the retired `overlays/{dev,local}`
> trees took it with them; nothing reads `kv/*/dev` anymore.

One door, two keys-hands: every step below runs in **either** of two
equivalent variants — **A) `kubectl exec` + the `bao` CLI inside the pod**,
or **B) `kubectl port-forward` + plain `curl` from your laptop**. Read §2
for the shape, then pick a variant per taste; both are given in full because
the day the pod's shell misbehaves (it has), the HTTP API saved the walk.

## 1. The vault comes up with the FOUNDATION hub (ch. 04), sealed

You'll see: `openbao` pod Running in namespace `secrets` (Deployment
`openbao`, Service `bao` — see `bases/openbao/openbao.yaml`), the
store's `bao` ClusterSecretStore **not-Ready**, and the vault itself
SEALED. **That is the expected state** — sealed vault = no values =
nothing renders. This ritual runs *between* the manual applies: the env
hubs (production, staging) stay unapplied until §8 says Go, which is
exactly how the split makes seed-before-apps structural. (Apply an env hub
early anyway and its ExternalSecrets go red with
`could not get secret data from provider` — the un-ordered shape the split
exists to prevent; finish here first.) It stops being scary at step 4.

The quirk to know in both variants: the listener is `tls_disable = 1`
(cluster-internal by design, §2 of the INFRA doc), so the CLI defaults to
https and finds nothing. Always say http:

```bash
export VAULT_ADDR=http://127.0.0.1:8200   # inside the pod (variant A)
# variant B gets this free: port-forward speaks to 127.0.0.1:8200 locally
```

## 2. The ritual, both doors (one diagram, then the commands)

```mermaid
sequenceDiagram
    autonumber
    participant L as Laptop (you)
    participant A as Variant A — kubectl exec<br/>bao CLI inside the pod
    participant B as Variant B — port-forward svc/bao<br/>curl on the laptop
    participant V as OpenBao :8200<br/>(http, tls_disable)
    Note over L,V: pick A or B per step — same calls, same order, never both at once
    L->>A: bao operator init -key-shares=3 -key-threshold=2
    A->>V: POST /v1/sys/init
    V-->>L: keys + root token land in /root/bao-init.json
    L->>L: scp /root/bao-init.json → laptop → offline store<br/>(BEFORE deleting the server copy!)
    L->>A: bao operator unseal <KEY> (×2, key as ARGUMENT)
    A->>V: POST /v1/sys/unseal
    L->>B: kubectl -n secrets port-forward svc/bao 8200:8200
    B->>V: curl -X POST http://127.0.0.1:8200/v1/sys/unseal -d '{"key":"…"}'
    L->>A: mount kv-v2 · enable approle · write policies · create roles
    Note over L,V: then the same over HTTP: sys/mounts/kv · sys/auth/approle · sys/policy/eso · auth/approle/role/eso
    L->>L: mint role-id + secret-id, kubectl create secret (the paradox family)
    L->>V: SEED kv/lumen/shared · lumen/{staging,production} · earendil · mellon (shared+envs)<br/>· grafana · cert-manager · meilisearch — every §6 table, BEFORE any env hub syncs
```

## 3. Variant A — `kubectl exec` + `bao` CLI

Wrap the exec once; every step reuses it:

```bash
X() { kubectl -n secrets exec -i deploy/openbao -- \
  sh -c "export VAULT_ADDR=http://127.0.0.1:8200; $1"; }
```

### 3.1 Init — do it ONCE, carefully

```bash
X 'bao operator init -key-shares=3 -key-threshold=2 -format=json' > /root/bao-init.json
```

> **Why 3 shares / threshold 2:** any single paper is worthless alone,
> **any two of the three open it**. One paper on one server = one fire =
> one loss (the rehearsal used 1/1 to stay simple; production deserves the
> better math). Losing all unseal keys = losing every value in the estate —
> INFRA §5.6 says so, and there is no support ticket that fixes it.

**The extraction step — do NOT skip, in this order:**

```bash
# FROM YOUR LAPTOP, while the init file still exists on the server:
scp <server>:/root/bao-init.json ~/Desktop/   # then straight into your
                                              # password manager AND/OR
                                              # paper, in two physical spots
```

> **The backup bucket never holds unseal keys — that's what "offline"
> means.** Restic ships this server's disks to R2 (ch. on backups); if the
> keys lived in a root file they'd ride that bucket, and anyone with the one
> backup credential could open the vault that guards the other ones. The
> keys' only homes: your laptop's transfer copy, then offline storage.
> **Delete `/root/bao-init.json` ONLY after the offline copies exist** —
> and remember which two of the three keys you kept; any pair works, the
> third is spare.

### 3.2 Unseal (twice)

```bash
X "bao operator unseal $(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['unseal_keys_b64'][0])")"
X "bao operator unseal $(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['unseal_keys_b64'][1])")"
# → "Sealed: false" on the second call. NOW delete /root/bao-init.json.
```

> **Non-tty lesson (incident-proven):** piping a key into `unseal` on stdin
> fails ("file descriptor 0 is not a terminal") — pass the key as the
> **argument**, as above. Same class of extraction hygiene: pull values with
> `python3`/`jq` — **never `cut -d=`**: base64 keys contain `=` padding and
> `cut` silently truncates them into uselessness (learned twice).

### 3.3 Mounts, auth, policies

```bash
ROOT=$(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['root_token'])")
X "export VAULT_TOKEN=$ROOT; bao kv enable version=2 kv"     # the values store
X "export VAULT_TOKEN=$ROOT; bao auth enable approle"        # machine logins

# ESO policy: READ/LIST only — the renderer must never write values.
X "export VAULT_TOKEN=$ROOT; bao policy write eso - <<'EOF'
path \"kv/data/*\"        { capabilities = [\"read\"] }
path \"kv/metadata/*\"    { capabilities = [\"read\", \"list\"] }
EOF"

# PORTAL policy (lumen-admin's relay for mellon): SCOPED per-app paths, not
# kv/* — INFRA §5.6 cap. With the env model the edit surface spans BOTH
# envs' lumen paths; every other app/env (and the shared plane) is
# read/list. Metadata listing is what powers mellon's matrix (§7).
X "export VAULT_TOKEN=$ROOT; bao policy write portal - <<'EOF'
path \"kv/data/lumen/staging\"     { capabilities = [\"read\",\"list\",\"create\",\"update\",\"patch\"] }
path \"kv/data/lumen/production\"  { capabilities = [\"read\",\"list\",\"create\",\"update\",\"patch\"] }
path \"kv/data/*/staging\"         { capabilities = [\"read\",\"list\"] }
path \"kv/data/*/production\"      { capabilities = [\"read\",\"list\"] }
path \"kv/data/*/shared\"          { capabilities = [\"read\",\"list\"] }
path \"kv/metadata/*\"             { capabilities = [\"read\",\"list\"] }
EOF"
```

> **Why the `shared` line reads but never writes:** `kv/lumen/shared` holds
> the estate's ONLY session signing key and the admin DSN. The relay may
> show it (matrix row), must not edit it casually — the same reason the
> `LUMEN_SESSION_JWT_SECRET` has exactly one home (§6).
> **OPEN (flagged, not invented):** the relay's app/env enumeration in
> mellon's onboarding wizard still defaults to `dev/staging/production` and
> whether `shared` becomes a first-class portal env is an undecided wire
> shape (options: keep shared off-limits to the wizard, or add it as a
> read-mostly class). Owner call — see [14](14-onboarding.md).

### 3.4 Roles — the time-bomb setting FIRST

```bash
# secret_id_num_uses=0 BEFORE minting any id — the single-use default is a
# silent time-bomb (the id dies at the first 1-hour token refresh). Learned
# the hard way; the proof line is at the end of §3.5.
X "export VAULT_TOKEN=$ROOT; bao write auth/approle/role/eso    token_policies=eso    token_ttl=1h token_type=service secret_id_num_uses=0"
X "export VAULT_TOKEN=$ROOT; bao write auth/approle/role/portal token_policies=portal token_ttl=1h token_type=service secret_id_num_uses=0"
```

### 3.5 Hand the pairs to their consumers (the bootstrap-paradox family)

These few credentials are **k8s Secrets created by hand** — they unlock the
store that would render them, so they can never ride it. The consumers'
manifests name them: `bases/secrets-plane/clustersecretstore.yaml`
wants `external-secrets/bao-approle-credentials` with keys **`role-id` +
`secret-id`**; the lumen family wants `lumen/lumen-bao-credentials` —
**consumed meaningfully by lumen-admin only** now: `LUMEN_BAO_*` binds
exclusively on the admin plane (`lumen config keys --role admin`; the relay
lives in the Control Plane). The cms deployments keep an `optional: true`
ref to the same un-suffixed Secret (single instance per namespace) and run
with the Bao paths dark — harmless by design.

```bash
# role_id reads plain; secret_id needs -force (empty body) and -field:
ESO_RID=$(X "export VAULT_TOKEN=$ROOT; bao read -format=json -field=role_id auth/approle/role/eso/role-id" | tr -d '\r\n\" ')
ESO_SID=$(X "export VAULT_TOKEN=$ROOT; bao write -force -format=json -field=secret_id auth/approle/role/eso/secret-id" | tr -d '\r\n\" ')
kubectl -n external-secrets create secret generic bao-approle-credentials \
  --from-literal=role-id=$ESO_RID --from-literal=secret-id=$ESO_SID
# portal family likewise → lumen-bao-credentials in namespace lumen
```

**Prove every pair by logging in with it** before declaring done — the walk
found two dead corpses that `create secret` had happily shipped:

```bash
X "export VAULT_TOKEN=dummy; bao write -format=json -field=token auth/approle/login role_id=$ESO_RID secret_id=$ESO_SID"
# a real token string back = alive; a 400 = you just saved yourself an hour
```

✅ check the store noticed: `kubectl -n external-secrets get clustersecretstore bao`
→ `Ready: True` once values exist (§6 forces it if timing beats you).

## 4. Variant B — `port-forward` + plain `curl` (no pod shell needed)

```bash
kubectl -n secrets port-forward svc/bao 8200:8200 &   # terminal tab 2
V=http://127.0.0.1:8200                                # terminal tab 1
```

Same ritual, all HTTP. (Bao's API speaks JSON at `/v1/…`; `jq -r` for
extraction — the `cut` rule applies doubly.)

```bash
# 1. INIT (once) — identical 3/2 math; SAVE THE RESPONSE FIRST (see §3.1 box)
curl -s -X POST $V/v1/sys/init \
  -d '{"secret_shares": 3, "secret_threshold": 2}' | tee ~/bao-init.json
ROOT=$(jq -r .root_token ~/bao-init.json)
K1=$(jq -r '.unseal_keys_b64[0]' ~/bao-init.json); K2=$(jq -r '.unseal_keys_b64[1]' ~/bao-init.json)
# → scp-safe: ~/bao-init.json now lives on the laptop; delete any server copy.

# 2. UNSEAL ×2 (any two of the three keys, every restart, forever)
curl -s -X POST $V/v1/sys/unseal -d "{\"key\": \"$K1\"}" >/dev/null
curl -s -X POST $V/v1/sys/unseal -d "{\"key\": \"$K2\"}" | jq .sealed   # → false

# 3. MOUNT kv-v2 + enable approle
curl -s -X POST $V/v1/sys/mounts/kv   -H "X-Vault-Token: $ROOT" -d '{"type": "kv-v2"}'
curl -s -X POST $V/v1/sys/auth/approle -H "X-Vault-Token: $ROOT" -d '{"type": "approle"}'

# 4. POLICIES (bodies mirror §3.3 exactly — eso read/list, portal scoped)
curl -s -X POST $V/v1/sys/policy/eso -H "X-Vault-Token: $ROOT" --data-binary @- <<'EOF'
{"policy": "path \"kv/data/*\" { capabilities = [\"read\"] }\npath \"kv/metadata/*\" { capabilities = [\"read\",\"list\"] }"}
EOF
curl -s -X POST $V/v1/sys/policy/portal -H "X-Vault-Token: $ROOT" --data-binary @- <<'EOF'
{"policy": "path \"kv/data/lumen/staging\" { capabilities = [\"read\",\"list\",\"create\",\"update\",\"patch\"] }\npath \"kv/data/lumen/production\" { capabilities = [\"read\",\"list\",\"create\",\"update\",\"patch\"] }\npath \"kv/data/*/staging\" { capabilities = [\"read\",\"list\"] }\npath \"kv/data/*/production\" { capabilities = [\"read\",\"list\"] }\npath \"kv/data/*/shared\" { capabilities = [\"read\",\"list\"] }\npath \"kv/metadata/*\" { capabilities = [\"read\",\"list\"] }"}
EOF

# 5. ROLES — secret_id_num_uses 0 BEFORE minting (§3.4's bomb)
curl -s -X POST $V/v1/auth/approle/role/eso -H "X-Vault-Token: $ROOT" \
  -d '{"token_policies":["eso"],"token_ttl":"1h","token_type":"service","secret_id_num_uses":0}'
curl -s -X POST $V/v1/auth/approle/role/portal -H "X-Vault-Token: $ROOT" \
  -d '{"token_policies":["portal"],"token_ttl":"1h","token_type":"service","secret_id_num_uses":0}'

# 6. PAIRS + PROOF (then kubectl create secret … as in §3.5)
ESO_RID=$(curl -s $V/v1/auth/approle/role/eso/role-id  -H "X-Vault-Token: $ROOT" | jq -r .data.role_id)
ESO_SID=$(curl -s -X POST $V/v1/auth/approle/role/eso/secret-id -H "X-Vault-Token: $ROOT" | jq -r .data.secret_id)
curl -s -X POST $V/v1/auth/approle/login -d "{\"role_id\":\"$ESO_RID\",\"secret_id\":\"$ESO_SID\"}" \
  | jq -r .auth.client_token | head -c 8 && echo   # a token prefix prints = alive
```

The seed step (§6) in variant-B form, for one path:

```bash
curl -s -X POST $V/v1/kv/data/lumen/staging -H "X-Vault-Token: $ROOT" \
  -d '{"data": {"LUMEN_DB_URL": "…", "LUMEN_MEILI_URL": "…", "…": "…"}}'
```

## 5. Harvest-then-seed — the DB passwords come OUT before they go IN

Order trap: Patroni (the Zalando operator, ch. 04 §2) **generates** the DB
user passwords itself at cluster creation. The vault seeds *from* them, not
the other way around. The foundation `lumen-db` overlay declares ONE
Patroni cluster (`lumen-pg`, ns `db`) with **THREE logical databases +
owner users** in `bases/lumen-db/postgresql.yaml`:

| database | owner user | consumer | vault path holding the DSN |
| :-- | :-- | :-- | :-- |
| `lumen_admin` | `db_user_admin` | foundation `lumen-admin` (the Control Plane — the ONLY users table) | `kv/lumen/shared` |
| `lumen_staging` | `db_user_staging` | `environments/staging/lumen` (cms) | `kv/lumen/staging` |
| `lumen_production` | `db_user_production` | `environments/production/lumen` (cms) | `kv/lumen/production` |

The operator publishes each credential as a k8s Secret with its dotted
naming — `<cluster>.<user>.credentials.postgresql.acid.zalan.do` (the
operator's own convention, echoed in `bases/lumen-db/postgresql.yaml`:
`lumen-pg.db_user_admin`; if a secret name ever surprises you, list
first: `kubectl -n db get secret -o name | grep db_user`):

```bash
ADMIN_DB_PW=$(kubectl -n db get secret \
  'lumen-pg.db_user_admin.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
STAGING_DB_PW=$(kubectl -n db get secret \
  'lumen-pg.db_user_staging.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
PROD_DB_PW=$(kubectl -n db get secret \
  'lumen-pg.db_user_production.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
```

Only now do you have everything worth seeding. ✅ pre-flight: all three
commands printed non-empty strings, and `kubectl -n db get pods` shows
`lumen-pg-0` Running (foundation wave 1 did its job).

> **Why three databases and one engine, and why the split is structural:**
> one Patroni is one backup story, one failover story, one $/RAM line. The
> role-split migration sets (lumen `store.MigrateForRole`: `users` ships
> ONLY in the admin set — `0002_admin_users.sql`/`0007_users_roles.sql` are
> PlaneAdmin files) make it **structurally impossible** for a cms DB to grow
> its own users table and diverge from the Control Plane. Sessions mint in
> exactly ONE place; the cms planes introspect (`§6.1`).

## 6. Seed the values — the CRs are the contract, path by path

Every key below exists because an ExternalSecret declares it —
**1:1, property == secretKey, no translations.** For lumen the truth is
machine-readable: `lumen config keys --role admin|cms`. Generate fresh
values on the spot (`openssl rand -hex 16|32`); reuse nothing from the
rehearsal. The paths are what the store mounts: `remoteRef: { key:
lumen/staging }` + the `bao` store's `path: kv` =
`kv/data/lumen/staging` (see `bases/secrets-plane/
clustersecretstore.yaml`).

**Seed order: `shared` first** (lumen-admin boots with foundation wave 2,
before either env hub), then staging, then production.

### 6.1 `kv/lumen/shared` — the Control Plane's identity (3 keys)

| kv path | Keys | Declared by |
|---|---|---|
| `kv/lumen/shared` | `LUMEN_DB_URL` `LUMEN_SESSION_JWT_SECRET` `LUMEN_ADMIN_URL` | `environments/foundation/lumen/externalsecret.yaml` (first two; the admin ES binds exactly what role=admin reads) + the two cms ESes read `LUMEN_ADMIN_URL` FROM this path |

```bash
X "export VAULT_TOKEN=$ROOT; bao kv put kv/lumen/shared \
  LUMEN_DB_URL=postgres://db_user_admin:$ADMIN_DB_PW@lumen-pg.db.svc:5432/lumen_admin \
  LUMEN_SESSION_JWT_SECRET=$(openssl rand -hex 32) \
  LUMEN_ADMIN_URL=http://lumen-admin.lumen.svc.cluster.local"
```

> **`LUMEN_SESSION_JWT_SECRET` has exactly ONE home:** this path. The admin
> plane signs, only the admin plane verifies with the key; the cms planes
> hold no signing key and no users table — they ask the Control Plane
> `POST /admin/session/verify` (verdicts cached 30 s keyed by the token's
> SHA-256, so revocation propagates in ≤30 s; admin unreachable = **fail
> closed, 503** — a down Control Plane must never degrade into "probably
> still valid"). `LUMEN_ADMIN_URL` is seeded here because a service URL is
> a VALUE (the `LUMEN_MEILI_URL` precedent) — and it must name the UNSUFFIXED
> Service `lumen-admin` (foundation owns it; the Naming contract guarantees
> the name).

### 6.2 `kv/lumen/{staging,production}` — each cms plane (13 keys, identical shape)

| kv path | Keys | Declared by |
|---|---|---|
| `kv/lumen/staging` | `LUMEN_DB_URL` `LUMEN_MEILI_URL` `LUMEN_MEILI_KEY` `LUMEN_MEILI_INDEX_POSTS` `LUMEN_MEILI_INDEX_PHOTOS` `LUMEN_MEDIA_ENDPOINT` `LUMEN_MEDIA_REGION` `LUMEN_MEDIA_BUCKET` `LUMEN_MEDIA_ACCESS_KEY` `LUMEN_MEDIA_SECRET_KEY` `LUMEN_MEDIA_CDN_BASE` `LUMEN_MEDIA_FORCE_PATH` `LUMEN_MEDIA_PREFIX` | `environments/staging/lumen/externalsecret.yaml` (plus `LUMEN_ADMIN_URL` sourced from `lumen/shared`) |
| `kv/lumen/production` | the same 13 keys with production values | `environments/production/lumen/externalsecret.yaml` |

```bash
# STAGING — note the THREE collapse-preventors: distinct DB, distinct index
# names, distinct media prefix. The in-code index defaults (posts/photos)
# belong to PRODUCTION; staging MUST use distinct names (posts-staging /
# photos-staging) — sharing an index is exactly the failure these keys
# exist to prevent.
X "export VAULT_TOKEN=$ROOT; bao kv put kv/lumen/staging \
  LUMEN_DB_URL=postgres://db_user_staging:$STAGING_DB_PW@lumen-pg.db.svc:5432/lumen_staging \
  LUMEN_MEILI_URL=http://meilisearch.search.svc.cluster.local:7700 \
  LUMEN_MEILI_KEY=$MEILI_KEY \
  LUMEN_MEILI_INDEX_POSTS=posts-staging LUMEN_MEILI_INDEX_PHOTOS=photos-staging \
  LUMEN_MEDIA_ENDPOINT=https://<account-hash>.r2.cloudflarestorage.com \
  LUMEN_MEDIA_REGION=r2 LUMEN_MEDIA_BUCKET=omicron-media \
  LUMEN_MEDIA_ACCESS_KEY=<R2 token> LUMEN_MEDIA_SECRET_KEY=<R2 token> \
  LUMEN_MEDIA_CDN_BASE=https://img.gofar.id LUMEN_MEDIA_FORCE_PATH=false \
  LUMEN_MEDIA_PREFIX=staging/"

# PRODUCTION — the same shape, production's values.
X "export VAULT_TOKEN=$ROOT; bao kv put kv/lumen/production \
  LUMEN_DB_URL=postgres://db_user_production:$PROD_DB_PW@lumen-pg.db.svc:5432/lumen_production \
  LUMEN_MEILI_URL=http://meilisearch.search.svc.cluster.local:7700 \
  LUMEN_MEILI_KEY=$MEILI_KEY \
  LUMEN_MEILI_INDEX_POSTS=posts LUMEN_MEILI_INDEX_PHOTOS=photos \
  LUMEN_MEDIA_ENDPOINT=https://<account-hash>.r2.cloudflarestorage.com \
  LUMEN_MEDIA_REGION=r2 LUMEN_MEDIA_BUCKET=omicron-media \
  LUMEN_MEDIA_ACCESS_KEY=<R2 token> LUMEN_MEDIA_SECRET_KEY=<R2 token> \
  LUMEN_MEDIA_CDN_BASE=https://img.gofar.id LUMEN_MEDIA_FORCE_PATH=false \
  LUMEN_MEDIA_PREFIX=production/"
```

> **Media on one bucket is a choice, printed honestly:** both envs share
> `omicron-media` (and may share `img.gofar.id` as the CDN face); the
> `LUMEN_MEDIA_PREFIX` values (`staging/` | `production/`, never empty) are
> what keep their objects apart. Seeding a different `LUMEN_MEDIA_BUCKET`
> for staging is the pre-documented escape hatch if the bucket split ever
> earns its keep.

### 6.3 `kv/earendil/{staging,production}` — the readers (2 keys each)

| kv path | Keys | Declared by |
|---|---|---|
| `kv/earendil/staging` | `API_BASE` `ORIGIN` | `environments/staging/earendil/externalsecret.yaml` |
| `kv/earendil/production` | `API_BASE` `ORIGIN` | `environments/production/earendil/externalsecret.yaml` |

```bash
# THE VALUES MUST NAME THE SUFFIXED SERVICES (the Naming contract):
# nameSuffix never rewrites spec fields, so what the manifest guarantees is
# that lumen-http-server-staging EXISTS — and what you seed is the string.
X "export VAULT_TOKEN=$ROOT; bao kv put kv/earendil/staging \
  API_BASE=http://lumen-http-server-staging.lumen.svc.cluster.local \
  ORIGIN=https://staging.gofar.id"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/earendil/production \
  API_BASE=http://lumen-http-server-production.lumen.svc.cluster.local \
  ORIGIN=https://gofar.id"
```

(`ORIGIN` returned with its reader — earendil reads it for the JSON-LD and
anything origin-anchored; staging's pod must speak STAGING.)

### 6.4 `kv/mellon/shared` + `kv/mellon/{staging,production}` — the dual-upstream portal

| kv path | Keys | Declared by |
|---|---|---|
| `kv/mellon/shared` | `ADMIN_URL` | both mellon ESes (`remoteRef key: mellon/shared`) |
| `kv/mellon/staging` | `CMS_URL` (+ `API_BASE` — transitional) | `environments/staging/mellon/externalsecret.yaml` |
| `kv/mellon/production` | `CMS_URL` (+ `API_BASE` — transitional) | `environments/production/mellon/externalsecret.yaml` |

```bash
X "export VAULT_TOKEN=$ROOT; bao kv put kv/mellon/shared \
  ADMIN_URL=http://lumen-admin.lumen.svc.cluster.local"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/mellon/staging \
  CMS_URL=http://lumen-http-server-staging.lumen.svc.cluster.local \
  API_BASE=http://lumen-http-server-staging.lumen.svc.cluster.local"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/mellon/production \
  CMS_URL=http://lumen-http-server-production.lumen.svc.cluster.local \
  API_BASE=http://lumen-http-server-production.lumen.svc.cluster.local"
```

> **Mirror the routing table, never out-guess it:** mellon's
> `src/lib/api/routing.ts` is the auditable answer to "which lumen gets
> this call?" — `/admin/session|users|setup|bao` → `ADMIN_URL`;
> `/admin/posts|photos|tags|collections|media|search` + `/api` →
> `CMS_URL`; unknown paths throw (no default upstream). `API_BASE` is the
> legacy single-upstream key kept TRANSITIONALLY for v1.1.0 pods — drop it
> by human PR once the dual-upstream image is all that deploys.

### 6.5 Foundation singletons

| kv path | Keys | Declared by |
|---|---|---|
| `kv/grafana/production` | `GF_SERVER_ROOT_URL` `GF_SECURITY_ADMIN_PASSWORD` `GF_AUTH_GENERIC_OAUTH_CLIENT_ID` `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` | `bases/observability/externalsecret.yaml` (rendered by the FOUNDATION overlay — the one Grafana door serves BOTH envs) |
| `kv/cert-manager/production` | `CF_API_TOKEN` | `bases/certificates/externalsecret.yaml` |
| `kv/meilisearch/production` | `MASTER_KEY` (mirror — see note) | *(no ES yet — note below)* |

```bash
X "export VAULT_TOKEN=$ROOT; bao kv put kv/cert-manager/production CF_API_TOKEN=<scoped DNS-Edit token — minted in ch. 07>"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/meilisearch/production MASTER_KEY=$MEILI_KEY"
# grafana's four keys land here too — but GF_AUTH_GENERIC_OAUTH_* don't
# exist until Cloudflare Access hands you the OIDC app (ch. 07); seed
# GF_SERVER_ROOT_URL + a generated GF_SECURITY_ADMIN_PASSWORD now, re-put
# the path WITH all keys once Access exists (a put replaces — never
# half-list). The door itself (Grafana at anor.gofar.id) wakes in ch. 07.
```

> ⚠️ **`bao kv put` REPLACES the whole path's map** (incident: a mid-list
> failure stripped the rest). **One invocation per path, listing every key**
> — then VERIFY by diffing the key set against the CR's `data:` list,
> key-by-key: `bao kv get -format=json kv/lumen/staging`. **Never**
> `bao kv delete` casually. The CI driftcheck does the same diff from the
> Git side, so a mismatch you missed here becomes a red pipeline later.
> (CLI writes with the root token are the operator's break-glass — the
> 403 pin-lock (§7.1) guards the relay, not the mount; disagreement is
> what driftcheck's amber and the config-gate are for.)

> **Meilisearch's special case:** its Deployment reads
> `search/meilisearch-master-key` (key `master-key`,
> `bases/meilisearch/deployment.yaml`) — and **no ExternalSecret
> renders that Secret yet** (the manifest comment says "eventually via
> ExternalSecret/OpenBao"; today it's `optional: true` so the pod can boot
> unkeyed, which production must not do). So: pick ONE `$MEILI_KEY` (the
> same one every cms path gets as `LUMEN_MEILI_KEY` — the engine is shared,
> the INDEXES are the per-env separation), create the k8s Secret by hand
> (`kubectl -n search create secret generic meilisearch-master-key --from-literal=master-key=$MEILI_KEY`),
> AND mirror it into `kv/meilisearch/production` so it shows in the matrix
> (§7) and rides vault backups. When its ES lands, the hand Secret retires.

## 7. Portal doctrine: seeded right == visible to operators (one fact)

Everything you seed under `kv/<app>/<env>` (shared included — it is just
another leaf) shows up in **mellon's matrix/Vault card automatically**:
lumen-admin's relay enumerates `kv/metadata` (`ListPaths`,
`lumen/internal/bao/bao.go`) and mellon derives its rows from that
(`GET /admin/bao/paths` → the configs/vault page — and note the ROUTING:
`/admin/bao*` rides `ADMIN_URL` per §6.4's table). You never register a
path in two places — which means the flip side is a *check*, not a chore:

> **Conformance check:** once §6 is done, the portal matrix must show rows
> for **lumen/{shared,staging,production}**, **earendil** + **mellon** per
> env, **grafana** and **cert-manager** — exactly what §6 seeded. A missing
> row = an off-contract seed (wrong path spelling), fixed in the vault,
> never by adding a row to code.
> **OPEN:** the wizard's env picker still proposes `dev` (see §3.3's flag) —
> don't let it talk you into seeding paths nobody renders.

The only things invisible to the portal are precisely the hand-made
bootstrap-paradox Secrets (§3.5, the k8s Secret `meilisearch-master-key`,
and the Patroni-generated DB credentials — Git's CRs don't read those, the
apps hold them as k8s Secrets). That's the correct shape: the portal can't
show the keys that unlock the portal's own plumbing. The rehearsal-era
recovery Secret `lumen-admin-password` (archived RUNBOOK.md) follows the
same rule — offline note, not vault row.

### 7.1 The pin is a LOCK, not a label (owner ruling 2026-11-13, block mode)

Every versioned path carries an optional pin — Bao `custom_metadata`'s
`pinned_version`, toggled from mellon's Vault drawer. The semantics are
**block mode**: while a path is pinned, lumen's relay refuses every write
to it — **HTTP 403**, body `{"error":"pinned at v<N> — unpin first"}` —
and the portal renders that copy verbatim, end to end (the browser client
once rendered only 409s cleanly; fixed the same day the lock shipped).
Reads are never affected: **head keeps serving** — the lock stops writes,
not traffic. The ritual for changing config under a pin, in order:

1. **unpin** — release the lock; the 403 was the feature telling you it held;
2. **restore-draft** — Restore on the pinned version overlays its values
   onto the CURRENT key set in the editor; a refused save keeps the dirty
   editor, so nothing is retyped under fire;
3. **save as vN** — head moves; the frozen pin number does NOT move with it;
4. the portal then offers **"pin vN?"** — for restore-seeded saves only,
   so the lock re-lands exactly on the content you just released.

Downstream, the disagreement has its own alarm, and none of it is silent:
`driftcheck` prints a pinned-below-head path amber
(`pinned v2, head v3 (held intent)`) — intent vs content, the *disagreement
alarm*, not a failure — and the PreSync config-gate (ch. 06 §4) refuses to
sync against a mismatch until you align it. The whole contract in one line:
**pin = lock, head = truth, restore = the only road back, gate = where you
can't lie.**

## 8. Make the robots notice (materialize timing)

ExternalSecrets created *before* the seed sit "Ready=false, next refresh in
~1h". Don't wait:

```bash
kubectl delete externalsecret -n <ns> <name>   # for each ES — Argo selfHeal
                                               # recreates it, fresh objects sync NOW
kubectl rollout restart deploy/...             # every consumer pod: envFrom
                                               # binds ONLY at container start
```

✅ end state: all rendered ES `Synced=True`; `kubectl -n external-secrets
get clustersecretstore bao` → Ready; foundation wave 2 (lumen-admin +
observability) has rolled in the store's wake. **Only now are the env-hub
applies safe** — `kubectl apply -f bootstrap/apps-hub-production.yaml`
(and/or `bootstrap/apps-hub-staging.yaml`) — ch. 04 §3's entry order — and
the application planes sync onto real values at their very first render.
Chapter 06 picks the story up there.

## 9. Day-2 rituals (in the Operations calendar because they bite)

- **After EVERY bao pod restart (host reboots included):** the vault returns
  **SEALED** (data survives, seal state doesn't). Unseal ritual: any **two**
  keys ×2 (`X "bao operator unseal <key-from-offline>"`, or variant B's two
  curls) → everything reconciles within ~a minute; bounce the ESO controller
  (`kubectl -n external-secrets rollout restart deploy/external-secrets`) to
  skip its error backoff. All-ES-red = sealed-vault signature; trust
  `describe`'s *Last Transition Time* to date the incident, not `get`'s
  misleading "last sync". (The pod's liveness probe deliberately ignores
  seal state — see the war comment in `bases/openbao/openbao.yaml` —
  so the pod being alive *while sealed* is you being able to exec the
  unseal into it.)
- **Rotation:** values change in Bao → ES re-renders on refresh (1h) → pods
  that read env at boot need `rollout restart` (selfHeal never reverts what
  it doesn't track). A rotation into a **pinned** path is refused first —
  that's §7.1's lock doing its job; unpin to rotate, re-pin after. Rotate
  the shared signing key ONCE at `kv/lumen/shared` and BOTH cms planes
  start rejecting old tokens within their 30 s cache window — expect
  re-logins, that is revocation working.
- **Save refused with 403 `pinned at v<N> — unpin first`:** not an outage,
  the lock (§7.1). The remedy is three verbs: **unpin → act → re-pin**
  (unpin, restore-draft the version you mean or type the change, save as
  vN, answer the portal's "pin vN?" offer). Readers never felt anything —
  head kept serving the whole time.
- **Vault reborn (lost unseal keys):** it happens. Destroy pod + PVC **and
  the node directory** (`/var/lib/rancher/k3s/storage/<ns>_openbao-…` —
  Retain + PV deletion does NOT wipe it; this trap bit twice in rehearsal,
  bao and meili), re-init §3, re-seed §6, re-issue the §3.5 pairs.
  Everything else in the estate rebuilds from Git + backups.

Next → [06 · Apps Land & First Release](06-apps-first-release.md)
