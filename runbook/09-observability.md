---
tags: [runbook, observability]
updated: 2026-11-13
status: stack decided & pinned (INFRA Phase 5); deployment path written,
  first real install happens on the VPS walk
---

# 09 · Observability — the lab's eyes (Grafana LGTM + VictoriaMetrics)

> **Why this chapter:** everything so far can fail quietly. The point of
> metrics + logs + dashboards is that **the estate tells you before the
> readers do** — cert about to die, backup gone stale, vault sealed, pod
> crash-looping. Also: this is the family's learning wall (ch. 09 §5).

## 1. The four tools, in one honest paragraph each

| Tool | Job | Analogy |
|---|---|---|
| **Grafana Alloy** (DaemonSet) | one small collector that scrapes *everything* and also listens for pushed logs/metrics | the building's single wiring closet |
| **VictoriaMetrics** | stores **metrics** (numbers over time), PromQL-compatible | the ticker tape |
| **Loki** | stores **logs** (labeled lines, LogQL) | the mailroom, index-only |
| **Grafana** | the face: dashboards + alerts | the wall of screens |

> **Why Alloy one-per-node instead of a per-app agent army:** the INFRA
> decision (Phase 5) — small machines don't fit ~150 Mi of exporters per
> pod; Alloy remotely scrapes kubelet/cAdvisor and reads pods'
> `/metrics`, so apps opt in with **three pod annotations** and zero
> sidecars. **Why VictoriaMetrics over plain Prometheus:** single-binary,
> storage-efficient, drop-in PromQL — and it was the owner's stack ruling
> (2026-11-13; INFRA carries the amendment next to the LGTM name).

## 2. Turning it on (it's already templated in vortex)

`applications/observability/` exists (19 manifests, pinned versions per
INFRA Phase 5) but was excluded from the rehearsal hub on a 2 GB node.
On the VPS it belongs in: add the Application CR to `apps/single-node/`
(wave 3 — after the data plane is healthy), point at
`overlays/production/observability`, merge, Argo does the rest — GitOps,
same as every other app, *no manual installs.*

Sizing on the 4c/8G box (from INFRA §1 budgets, single-node honest edit):
VM retention **30d / ~10 Gi PVC**, Loki **7d / ~15 Gi PVC**, Grafana ~1 Gi.
If disk pressure shows up, shrink *Loki retention first* — metrics are
cheaper to keep than logs. Traces stay OFF (no Tempo — deliberate).

## 3. The apps already speak (the no-sidecar contract)

Any pod that should be watched gets:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"    # the unrouted admin port — never an Ingress
  prometheus.io/path: "/metrics"
```

lumen already does (admin port 9090, not public); structured stdout logs
are picked up by Alloy's log reader automatically. The OTLP receiver is
configured-but-waiting (forward path for the Go OTel SDK — "add, not a
rewrite" is the INFRA line; nothing to do today).

## 4. The door: `anor.gofar.id` (or your chosen `beacon`)

Already wired by earlier chapters: DNS 🟠 + managed challenge (ch.04 Act 2)
+ **Access application** (Act 4) + `Certificate`. The Traefik Ingress for
`grafana` is in the overlay; **no NodePort, no public origin exposure** —
the only path in is Cloudflare→Access→edge. Root URL + OAuth env values
are *config*, so they live in Bao (`kv/grafana/production`) and render via
an ExternalSecret like everything else — including the Access OAuth
client secret:

```
GF_SERVER_ROOT_URL=https://anor.gofar.id
GF_AUTH_GENERIC_OAUTH_ENABLED=true            # Access is the identity
GF_AUTH_GENERIC_OAUTH_CLIENT_ID / _CLIENT_SECRET
GF_AUTH_OAUTH_AUTO_ASSIGN_ORG=true            # first login = account exists
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=... # maps your email → Admin
```

## 5. Users, roles, and the family lab (junior version)

Grafana roles from smallest to largest:

| Role | Can |
|---|---|
| **Viewer** (what friends get) | look at every dashboard, run queries |
| **Editor** | create/edit dashboards — *scoped to the team folder you grant* |
| **Admin** (YOU only) | also manage **data sources** — and a data-source
  admin can read its credentials and query whatever it connects to. That
  line is the whole security story of a shared Grafana. |

The loop: add an email to the **Access policy** → their first visit
auto-creates the Grafana user as Viewer. Remove = delete from the policy
(no second password system to forget). Create a team `lab-friends`, give
it **Editor on one folder: `Learning`** — inside that folder they can make
and wreck dashboards all afternoon; outside it, nothing. That's a homelab
classroom without a `sudo` list.

> **The honest caveat:** every Viewer sees all metrics/logs of this estate
> (that's what Grafana *is*). For family: a feature. For a stranger: don't
> invite strangers; org-level isolation is a later exercise, not tonight.

Include-the-dashboards starter pack (import JSON, all community-proven):
node exporter (the machine), kubernetes cluster (the pods), Loki logs
explorer ("search the mailroom"), and the alerts below. A `Learning`
folder with one blank panel + a query you can type is the actual
teaching tool.

## 6. Alerts that matter (the boring ones earn the stack)

Wire these Grafana alert rules first — they've each *really* bitten once:

1. **Certificate expires < 21d** (`certmanager_certificate_expiration_timestamp_seconds`)
2. **Backup freshness** — push a metric from restic (ch.10's timer exports
   `backup_last_success_timestamp`; alert if older than 36h). *An old
   backup is not a backup, it's a hope.*
3. **Vault sealed** — probe `bao status` via the node's exporter metrics
   or a small blackbox; the reboot-incident's symptom in advance.
4. **Pod restarts spike / CrashLoopBackOff** — generic, catches everything
   else (sealed vault, ImagePull, failed migrations).
5. **Disk > 80%** — the quiet killer on an 80 GB box.
Contact point: email (Let's Encrypt notices go there too — one inbox).

Next → [10 Backup & Recovery](10-backup-dr.md)
