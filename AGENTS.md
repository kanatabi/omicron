# AGENTS.md — working in this repository

Guide for AI coding agents (and humans) making changes here. Read the linked docs
before structural changes; don't re-derive decisions that are already made.

## What this repo is

A personal blog project + its production infrastructure blueprint. Not a single app —
four moving parts with different toolchains:

| Path | What | Treat with |
| :--- | :--- | :--- |
| `sv-fzr/` | SvelteKit 3 blog frontend, SSR via `adapter-node` | normal app dev — see its README |
| `k8s-platform-manifests/` | GitOps source of truth (Argo CD app-of-apps) | **read `k8s-platform-manifests/README.md` first**; conventions are load-bearing |
| `INFRA_ARCHITECTURE.md` | Production blueprint (K3s on 3 VPS, phases §4, secrets design §5) | the decision record — update it when you change a decision |
| `test/local-backend/` | Placeholder Go API for k3d testing only | throwaway |

## Commands

**Frontend (`sv-fzr/`):** `npm run dev` · `npm run check` (svelte-check) ·
`npm run build` · `npm run lint` · `npm run test:unit` (vitest).
Always run `npm run check && npm run test:unit` after touching `src/`.

**Manifest validation (no cluster needed):** `kubectl kustomize <dir>` builds any
kustomization under `k8s-platform-manifests/` — run it after ANY manifest edit.
Remote-pinned resources (Argo overlay) need network on first fetch.

**Local cluster rehearsal:** follow `README.md` (k3d, 1 server + 2 agents, node-pool
labels). `k3d image import` after rebuilding placeholder images.

## Workflow

- `k8s-platform-manifests/` is its own git repo (master). **All changes there go on
  branches forked from `master`** — never direct commits (the four scaffold commits are
  the baseline exception). Conventional Commits, granular.
- The workspace root is not a git repo; `sv-fzr/` has its own repo and history.

## Non-negotiable conventions

1. **No real config/secret values in Git.** Schema (`env.yaml.sample`) and templates
   (`ExternalSecret` CRs) live in Git; values live in OpenBao. Adding a value, token, or
   domain-specific string directly to a manifest = breaking the design (INFRA doc §5).
   DB creds & TLS are generated in-cluster — reference them, never store them.
2. **Exactly one public ingress: the frontend.** `lumen` and `meilisearch` are
   ClusterIP-only by design; browser→API traffic rides the SSR same-origin proxy
   (`sv-fzr/src/routes/api/[...path]/+server.ts`). Don't "fix" a 404 on `/api/...` by
   adding an API ingress — the proxy or `API_BASE` is the bug.
3. **Placement is explicit.** Every deployment carries `node-pool` affinity
   (`platform` master / `data` worker-1 / `edge` worker-2) and hostname anti-affinity
   where 2-replica. If you add a workload, update the §1 budget table too — master has
   ~100 Mi slack, don't schedule there.
4. **Versions pinned, tags immutable.** Argo overlay, cert-manager, operator, Helm
   charts: exact versions. Images deploy as `sha-<short>`, never `latest`.
5. **App-of-apps shape:** `apps/` contains ONLY Argo `Application` CRs; raw manifests
   under `applications/<name>/`; hub syncs `apps/` non-recursively. Adding an app = new
   dir + new Application CR, never hub edits. Bases stay ESO-free (k3d invariant) —
   per-env values ride `overlays/production/<app>`; going prod = repoint that app's
   Application `source.path`.
6. **CI edits only `images:` in `applications/*/kustomization.yaml`** via
   `kustomize edit set image <name>=...`. Keep the container's image name (e.g.
   `lumen`) stable so that hook keeps working; GHCR names must be lowercase.
7. **Observability contract: no sidecars.** Alloy is a worker-node DaemonSet; apps opt
   into scraping with `prometheus.io/{scrape,port,path}` pod annotations and serve
   `/metrics` on an unrouted admin port (9090) + structured stdout logs. Traces are OFF
   (no Tempo); the statsd listener exists but stays commented. See INFRA doc Phase 5.

## SvelteKit-specific traps (sv-fzr)

- **Runtime env only.** Never use `VITE_*`/build-time-inlined env for anything that
  differs between staging/prod — one image runs everywhere. Server: `process.env.API_BASE`;
  browser: `PUBLIC_API_BASE="/" ` (same-origin proxy). Kit v3 env lives in `src/env.ts`
  (`defineEnvVars`); `$app/env/private` is **server-only** — importing it from shared code
  breaks the client build. That's why server loads use `#lib/api/server.ts` while
  components use `#lib/api/index.ts`.
- `#lib/*` is a package.json `imports` alias — don't rewrite to `$lib` and vice versa.
- `createApi(undefined)` → mock fixtures (no backend). Keep mock coverage: `npm run test:unit`
  and dev-mode must work without the cluster.
- Search suggest is the ONLY client-side API call. Everything else lives in `+page.server.ts`.

## Kubernetes/kustomize gotchas

- `patches:` with a `path:` file CANNOT wrap targets inside the file (`- target:/patch:`
  lists are invalid there). Either put `target:` on the kustomization entry with the file
  holding the bare patch body, or use multi-doc strategic-merge files matched by name
  (see `platform/argocd/`). `components:` must be directories, not files.
- Argo's install manifests label every component `app.kubernetes.io/part-of=argocd` —
  the pinning patch uses that labelSelector on Deployment + StatefulSet so future
  components auto-pin. Don't regress to per-name pinning.
- The app-of-apps hub (`bootstrap/apps-hub.yaml`) can't be GitOps-managed itself; that's
  the intended manual bootstrap exception. Same for ESO/OpenBao first-time seeds (§5.6).

## Placeholders — what's real vs still open

`cavadevop` (all repoURLs) and `ainurrofiq.com` / `staging.ainurrofiq.com` (hosts,
ORIGIN) are REAL — do not revert them to placeholders. Still open: `REPLACE_AT_BOOTSTRAP`
(roleId in applications/secrets-plane), Bao kv seeds (`lumen/{env}`, `earendil/{env}`
values), and the staging Application CRs (overlay dirs exist; CRs land when a staging
target is wired).

## Pointers

- Production phases, unseal drills, quorum rationale: `INFRA_ARCHITECTURE.md`
- Local end-to-end test script (placement, failover, selfHeal, proxy): `README.md` §5
- Manifest-repo rules in short form: `k8s-platform-manifests/README.md`
- sv-fzr's older single-node notes (`sv-fzr/ARCHITECTURE.md`, `DESIGN.md`, `PLAN.md`) are
  pre-revision drafts — the root INFRA doc supersedes them on conflicts.
