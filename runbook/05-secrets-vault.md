---
tags: [runbook, secrets]
updated: 2026-11-13
status: rehearsed (minikube era + incident-proven unseal ritual); VPS = first real production seeding
---

# 05 · Secrets Vault — OpenBao + ESO: values live only here

> **Why a vault at all:** passwords in Git are forever public (even in
> private repos, forever in backups/logs/forks). The estate's rule is
> absolute: **Git holds templates, Bao holds values.** Anything that
> renders — a database, a CDN token, a search key — gets its value from
> the vault at boot, and the vault itself is the single place to
> concentrate your paranoia.

The manifests already exist (`vortex/applications/openbao|external-secrets`);
this chapter is the **manual bootstrap** they can't self-start (the vault
cannot unlock itself — the docs call this the bootstrap paradox).

## 1. The vault comes up with the hub (ch. 07), sealed

You'll see: `openbao-0` Running, ExternalSecrets red with
`could not get secret data from provider`. **That is the expected state** —
sealed vault = no values = red robots. It stops being scary at step 4.

## 2. Init — do it ONCE, carefully

```bash
X() { kubectl -n secrets exec -i deploy/openbao -- \
  sh -c "export VAULT_ADDR=http://127.0.0.1:8200; $1"; }   # the tls_disable quirk:
                                                            # bao defaults to https
X 'bao operator init -key-shares=3 -key-threshold=2 -format=json' > /root/bao-init.json
```

> **Why 3 shares / threshold 2:** any single paper is worthless alone, any
> two open it. One paper on one server = one fire = one loss (the rehearsal
> used 1/1 to stay simple; production deserves the better math). Copy the
> **two of the three unseal keys + the root token** OUT NOW to your offline
> place (password manager AND/OR paper in a different physical spot).
> Losing all unseal keys = losing every value in the estate — the DR doc
> says so in §5.6, and there is no support ticket that fixes it.
> Extraction hygiene (learned twice): pull values with
> `python3 -c "import json..."` or `sed 's/^...=//'` — **never**
> `cut -d= `, base64 keys contain `=` padding and `cut` silently
> truncates them into uselessness.

```bash
X "bao operator unseal $(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['unseal_keys_b64'][0])")"
X "bao operator unseal $(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['unseal_keys_b64'][1])")"
# Sealed → false. Delete /root/bao-init.json ONLY after keys are saved offline.
```

> **Non-tty lesson (incident-proven):** piping the key into `unseal` on
> stdin fails ("file descriptor 0 is not a terminal") — pass the key as the
> **argument** like above.

## 3. Mounts, policies, AppRoles

```bash
ROOT=$(python3 -c "import json;print(json.load(open('/root/bao-init.json'))['root_token'])")
X "export VAULT_TOKEN=$ROOT; bao kv enable version=2 kv"      # the values store
X "export VAULT_TOKEN=$ROOT; bao auth enable approle"          # machine logins

# ESO policy: READ/LIST only — the renderer must never write values.
X "export VAULT_TOKEN=$ROOT; bao policy write eso - <<'EOF'
path \"kv/data/*\"        { capabilities = [\"read\"] }
path \"kv/metadata/*\"    { capabilities = [\"read\", \"list\"] }
EOF"

# PORTAL policy: production is SCOPED per-app paths, not kv/* (INFRA §5.6 cap;
# the rehearsal's broad shape is not what ships).
X "export VAULT_TOKEN=$ROOT; bao policy write portal - <<'EOF'
path \"kv/data/lumen/production\"      { capabilities = [\"read\",\"list\",\"create\",\"update\",\"patch\"] }
path \"kv/data/*/production\"          { capabilities = [\"read\",\"list\"] }
path \"kv/metadata/*\"                 { capabilities = [\"read\",\"list\"] }
EOF"

# roles: secret_id_num_uses=0 BEFORE minting ids — the single-use default is
# a silent time-bomb (expires at the first 1-hour token refresh). Learned
# the hard way; the line that proves any pair works is at the bottom.
X "export VAULT_TOKEN=$ROOT; bao write auth/approle/role/eso token_policies=eso token_ttl=1h token_type=service secret_id_num_uses=0"
X "export VAULT_TOKEN=$ROOT; bao write auth/approle/role/portal token_policies=portal token_ttl=1h token_type=service secret_id_num_uses=0"
```

Hand the pairs to their consumers (k8s Secrets — these few never ride the
vault they unlock; same paradox, documented in the CR headers):

```bash
# role_id reads plain; secret_id needs -force (empty body) and -field:
ESO_RID=$(X "export VAULT_TOKEN=$ROOT; bao read -format=json -field=role_id auth/approle/role/eso/role-id" | tr -d '\r\n\" ')
ESO_SID=$(X "export VAULT_TOKEN=$ROOT; bao write -force -format=json -field=secret_id auth/approle/role/eso/secret-id" | tr -d '\r\n\" ')
kubectl -n external-secrets create secret generic bao-approle-credentials \
  --from-literal=role-id=$ESO_RID --from-literal=secret-id=$ESO_SID
# portal (lumen's relay) family likewise → lumen-bao-credentials; PROVE each
# pair by logging in with it before declaring done:
#   bao write -format=json -field=token auth/approle/login role_id=.. secret_id=..
#   (length must be a real token, not a 400 — the walk found both corpses)
```

## 4. Seed the values — `kv/{app}/production`, the CRs are the contract

Every key listed below must exist because the ExternalSecrets in
`vortex/overlays/production/*` declare them — **1:1, property == secretKey,
no translations**. Generate values on the server, never in Git, reuse
nothing from the rehearsal:

```bash
STAGINGLESS_DB_PW=$(kubectl -n db get secret 'db_user_production.lumen-pg.credentials.postgresql.acid.zalan.do' -o jsonpath='{.data.password}' | base64 -d)
X "export VAULT_TOKEN=$ROOT; bao kv put kv/lumen/production \
  LUMEN_DB_URL=postgres://db_user_production:$STAGINGLESS_DB_PW@lumen-pg.db.svc:5432/lumen_production \
  LUMEN_MEILI_URL=http://meilisearch.search.svc.cluster.local:7700 \
  LUMEN_MEILI_KEY=$(openssl rand -hex 16) \
  LUMEN_SESSION_JWT_SECRET=$(openssl rand -hex 32) \
  LUMEN_MEDIA_ENDPOINT=https://<account-hash>.r2.cloudflarestorage.com \
  LUMEN_MEDIA_REGION=r2 LUMEN_MEDIA_BUCKET=omicron-media \
  LUMEN_MEDIA_ACCESS_KEY=<from R2 token> LUMEN_MEDIA_SECRET_KEY=<from R2 token> \
  LUMEN_MEDIA_CDN_BASE=https://img.gofar.id LUMEN_MEDIA_FORCE_PATH=false"

X "export VAULT_TOKEN=$ROOT; bao kv put kv/earendil/production API_BASE=http://lumen-http-server.lumen.svc.cluster.local"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/mellon/production API_BASE=http://lumen-http-server.lumen.svc.cluster.local"
X "export VAULT_TOKEN=$ROOT; bao kv put kv/cert-manager/production CF_API_TOKEN=<scoped token from ch.04>"
```

> ⚠️ **`bao kv put` REPLACES the whole path's map** (incident: a mid-list
> failure stripped the rest). One invocation per path, then VERIFY:
> `bao kv get -format=json kv/lumen/production` and diff key-by-key against
> the CR's `data:` list. **Never** `bao kv delete` casually.

## 5. Make the robots notice (materialize timing)

ExternalSecrets created *before* the seed sit "Ready=false, next refresh in
~1h". Don't wait: `kubectl delete externalsecret -n <ns> <name>` → Argo
selfHeal recreates it → fresh object syncs immediately. Then
`kubectl rollout restart deploy/...` every consumer pod — **envFrom binds
only at container start**, pods that booted blind hold empty values until
recycled. ✅ end state: all ES `Synced=True`, `Ready=True`.

## 6. Day-2 rituals (they are in ch. 12's calendar because they bite)

- **After EVERY bao pod restart (incl. host reboots):** the vault returns
  **SEALED** (data survives, seal state doesn't). Unseal ritual (2 keys):
  `X "bao operator unseal <key-from-offline>"` ×2 → everything reconciles
  within ~a minute; bounce the ESO controller (`kubectl -n external-secrets
  rollout restart`) to skip its error backoff. ES symptom of a sealed vault
  (all three red, `could not get secret data from provider`) — trust
  `describe`'s *Last Transition Time* to date the incident, not `get`'s
  misleading "last sync".
- **Rotation:** values change in Bao → ES re-renders on refresh (1h) →
  pods needing the new value get `rollout restart` (selfHeal never reverts
  what it doesn't track).
- **Vault reborn (lost unseal keys):** it happens — the rehearsal did this
  drill by accident. Destroy pod + PVC **and the node directory**
  (`/var/lib/rancher/k3s/storage/<ns>_openbao-...` — Retain + PV deletion
  does NOT wipe it; this trap bit twice: bao and meili), re-init §2, re-seed
  §4, re-issue §3 credentials. Everything else in the estate can be
  rebuilt from Git + backups.

Next → [06 Media on R2](06-media-r2.md)
