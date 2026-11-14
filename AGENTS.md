# AGENTS.md — working in this repository

Guide for AI coding agents (and humans) making changes here. Read the linked docs
before structural changes; don't re-derive decisions that are already made.

## What this repo is

A personal blog superproject: three git **submodules**, each its own repo under
[`kanatabi`](https://github.com/kanatabi) on GitHub (GitLab `arkoi/omicron*` kept as
mirrors), plus the production infrastructure blueprint. Not a single app —
several moving parts with different toolchains:

| Path | What | Treat with |
| :--- | :--- | :--- |
| `earendil/` | SvelteKit 3 blog frontend, SSR via `adapter-node` | normal app dev — see its README |
| `vortex/` | GitOps source of truth (Argo CD app-of-apps) | **read `vortex/README.md` first**; conventions are load-bearing |
| `INFRA_ARCHITECTURE.md` | Production blueprint (K3s on 3 VPS, phases §4, secrets design §5) | the decision record — update it when you change a decision |
| `lumen/` | REST backend — **live code** (M1–M6 merged to `main` 2026-11-09: read API on Meilisearch, admin API, media relay, Bao passthrough) | contract mirror of earendil's `BlogApi`; `lumen/DESIGN.md` mirrors §1/§8 |
| `mellon/` | Admin portal — **live code** (`kanatabi/mellon` remote real; UI + lumen fetch-adapter on `feature/lumen-cutover`) | UI-only by doctrine: relays to lumen, holds no credentials — read `mellon/DESIGN.md` §2 before any feature work |

## Commands

**Frontend (`earendil/`):** `npm run dev` · `npm run check` (svelte-check) ·
`npm run build` · `npm run lint` · `npm run test:unit` (vitest).
Always run `npm run check && npm run test:unit` after touching `src/`.

**Manifest validation (no cluster needed):** `kubectl kustomize <dir>` builds any
kustomization under `vortex/` — run it after ANY manifest edit.
Remote-pinned resources (Argo overlay) need network on first fetch.

**Local cluster rehearsal:** follow `README.md` / `runbook/00a` — Track A
(the canonical k3d rehearsal: both staging AND production envs on one
cluster) and the 3-node topology exercise (node-pool labels). Images are
real public ghcr v-tags (no placeholder builds / image imports anymore).

## Workflow

- Each submodule (`earendil/`, `lumen/`, `vortex/`) is its own git repo — GitHub is the
  primary (`git@github.com:kanatabi/<name>.git`, default branch `main`); the GitLab
  `arkoi/omicron/<name>` remotes are kept as mirrors. Conventional Commits, granular.
- `vortex/` extra rule: **all changes go on branches forked from `main`** — never direct
  commits (the four scaffold commits are the baseline exception).
- The workspace root is the submodule superproject: changes here are only pins (gitlinks),
  `.gitmodules`, and root docs. Bump a pin after pushing the child:
  `git add <child> && git commit`.

## Non-negotiable conventions

1. **No real config/secret values in Git.** Schema (`env.yaml.sample`) and templates
   (`ExternalSecret` CRs) live in Git; values live in OpenBao. Adding a value, token, or
   domain-specific string directly to a manifest = breaking the design (INFRA doc §5).
   DB creds & TLS are generated in-cluster — reference them, never store them.
2. **Two sanctioned public surfaces, never a public API** (owner amendment,
   2026-11-08, INFRA §2): `gofar.id` (earendil, content) and `console.gofar.id`
   (mellon, TLS + GATE #10 checklist). `lumen` and `meilisearch` stay ClusterIP-only
   by design; browser→API traffic rides the SSR/portal same-origin proxies
   (`earendil/src/routes/api/[...path]/+server.ts`, `mellon/src/routes/(app)/api/`).
   Don't "fix" a 404 on `/api/...` by adding an API ingress — the proxy or `API_BASE`
   is the bug.
3. **Placement is explicit.** Every deployment carries `node-pool` affinity
   (`platform` master / `data` worker-1 / `edge` worker-2) and hostname anti-affinity
   where 2-replica. If you add a workload, update the §1 budget table too — master has
   ~100 Mi slack, don't schedule there.
4. **Versions pinned, tags immutable.** Argo overlay, cert-manager, operator, Helm
   charts: exact versions. **Only released v-tags deploy** — `sha`-of-branch and
   `latest` are banned from manifests. Merges gate and park three waiting bump
   jobs, EACH on its own protected environment (`release-patch|minor|major` —
   never shared: approvals batch per environment); approving ONE is the
   release decision; the PAT-pushed tag it emits (RELEASE_BOT_PAT,
   Contents+Workflow+Actions perms) triggers the deploy pipeline, whose
   `deploy` jobs — ONE CHAIN PER ENVIRONMENT (`deploy-foundation|
   deploy-staging|deploy-production`, lumen three, earendil/mellon two) —
   each parking on its SAME-NAMED protected environment; evidence first
   (deploy-plan-<env>), then the human's deploy click, then that env's
   bump PR (born validated, auto-merge behind `DEPLOY_AUTOMERGE`); the
   ladder is the APPROVAL ORDER (staging before production). Because a
   referenced-but-missing environment is AUTO-CREATED UNPROTECTED (the
   2026-11-13 incident: v3.0.0 fired with no park, five bump PRs opened
   unattended), every release pipeline ships a fail-closed `gate-audit`
   job: no environment OR no required_reviewers = deploy chain RED.
   Config is likewise released: the `omicron/config.epoch` TRIO
   (pod annotation + gate `--declared` + ES annotation, byte-equal)
   bumps through the same pipeline, per-env only (an epoch flip targets
   ONE environment — trio values differ per env); the in-cluster gate
   BLOCKS sync unless declared==head and pin agrees — and a pin is a
   LOCK (lumen 403s writes while set).
   (amendments 2026-11-13/14, runbook/06–09 + `runbook/00a` for order)
5. **App-of-apps shape:** `apps/{foundation,observability,production,staging}/`
   (and the Part-C `apps/`) contain ONLY Argo `Application` CRs; raw manifests
   under `bases/<name>/`; each hub syncs its folder non-recursively.
   Adding an app = new dir + new Application CR, never hub edits. The
   observability app rides its OWN hub (`bootstrap/apps-hub-observability.yaml`)
   — a manual gate applied only after the vault ritual AND the grafana
   four-key seed verify (its ExternalSecrets error on any missing key; the
   sync-op wedge class, ch.12 card 11). Bases stay ESO-free (k3d invariant)
   AND carry NO image pins (2026-11-13 convergence: a base `images:` stanza
   outranks every env overlay in kustomize — fixture-proven; env trees are
   the only version homes); per-env values ride `environments/<env>/<app>`;
   moving an env to another cluster = that app's Argo destination edit only.
6. **CI bump PRs edit only fence-covered lines, by pattern:** the `images:` stanza
   in `environments/<env>/*/kustomization.yaml` (same-env lockstep: a lumen bump
   moves every `name: lumen` stanza of that env — its gate pins — in ONE commit,
   never another env's), plus the epoch TRIO: pod-template `omicron/config.epoch`
   annotation + gate `--declared` arg + ExternalSecret `omicron/config.epoch`
   annotation, byte-equal, all three in the same commit. Branch grammar
   `bump/<app>-<env>-<tag>` (legacy `bump/<app>-<tag>` = production, deprecated);
   the path fence is env-scoped from the branch. The fence accepts line SHAPES and
   never app names; app identity arrives from each repo's workflow (`--app`, and the
   app is also parsed from the bump branch name). Keep the container's image name (e.g.
   `lumen`) stable so `kustomize edit set image` keeps working; GHCR names must be lowercase.
7. **Observability contract: no sidecars.** Alloy is a worker-node DaemonSet; apps opt
   into scraping with `prometheus.io/{scrape,port,path}` pod annotations and serve
   `/metrics` on an unrouted admin port (9090) + structured stdout logs. Traces are OFF
   (no Tempo); the statsd listener exists but stays commented. See INFRA doc Phase 5.

## SvelteKit-specific traps (earendil)

- **Runtime env only.** Never use `VITE_*`/build-time-inlined env for anything that
  differs between staging/prod — one image runs everywhere. Server: `process.env.API_BASE`;
  browser: `PUBLIC_API_BASE="/" ` (same-origin proxy). Kit v3 env lives in `src/env.ts`
  (`defineEnvVars`); `$app/env/private` is **server-only** — importing it from shared code
  breaks the client build. That's why server loads use `#lib/api/server.ts` while
  components use `#lib/api/index.ts`.
- `#lib/*` is a package.json `imports` alias — don't rewrite to `$lib` and vice versa.
- **Real-by-default** (owner ruling 2026-11-09, supersedes "mock-first"): the runtime always
  fetches lumen (unset env = dev fallback `http://localhost:8080`). `mock.ts` is TEST-ONLY
  (twin semantics + contract baseline) — the runtime import graph must never touch it;
  `npm run test:unit` still works with no cluster (direct twin imports).
- Search suggest is the ONLY client-side API call. Everything else lives in `+page.server.ts`.

## Kubernetes/kustomize gotchas

- `patches:` with a `path:` file CANNOT wrap targets inside the file (`- target:/patch:`
  lists are invalid there). Either put `target:` on the kustomization entry with the file
  holding the bare patch body, or use multi-doc strategic-merge files matched by name
  (see `platform/argocd/`). `components:` must be directories, not files.
- Argo's install manifests label every component `app.kubernetes.io/part-of=argocd` —
  the pinning patch uses that labelSelector on Deployment + StatefulSet so future
  components auto-pin. Don't regress to per-name pinning.
- The app-of-apps hubs (`bootstrap/apps-hub-foundation.yaml` +
  `bootstrap/apps-hub-observability.yaml` + the env hubs; Part C's
  `apps-hub.yaml` when it comes)
  can't be GitOps-managed themselves; that's
  the intended manual bootstrap exception. Same for ESO/OpenBao first-time seeds (§5.6).

## Placeholders — what's real vs still open

Staging hosts are contractual `staging.gofar.id` + `staging-console.gofar.id`
(vortex README; DNS records + vault seeds land when staging goes live on a
real cluster); the
earendil PRODUCTION ingress was cut over to `gofar.id` + `www.gofar.id` on 2026-11-11
(vortex 7b2c5cc, verified live) — do not revert that either. `repoURL`s are REAL too as of 2026-11-10 — repointed to
`https://github.com/kanatabi/vortex.git` when the manifests repo moved org+name (the
old `cavadevop/k8s-platform-manifests` was the last cluster-breaking placeholder).
The `ORIGIN` env: dropped 2026-11-10 with no reader, then RE-ADOPTED WITH its
reader per the with-its-consumer clause (earendil `resolveOrigin` → JSON-LD
canonical; vortex earendil ES data lines render it per env, seeded from Bao).
Still open:
Bao kv seeds (`lumen/{env}`, `earendil/{env}` values — per-cluster, seeded at
bootstrap per RUNBOOK) plus the staging DNS records and vault seeds
(`kv/{app}/staging`, `kv/lumen/shared`) — the staging Application CRs +
`bootstrap/apps-hub-staging.yaml` have LANDED (staging hub live; first bump
#17 proved the ladder). The first live walk of RUNBOOK Part A is DONE
(2026-11-11: estate green on minikube, login both postures proven; §5 of the
runbook lists what remains open — Part B/VPS ordering, observability sizing). RESOLVED 2026-11-10: `REPLACE_AT_BOOTSTRAP` —
the ESO appRole now takes BOTH ids from the bootstrap Secret (`roleRef`, verified
against the 2.15.0 CRD); no cluster-specific literals in Git anymore.

## Pointers

- **`runbook/` (this repo)** — THE operating procedure: VPS-first,
  provider-neutral, junior-readable (start at `runbook/00-overview.md`).
  The minikube rehearsal that produced its claims lives in the archived
  `RUNBOOK.md` at this root.

- Production phases, unseal drills, quorum rationale: `INFRA_ARCHITECTURE.md`
- Local end-to-end test script (placement, failover, selfHeal, proxy): `README.md` §5
- Manifest-repo rules in short form: `vortex/README.md`
- earendil's older single-node notes (`earendil/ARCHITECTURE.md`, `DESIGN.md`, `PLAN.md`) are
  pre-revision drafts — the root INFRA doc supersedes them on conflicts.
