---
tags: [glossary]
updated: 2026-11-15
---

# Glossary — the estate's vocabulary

Terms a newcomer (human or agent) will meet in the repos' docs. Each entry
points at where the depth lives — this file defines, it does not explain.

## The cast

- **omicron** — the superproject workspace: five git submodules + the INFRA
  decision record + `runbook/`. See [what-is-omicron.md](what-is-omicron.md).
- **gofar;** — the blog brand/wordmark ("go far", pen-word of Faiz Ainur
  Rofiq; also a legitimate Arabic/Indonesian name). earendil DESIGN §brand.
- **earendil** — the SvelteKit SSR frontend; a Tolkien mariner that "goes far".
- **lumen** — the Go REST backend; the light the blog runs on.
- **mellon** — the admin portal; Sindarin for "friend" (`_Speak, friend, and
  enter._`).
- **vortex** — the GitOps manifests repo; the swirl everything lands through.
- **anvil** — the release toolkit; where tags are hammered into deploys.

## GitOps & cluster

- **app-of-apps** — Argo CD pattern: one hub Application syncs a folder of
  child Application CRs. vortex's hubs sync `apps/<hub>/` **non-recursively**.
- **hub / entrypoint** — a `bootstrap/apps-hub-<name>.yaml` applied by hand:
  foundation → observability (manual gate) → production → staging.
- **base** — `vortex/bases/<app>/`: raw manifests, suffix-free, env-free,
  **ESO-free, and never carrying image pins** (a base `images:` stanza
  outranks every overlay — kustomize override order, fixture-proven
  2026-11-13).
- **env tree** — `vortex/environments/{foundation,staging,production}/<app>/`:
  the env axis. The ONLY version homes.
- **nameSuffix** — kustomize rewrites `metadata.name` only; every name-bearing
  reference must be authored final in the overlay or JSON6902-patched
  (vortex naming contract).
- **config-gate** — a PreSync Job that decodes `omicron/config.epoch` and
  refuses to sync when declared ≠ rendered (vortex `components/config-gate`).
- **epoch TRIO** — pod-template annotation + gate `--declared` arg +
  ExternalSecret annotation, byte-equal, moved in ONE commit (anvil §6).
- **walk / walked green** — a runbook chapter executed against the real
  estate; a `status:` promotion ritual (runbook ch.12).
- **battery** — the manifest validation suite (anvil `validate-all.sh`):
  rendered-loss baseline + structural invariants over the RENDERED output.

## Secrets plane

- **OpenBao / Bao** — the values store (Vault-compatible fork). ClusterIP-only.
- **ESO** — External Secrets Operator; renders `ExternalSecret` CRs from Bao.
  Fails the whole render on ONE missing property — seeding order is structural.
- **KV v2 (head / version / pin)** — OpenBao's versioned KV. Head is what you
  see; a pin is a LOCK (refuses writes while pinned, lumen answers 403) —
  redefined 2026-11-13, was "intent".
- **apps-are-data** — no app-specific logic anywhere in lumen/mellon; app
  slugs are opaque validated names; onboarding seeds the
  `dev/staging/production` trio (the frozen contract:
  [decisions/secrets-control-plane.md](decisions/secrets-control-plane.md)).
- **key-set mirror** — a write to one env mirrors the KEY SET to sibling envs
  (adds empty, removes propagate; values stay per-env).
- **TOFU** — trust-on-first-use: the setup wizard claims the estate's first
  admin exactly once, terminal `410 Gone` after.
- **break-glass** — a manual fallback path kept documented but unused
  (mellon's port-forward).

## Release ladder (anvil)

- **the ladder is the approval order** — staging deploys before production;
  each env's deploy parks on its own protected environment.
- **bump PR** — `bump/<app>-<env>-<tag>` against vortex: images stanza lines +
  optional epoch TRIO, born-validated, pattern-fenced.
- **deploy-plan** — the evidence-only rehearsal (current pin → proposed pin +
  validated rendered diff); what the human reads before approving.
- **gate-audit** — fail-closed job: no protected environment + required
  reviewers ⇒ deploy chain red (the 2026-11-13 auto-created-unprotected
  incident).
- **settle** — after a release, the sibling bump reviews auto-decline (warn-only).
- **GATE #N** — numbered human checkpoints in the runbook/INFRA ledger (GATE
  #5 secrets threat read-through; #9 media/R2; #10 console go-live).
- **live-fire** — a lesson proven by a real incident, not a drill (the tag
  that never deployed; the double release).
- **twin** — the frontend/backend fixture twins: TEST-ONLY corpora mirroring
  the real contracts (lumen's seed mirror, earendil's `mock.ts`); the runtime
  import graph never touches them (real-first ruling 2026-11-09).
- **Route B** — the adopted diagram design: BE ships raw ` ```mermaid `
  fences, FE renders client-side (Route A, publish-time SVG, was evaluated
  and rejected).
