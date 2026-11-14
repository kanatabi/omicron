---
tags: [runbook, secrets, vault]
updated: 2026-11-14
status: >-
  ritual incident-proven (rehearsal walk + two unseal drills); the
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
**The variant contract, in one line:** variant A **never** needs a
port-forward (the CLI runs in the pod); variant B's port-forward is §4's
first command — start it before any §4 command, keep that tab alive, and
re-establish it after every vault restart (§9's unseal ritual includes
the step). You never install a `bao` CLI on the laptop in either variant.

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
    V-->>L: keys + root token land in $HOME/bao-init.json<br/>(the machine running kubectl — laptop on Track A, VPS on Track B)
    L->>L: copy it to the laptop → password manager + paper, two spots<br/>(BEFORE deleting the working copy!)
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
X 'bao operator init -key-shares=3 -key-threshold=2 -format=json' > "$HOME/bao-init.json"
chmod 600 "$HOME/bao-init.json"
```

> **Where this file lives:** the redirect runs on **the machine where you
> run `kubectl`** — your laptop on Track A, the VPS (as `ops`) on Track B.
> `$HOME` is correct in both; a literal `/root/…` would fail for `ops` and
> is a leftover from the root-session era. Everything below (§3.2, §3.3)
> reads the same `$HOME` path, so stay in this one shell.

> **Why 3 shares / threshold 2:** any single paper is worthless alone,
> **any two of the three open it**. One paper on one server = one fire =
> one loss (the rehearsal used 1/1 to stay simple; production deserves the
> better math). Losing all unseal keys = losing every value in the estate —
> INFRA §5.6 says so, and there is no support ticket that fixes it.

**The extraction step — do NOT skip, in this order:**

```bash
# If you ran init ON THE LAPTOP: the file is already here — skip to the copy.
# If you ran init ON THE VPS (Track B), pull it from your laptop first:
scp ops@<server>:bao-init.json ~/Desktop/   # (relative path = ops's $HOME)
# THEN — either machine — straight into your password manager AND/OR
# paper, in two physical spots
```

> **The backup bucket never holds unseal keys — that's what "offline"
> means.** Restic ships this server's disks to R2 (ch. on backups); if the
> keys lived in a root file they'd ride that bucket, and anyone with the one
> backup credential could open the vault that guards the other ones. The
> keys' only homes: your laptop's transfer copy, then offline storage.
> **Delete `$HOME/bao-init.json` ONLY after the offline copies exist** —
> and remember which two of the three keys you kept; any pair works, the
> third is spare.

### 3.2 Unseal (twice)

```bash
INIT="$HOME/bao-init.json"   # set once; §3.3 reuses it
X "bao operator unseal $(python3 -c "import json;print(json.load(open('$INIT'))['unseal_keys_b64'][0])")"
X "bao operator unseal $(python3 -c "import json;print(json.load(open('$INIT'))['unseal_keys_b64'][1])")"
# → "Sealed: false" on the second call. NOW delete the init file (after the offline copies exist — §3.1's box).
```

> **Non-tty lesson (incident-proven):** piping a key into `unseal` on stdin
> fails ("file descriptor 0 is not a terminal") — pass the key as the
> **argument**, as above. Same class of extraction hygiene: pull values with
> `python3`/`jq` — **never `cut -d=`**: base64 keys contain `=` padding and
> `cut` silently truncates them into uselessness (learned twice).

### 3.3 Mounts, auth, policies

```bash
ROOT=$(python3 -c "import json;print(json.load(open('$INIT'))['root_token'])")
X "export VAULT_TOKEN=$ROOT; bao secrets enable -path=kv kv-v2"   # the values store
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

> **Why `secrets enable -path=kv kv-v2` (and not some `kv enable` form):**
> there is no `bao kv enable` subcommand — the mount itself is what makes
> the store version 2, and this is the same call variant B makes via
> `POST /v1/sys/mounts/kv`. If it answers `path is already in use`, the
> mount exists from an earlier attempt — check it IS v2
> (`X "bao secrets list -detailed"` shows the kv mount's options with
> `version:2`) and move on.

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

**The PORTAL pair — the doc's old version skipped it with one comment line,
and the estate stopped until it existed (walked 2026-11-14):** the
config-gate Job (PreSync) of EVERY gated app + `lumen-admin` authenticate
to Bao with it; without the Secret below, every gate exits 2
"plane unreachable" and its app's sync fails — `admin-secrets` and
`deploy/lumen-admin` are never born. NOTE the binding difference: these
consumers read it via **`envFrom`**, so the keys ARE the env names — three
keys, not the ESO pair's `role-id`/`secret-id`:

```bash
# 1. mint the PORTAL pair (the portal role from §3.4):
PORTAL_RID=$(X "export VAULT_TOKEN=$ROOT; bao read -format=json -field=role_id auth/approle/role/portal/role-id" | tr -d '\r\n\" ')
PORTAL_SID=$(X "export VAULT_TOKEN=$ROOT; bao write -force -format=json -field=secret_id auth/approle/role/portal/secret-id" | tr -d '\r\n\" ')
# 2. the paradox Secret — envFrom maps key names 1:1 to env names:
kubectl -n lumen create secret generic lumen-bao-credentials \
  --from-literal=LUMEN_BAO_ADDR=http://bao.secrets.svc.cluster.local:8200 \
  --from-literal=LUMEN_BAO_ROLE_ID=$PORTAL_RID \
  --from-literal=LUMEN_BAO_SECRET_ID=$PORTAL_SID
# 3. prove the pair (same dummy-token trick):
X "export VAULT_TOKEN=dummy; bao write -format=json -field=token auth/approle/login role_id=$PORTAL_RID secret_id=$PORTAL_SID"
```

**EVERY namespace that hosts a gated app needs a copy** (same values — one
portal pair serves the estate): `lumen` now, and `earendil` + `mellon`
BEFORE the env hubs apply (§8) — their PreSync gates run there:

```bash
for ns in earendil mellon; do
  kubectl -n "$ns" create secret generic lumen-bao-credentials \
    --from-literal=LUMEN_BAO_ADDR=http://bao.secrets.svc.cluster.local:8200 \
    --from-literal=LUMEN_BAO_ROLE_ID=$PORTAL_RID \
    --from-literal=LUMEN_BAO_SECRET_ID=$PORTAL_SID
done
```

✅ **check the store noticed** — run it as an ordered check, not a single
glance (walk-proven 2026-11-14: the naive `get` alone confuses — the
store can sit `InvalidProviderConfig` for minutes for perfectly
explained reasons):

```bash
# 1. the credentials Secret exists with exactly the two keys:
kubectl -n external-secrets get secret bao-approle-credentials \
  -o jsonpath='{.data}' | python3 -m json.tool    # keys: role-id, secret-id
# 2. the login proof above returned a token (the pair is alive)
# 3. KICK the ESO controller — its FIRST validation of this store ran while
#    the vault was still SEALED and the creds Secret did not exist yet; that
#    failed verdict is cached with an error backoff, and without a kick
#    `Ready` can lag by many minutes:
kubectl -n external-secrets rollout restart deploy/external-secrets
# ~30s later:
kubectl -n external-secrets get clustersecretstore bao   # → READY: True
```

> **Reading the status, honestly:** `InvalidProviderConfig` at this stage
> is the *expected pre-conditions state* (sealed vault / creds not yet
> created at first validation) — the backoff talking, not a broken spec.
> If it survives the kick, `kubectl describe clustersecretstore bao`'s
> events name the real cause: auth denied = the pair in the Secret is
> wrong (re-mint block 1 above); connection refused = store/server check.

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

**Pre-flight FIRST — nothing to harvest until it's true** (a NotFound on
the reads below means "not bootstrapped yet", not "wrong name"; do NOT
seed past an empty variable — that seeds an empty string, §6's guard
exists for this):

```bash
kubectl -n db get postgresql lumen-pg        # STATUS: Running (bootstrap pulls
                                             # the ~600 MB Spilo image — be patient)
kubectl -n default get pods -l name=postgres-operator   # Running
kubectl -n db get secret -o name | grep credentials     # the five naming below
```

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

The operator publishes each credential as a k8s Secret named
**`<user>.<cluster>.credentials.postgresql.acid.zalan.do`** — user FIRST —
and **hyphenates underscores in the k8s NAME only** (secret names are
DNS-1123; the PostgreSQL ROLE keeps its underscores — the operator's log
says `creating database "lumen_admin" owner "db_user_admin"`, and the
Secret's own `.data.username` proves it: `db_user_admin`). Five secrets
exist: the three estate ones below plus `postgres.…` (superuser) and
`standby.…` — neither is estate material. (Walk-verified 2026-11-14,
operator v2.0.3: names `db-user-admin.lumen-pg.…` etc., passwords
alphanumeric — DSN-safe, no percent-encoding.)

```bash
ADMIN_DB_PW=$(kubectl -n db get secret \
  'db-user-admin.lumen-pg.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
STAGING_DB_PW=$(kubectl -n db get secret \
  'db-user-staging.lumen-pg.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
PROD_DB_PW=$(kubectl -n db get secret \
  'db-user-production.lumen-pg.credentials.postgresql.acid.zalan.do' \
  -o jsonpath='{.data.password}' | base64 -d)
```

Only now do you have everything worth seeding. ✅ pre-flight: all three
commands printed non-empty strings.

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

**Variables this section depends on — check before the first `bao kv put`:**
every seed block writes what a shell variable *currently* holds; if your
terminal died since §3–§5, an empty variable seeds an **empty string**
(the worst failure: it renders, then misbehaves). Re-establish per the
table, then run the guard.

| Variable | Set in | What it must hold | Re-establish |
| :-- | :-- | :-- | :-- |
| `X()` (the exec wrapper) | §3 | the `kubectl exec` one-liner | re-run §3's block |
| `ROOT` | §3.3 | Bao root token | if the init file still exists: re-run §3.3's first line; else unseal ritual §9 + `bao login` |
| `ADMIN_DB_PW` `STAGING_DB_PW` `PROD_DB_PW` | §5 | the Patroni-generated passwords | re-run §5's three kubectl reads |
| `MEILI_KEY` | this § (below) | the shared search key | re-run this §'s `export MEILI_KEY=…` (it re-derives from the vault in §6.5's shape if you already seeded) |
| `R2_ACCOUNT_HASH` | ch.01 §2c (offline note) | the hex in your R2 endpoint URL (`https://<hash>.r2.cloudflarestorage.com`) — dashboard: R2 → account details | read it from your offline note |
| `R2_MEDIA_ACCESS_KEY` `R2_MEDIA_SECRET_KEY` | ch.01 §2c (offline note) | the media token pair (scoped to `omicron-media`) | read from your offline note |

```bash
# ⚠️ GENERATE the shared search key ONCE, here — §6.2 and §6.5 both use it.
# (If you already seeded and just need it back: skip the export and read it
# in §6.5's note — the vault holds it at kv/meilisearch/production.)
export MEILI_KEY=$(openssl rand -hex 32)
# paste-safe guard: WARN, don't exit — a dead terminal must not close itself.
# NO OUTPUT FROM THIS LOOP = all variables set (silence is the pass condition);
# a WARNING line names what to re-establish first.
for v in ROOT ADMIN_DB_PW STAGING_DB_PW PROD_DB_PW MEILI_KEY \
         R2_ACCOUNT_HASH R2_MEDIA_ACCESS_KEY R2_MEDIA_SECRET_KEY; do
  [ -n "${!v}" ] || echo "WARNING: \$$v is EMPTY — re-establish it (table above) BEFORE seeding"
done
```

> **The `<placeholder>` convention, and its one trap:** any `<…>` token in
> a command means **replace it by hand before running** — it is never
> literal. Inside an `X` block that matters twice over: pasted literally,
> the shell reads `<…>` as an I/O **redirection** (you get
> `sh: can't open <thing>: no such file`), never a placeholder error. So
> inside `X` blocks, values arrive as exported variables — the table
> above — never as pasted angle brackets.

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
  LUMEN_MEDIA_ENDPOINT=https://$R2_ACCOUNT_HASH.r2.cloudflarestorage.com \
  LUMEN_MEDIA_REGION=r2 LUMEN_MEDIA_BUCKET=omicron-media \
  LUMEN_MEDIA_ACCESS_KEY=$R2_MEDIA_ACCESS_KEY LUMEN_MEDIA_SECRET_KEY=$R2_MEDIA_SECRET_KEY \
  LUMEN_MEDIA_CDN_BASE=https://img.gofar.id LUMEN_MEDIA_FORCE_PATH=false \
  LUMEN_MEDIA_PREFIX=staging/"

# PRODUCTION — the same shape, production's values.
X "export VAULT_TOKEN=$ROOT; bao kv put kv/lumen/production \
  LUMEN_DB_URL=postgres://db_user_production:$PROD_DB_PW@lumen-pg.db.svc:5432/lumen_production \
  LUMEN_MEILI_URL=http://meilisearch.search.svc.cluster.local:7700 \
  LUMEN_MEILI_KEY=$MEILI_KEY \
  LUMEN_MEILI_INDEX_POSTS=posts LUMEN_MEILI_INDEX_PHOTOS=photos \
  LUMEN_MEDIA_ENDPOINT=https://$R2_ACCOUNT_HASH.r2.cloudflarestorage.com \
  LUMEN_MEDIA_REGION=r2 LUMEN_MEDIA_BUCKET=omicron-media \
  LUMEN_MEDIA_ACCESS_KEY=$R2_MEDIA_ACCESS_KEY LUMEN_MEDIA_SECRET_KEY=$R2_MEDIA_SECRET_KEY \
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
X "export VAULT_TOKEN=$ROOT; bao kv put kv/meilisearch/production MASTER_KEY=$MEILI_KEY"
# cert-manager's CF_API_TOKEN is NOT seedable here — the scoped token is
# minted in ch. 07 §3.2, which seeds this path itself. Skip until then.
```

**Grafana — the FOUR-KEY put.** Walked 2026-11-14: leaving this as
prose-only got a fresh cluster's sync op WEDGED (ch.12 card 11) — an
ExternalSecret errors on ANY missing declared key, so the interim state
needs all four, with placeholders for the OAuth pair until ch. 07's
Cloudflare Access hands you the real OIDC app. A put REPLACES the map —
when ch. 07 lands, re-put ALL FOUR keys:

```bash
GF_PW=$(openssl rand -base64 24)   # → password manager IMMEDIATELY
X "export VAULT_TOKEN=$ROOT; bao kv put kv/grafana/production \
   GF_SERVER_ROOT_URL=https://anor.gofar.id \
   GF_SECURITY_ADMIN_PASSWORD=$GF_PW \
   GF_AUTH_GENERIC_OAUTH_CLIENT_ID=PLACEHOLDER-UNTIL-CH07-CLOUDFLARE-ACCESS \
   GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=PLACEHOLDER-UNTIL-CH07-CLOUDFLARE-ACCESS"
# verify the key set, then force ESO's hand:
kubectl -n observability annotate externalsecret grafana-config \
  grafana-secrets reconcile.external-secrets.io/force="true" --overwrite
```

> **This gate precedes `bootstrap/apps-hub-observability.yaml`** (the
> 2026-11-14 hub split): the observability Application is applied BY HAND,
> only after (a) the foundation hub is green, (b) this four-key put is in,
> and (c) the two grafana ExternalSecrets show `Ready: True`. An ES errors
> on ANY missing declared key — apply first and its sync op wedges forever
> (ch.12 card 11).

> ⚠️ **The admin password binds ONLY at grafana's first boot** (the boot
> creates the admin user). Grafana has never booted before this gate →
> today's seed is the clean path. If grafana ALREADY booted (the harvest
> branch): the live admin is the default `admin/admin` — align it to the
> vault value with
> `kubectl -n observability exec deploy/grafana -- grafana cli admin reset-admin-password "$PW"`
> (`$PW` = the value read back from the vault).
> With OAuth placeholders the rendered config keeps
> `GF_AUTH_GENERIC_OAUTH_ENABLED=true` (manifest constant) → a **dead SSO
> button** on the login screen until ch. 07; the admin door is unaffected.

> ⚠️ **`bao kv put` REPLACES the whole path's map** (incident: a mid-list
> failure stripped the rest). **One invocation per path, listing every key**
> — then VERIFY by diffing the key set against the CR's `data:` list,
> key-by-key. **Never** `bao kv delete` casually. The CI driftcheck does
> the same diff from the Git side, so a mismatch you missed here becomes a
> red pipeline later. The verify itself, per variant:
>
> ```bash
> # variant A — runs in the pod, no port-forward (the token export is REQUIRED —
> # the X wrapper sets only VAULT_ADDR; token-less reads 403):
> X "export VAULT_TOKEN=$ROOT; bao kv get -format=json kv/lumen/staging"
> # variant B — through the §4 port-forward:
> curl -s -H "X-Vault-Token: $ROOT" $V/v1/kv/data/lumen/staging | jq '.data.data | keys'
> ```
>
> (CLI writes with the root token are the operator's break-glass — the
> 403 pin-lock (§7.1) guards the relay, not the mount; disagreement is
> what driftcheck's amber and the config-gate are for.)

> **Meilisearch's special case:** its Deployment reads
> `search/meilisearch-master-key` (key `master-key`,
> `bases/meilisearch/deployment.yaml`) — and **no ExternalSecret
> renders that Secret yet** (the manifest comment says "eventually via
> ExternalSecret/OpenBao"; today it's `optional: true` so the pod can boot
> unkeyed, which production must not do). It's a bootstrap-paradox family
> member: hand-made once, below. Use the ONE `$MEILI_KEY` from §6's
> preamble (the same one every cms path gets as `LUMEN_MEILI_KEY` — the
> engine is shared, the INDEXES are the per-env separation):
>
> ```bash
> # 1. the hand Secret (dry-run form = safe to re-run; the value binds at
> #    container start, so the pod needs the restart in step 3):
> kubectl -n search create secret generic meilisearch-master-key \
>   --from-literal=master-key=$MEILI_KEY \
>   --dry-run=client -o yaml | kubectl apply -f -
> # 2. mirror into the vault (matrix row §7 + rides vault backups):
> X "export VAULT_TOKEN=$ROOT; bao kv put kv/meilisearch/production MASTER_KEY=$MEILI_KEY"
> # 3. make the pod bind OUR key:
> kubectl -n search rollout restart deploy/meilisearch
> ```
>
> ✅ check: the pod log **no longer** contains the "a master key has been
> generated" line.
>
> **Why the pod-generated key is NEVER the key:** a "master key has been
> generated" line in the pod log is the unkeyed-boot state talking — a
> random value minted at boot, printed to stdout, gone at the next
> restart. It can't serve this estate because **two parties must know
> this key**: the meili pod presents it (`MEILI_MASTER_KEY`) AND lumen
> presents it (`LUMEN_MEILI_KEY`, read from the vault at lumen's
> container start). Bao holds owned, versioned values — not log-scraped
> ones. Generate once (§6 preamble), distribute to both ends. When
> meili's ES lands, the hand Secret retires.

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
~1h". Don't wait. **Enumerate FIRST — the list tells you which case each
ES is in** (walked 2026-11-14):

```bash
kubectl get externalsecret -A --no-headers | awk '{print $1, $2}'
```

**Case A — an ES that exists** (walked: `grafana-config`,
`grafana-secrets` in `observability`): delete it — Argo selfHeal recreates
it, and the fresh object syncs NOW (the old one was created pre-seed and
errors with backoff). Then restart its consumer (`envFrom` binds ONLY at
container start):

```bash
kubectl -n observability delete externalsecret grafana-config
kubectl -n observability delete externalsecret grafana-secrets
kubectl -n observability rollout restart deploy/grafana
```

**Case B — an expected ES is MISSING from the list** (walked:
`admin-secrets` in `lumen`): its Argo Application never synced — its
config-gate PreSync Job failed during the sealed-vault era and Argo
exhausted its retries. Kick a fresh sync operation (the refresh annotation
alone won't do it after a Failed op — use the Argo UI's Sync button, or the
annotate + sync):

```bash
kubectl -n argocd annotate application lumen-admin argocd.argoproj.io/refresh=normal --overwrite
```

The gate re-runs against the now-seeded vault (`--declared 0` = not yet
under contract: passes iff no pin) and the sync is born post-seed — **it
syncs on creation; NO delete, NO restart needed**. Verify:

```bash
kubectl -n lumen get externalsecret,deploy,secret
```

> **Fresh-cluster note (walked):** the gate's first run needs two hand-made
> things this chapter provides — the `lumen-bao-credentials` Secret (§3.5)
> and, pre-pin-fix, the `config-gate` ServiceAccount (created by the sync
> phase that the hook itself was blocking — `kubectl -n lumen create
> serviceaccount config-gate` once, then re-sync; the vortex fix adding
> hook-wave annotations to the component's RBAC retires this).
>
> **The resource-level ordering contract (vortex, post-fix):** inside every
> gated app the sync-waves are ES **0** → migrate **1** → Deployments **2**
> — a workload that `envFrom`-binds an ES-rendered Secret can never boot
> dark (it reads env only at container start), and a migrate always finds
> its Secret. The PreSync config-gate stays a hook: it needs only the
> hand-made credentials, never a rendered Secret.
>
> **Job immutability on bump day (walked 2026-11-14):** the migrate Job is a
> wave-1 sync-phase resource, and Kubernetes Job pod templates are
> IMMUTABLE — the v4.0.1 bump could not patch the completed v3.0.0
> `lumen-admin-migrate` (`spec.template … field is immutable`, retried
> until exhausted; the corpse blocks wave 2 behind it). Two walked
> corrections:
>
> - **`Replace=true` does NOT fix this** (walked, then reverted-in-effect):
>   Argo's `argocd.argoproj.io/sync-options: Replace=true` is `kubectl
>   replace` — a PUT — and a PUT is bound by the same immutability
>   (`error when replacing … field is immutable`). It is not
>   delete-and-recreate.
> - **`ttlSecondsAfterFinished` on a git-managed Job is a graveyard
>   cycle**: complete → TTL deletes the Job → Argo sees Missing →
>   selfHeal recreates → migrate re-runs — every ~10 min, forever
>   (idempotent, so it stays green, but it re-ran twice in an hour,
>   walked live).
>
> Remedies, in order of landing: (1) clear the stale state —
> `kubectl -n lumen delete job lumen-admin-migrate --ignore-not-found`
> (or nothing at all if the cluster Job already matches) then one Sync;
> an identical-spec apply is a no-op. (2) The SA-round design: a janitor
> PreSync hook (`kubectl delete job <name> --ignore-not-found` — runs
> BEFORE the sync-phase apply, needs no secrets, no-ops on fresh
> clusters) plus TTL removed from the git-managed Jobs: bump days
> become deterministic corpse-removal, no red window, no eternal
> re-runs.

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
  keys, passed as ARGUMENTS from your offline note (`export
  UNSEAL_KEY_1=<…>; X "bao operator unseal $UNSEAL_KEY_1"`, then the second
  key — never `< key` stdin form: that's both the placeholder-redirection
  trap AND §3.2's non-tty failure; or variant B's two curls) → everything
  reconciles within ~a minute; bounce the ESO controller
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
