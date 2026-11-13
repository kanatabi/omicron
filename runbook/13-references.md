---
tags: [runbook, refs]
updated: 2026-11-14
---

# 13 · References — the official docs behind every claim

> **Why:** this runbook should be *checkable*, not faith-based. Every
> pinned thing links to its source; when a version bumps deliberately,
> these are the pages you re-read.

## The cluster itself

| Topic | Link |
|---|---|
| k3s install script & options (`--disable`) | https://docs.k3s.io/installation |
| k3s channels/versioning | https://k3s.io / https://github.com/k3s-io/k3s/releases |
| k3s storage class (local-path) | https://docs.k3s.io/storage |
| k3d (the local rehearsal cluster behind every "rehearsed" status line) | https://k3d.io |
| k9s (ch.11 §2's terminal UI) | https://k9s.io |
| Kubernetes concepts (for the junior reader: pods/Deployments/Services/Ingress) | https://kubernetes.io/docs/concepts/ |

## Edge & doors

| Topic | Link |
|---|---|
| Traefik helm chart (pinned 42.3.2) | https://doc.traefik.io/traefik/ + https://github.com/traefik/traefik-helm-chart |
| Cloudflare: proxy vs DNS-only | https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/ |
| Cloudflare IP list (firewall input) | https://api.cloudflare.com/client/v4/ips (+ docs page) |
| Managed challenges / WAF custom rules / Under Attack | https://developers.cloudflare.com/waf/managed-challenges/ · https://support.cloudflare.com/hc/articles/18680167876377 (Under Attack) |
| Cloudflare Access (Zero Trust) incl. Grafana SaaS template | https://developers.cloudflare.com/cloudflare-one/applications/ · https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/datasheet-grafana/ |
| Cloudflare DNSSEC | https://developers.cloudflare.com/dns/dnssec/ |
| cert-manager v1.16.x, DNS-01 Cloudflare solver | https://cert-manager.io/docs/ · https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/ |
| Let's Encrypt lifecycle (90d/renew-60) | https://letsencrypt.org/docs/a-warm-welcome-to-that-certificate-issuing-process/ |

## GitOps & the release machine

| Topic | Link |
|---|---|
| Argo CD (pinned v3.6.1; SSA note) | https://argo-cd.readthedocs.io/ |
| Argo CD repository authentication | **not needed: vortex is public** (kept here so nobody re-discovers the doc and wonders) |
| GitOps concepts | https://opengitops.dev/ |
| kustomize (`images:` transformer used by bump PRs) | https://kubectl.docs.kubernetes.io/references/kustomize/builtins/ |
| GitHub environments/required reviewers (the approval model, incl. per-env batching) | https://docs.github.com/actions/deployment/environments |
| Fine-grained PATs (Contents/Workflow/Actions perms — the trio's lesson, ch.09 §5) | https://docs.github.com/authentication/keeping-your-account-and-data-secure/about-fine-grained-personal-access-tokens |
| Actions anti-recursion rule (why tags need a PAT) | https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idsteps-run (see "GITHUB_TOKEN" notes) & https://github.community/t/support-triggeringRepositoryPushEvents-in-github-token/11510 |
| Repo variables NOT readable by GITHUB_TOKEN (the env-door lesson) | https://docs.github.com/actions/learn-github-actions/variables (limitations note) |
| Zalando Postgres Operator v1.13.0 (pinned install, ch.04 §2's table) | https://postgres-operator.readthedocs.io/ |
| External Secrets Operator 2.15.0 (Vault backend; generic `target.manifest` ConfigMap renders) | https://external-secrets.io/ |
| OpenBao | https://openbao.org/docs/ (init/unseal/**snapshot**/approle pages — snapshot is ch.08 §3b's) |
| Meilisearch upgrade policy (v1.56.1) | https://www.meilisearch.com/docs/learn/welcome/update-meilisearch |

## Observability & identity (ch.10)

| Topic | Link |
|---|---|
| Grafana Alloy / Loki | https://grafana.com/docs/alloy/ · https://grafana.com/docs/loki/ |
| VictoriaMetrics single-binary | https://docs.victoriametrics.com/ |
| Grafana generic-OAuth (the Access OIDC road) | https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/ |
| Grafana file **provisioning** (datasources-by-UID + the alerting `monitoring.grafana.com/v1alpha1` format) | https://grafana.com/docs/grafana/latest/administration/provisioning/ |
| Cloudflare Access Grafana template (the dashboard-door datasheet) | https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/datasheet-grafana/ |

## Storage, backups, access roads

| Topic | Link |
|---|---|
| Cloudflare R2 (**S3 compatibility — the one honest endpoint grammar in ch.08 §2**, $0 egress, scoped tokens) | https://developers.cloudflare.com/r2/ |
| restic (the S3 backend, backup/restore/check/forget — ch.08's whole verb list) | https://restic.readthedocs.io/ |
| age (file encryption used elsewhere in the estate — NOT part of the restic loop) | https://age-encryption.org/ |
| Tailscale (ACLs, kube-over-tailnet, Tailscale SSH) | https://tailscale.com/kb/ |
| Headscale (the self-host-the-coordinator escape hatch, ch.11 §4) | https://headscale.net |
| NetBird (fully-OSS control plane — the requirement-not-preference answer, ch.11 §5) | https://netbird.io |
| Ubuntu hardening baseline (ssh config.d, ufw, unattended-upgrades) | https://documentation.ubuntu.com/server/how-to/security/ |

## Estate-internal truth (where OUR decisions live, read before changing)

| Question | Where |
|---|---|
| Why any of this is shaped this way | `../INFRA_ARCHITECTURE.md` (the decision record) |
| What's proven vs open (walk ledger) | `../PLAN-SECRETS-CONTROL.md` + each chapter's frontmatter `status:` (the promotion ritual, ch.12) |
| How this folder is numbered & why (reading order, waves, the 04–07 split) | `00-overview.md` + this folder's git history |
| Working rules for agents/devs | `../AGENTS.md` (workspace) + each child repo's AGENTS/DESIGN |
| Rehearsal-era detail (minikube quirks, the A-numbered recipes like A11) | `../RUNBOOK.md` (**archived** rehearsal log — reference, not procedure) |
| The manifest truth battery's expected-kinds table | `../anvil/bin/expected-kinds.txt` — the 23-row truth table (per-directory expected resource-kind counts, regenerated for the `environments/*` tree — `bases/` bases + the 7 foundation + 3×2/3 env overlays) enforced by `validate-manifests`; a count change is a reviewable event |
| The render contract per plane | `vortex/README.md` ("ES = the render contract", "Naming contract") + lumen `config keys --role admin\|cms` — the machine truth behind ch.05's seed tables |
| The auto-merge guard itself (the six guards are law in code) | `../anvil/bin/auto-merge.sh` + `../vortex/.github/workflows/` |
| API contract between apps | `../lumen/DESIGN.md` ⇄ `../earendil` client.ts |
