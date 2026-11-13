---
tags: [runbook, onboarding]
updated: 2026-11-13
status: reference — every stop below is a live contract as built (pin-lock
  ch.05 §7.1, config-gate ch.06 §4/ch.07, structural validate-all); the
  ceremony is walked per new app, so "proven" = each stop exists and bites
---

# 14 · Onboarding a New App — the seven stops

> **Why this chapter:** the test of a designed estate is what adding
> *one more thing* costs. Here it costs a checklist, not a fork of
> shared scripts: six portal stops (the doors) and one Git tour (the
> map). Nothing in between holds secret knowledge — if it does, this
> chapter is the bug report.

## The map: seven stops, two owners

| # | Stop | Owner | Shipped |
|---|---|---|---|
| 1 | `+ app` — onboard the slug | portal | ✅ |
| 2 | `+ env` — add the environment | portal | ✅ |
| 3 | seed — first values, matrix row appears | portal | ✅ |
| 4 | pin — the lock | portal | ✅ |
| 5 | versions — history per path | portal | ✅ |
| 6 | restore — the road back | portal | ✅ |
| 7 | the structure: repo · CI settings · vortex manifests · kinds-table PR | Git | ✅ |

> **Why the split is the lesson:** the portal owns *values and their
> fate* (write, freeze, revisit, undo). Git owns *topology* — where the
> app runs, what gates it, who may release it. Stops 1–6 never create
> structure; stop 7 never touches values. Keep reading with that line
> in hand.

## Portal-owned — stops 1–6 (all shipped; the Vault page is the whole door)

1. **`+ app`** — mellon → configs/vault → onboarding dialog types the
   slug; lumen's `bao.onboard` control verb creates `kv/<app>/`. Slug
   grammar is enforced (`adminsvc.ValidAppSlug`) — the gate's `--app`
   arg and the bump-branch name the fence parses both speak it.
2. **`+ env`** — adds `kv/<app>/<env>` (the contract shape: one path
   per app per env, ch. 05 §7 — no registries anywhere).
3. **seed** — the first save creates **v1**; every later save moves
   **head**. The path appears in the matrix automatically (`ListPaths`
   over `kv/metadata`) — seeded right == visible, always.
   ✅ check: save, refresh, row exists; keys match the app's
   ExternalSecret `data:` list exactly.
4. **pin** — sets the path's `pinned_version`. While set, the relay
   refuses every write: HTTP 403 `{"error":"pinned at v<N> — unpin
   first"}`, rendered verbatim by the portal (ch. 05 §7.1). **A pin is
   a lock, not a label** — and reads are never affected: head keeps
   serving.
   ✅ check: pin it, click save, read the 403 — that's the feature.
5. **versions** — per-path history; each save is immutable, diffs are
   in the drawer.
6. **restore** — overlays an old version's values onto the **current
   key set** and hands you a dirty editor; save as vN and the portal
   offers **"pin vN?"** — restore-seeded saves only, so the lock
   re-lands exactly where you released it.
   ✅ check (the full loop): unpin → restore-draft → save as vN → take
   the offer → save refused again (correct) → done.

## Git-owned — stop 7: the structure tour

Four things, in order, and none of them names the app in a script:

1. **repo** — the app gets its own repo under `kanatabi` with
   `release.yml` + ci wired the way ch. 09's machine expects (three
   bump jobs, `deploy` job, `push-release.sh` as the only tag author).
2. **CI settings tour — FOUR protected environments per repo**:
   `release-patch` + `release-minor` + `release-major` + `deploy`,
   **one env per job** (shared envs batch-approve — a real incident,
   ch. 09 §5's first one-timer), required reviewer = the owner on
   each. Plus **two PAT secrets**: `RELEASE_BOT_PAT`
   (Contents+Workflow+Actions) and
   `VORTEX_BOT_PAT` (opens the bump PR) — 90-day expiry, calendar both
   at day ~75 (ch. 12). And the note on `DEPLOY_AUTOMERGE`: the vortex
   repo variable that arms auto-merge; absent = off = the kill switch
   (ch. 09 §4).
3. **vortex manifests** — `applications/<app>/` base,
   `overlays/production/<app>/` with the ExternalSecret + `envFrom` +
   the **epoch pair** (`omicron/config.epoch` annotation + gate
   `--declared` arg, byte-equal) + the `components/config-gate` PreSync
   Job — copy the shape of `overlays/production/earendil/` — and a
   new Application CR in `apps/applications/` (foundation dir for a
   data-plane piece).
   The *production* overlays carry the gate; dev/local shapes stay
   gate-free.
4. **kinds-table PR** — add the new dir + kind-count to
   `anvil/bin/expected-kinds.txt`; `kubectl kustomize` each dir locally
   first (no cluster needed). ✅ check: `validate-all` prints `… table +
   shape + hooks + epoch-pairs GREEN` — the structural classes now
   guard your app forever, with no shared script edited (next paragraph).

> **Why nothing in stop 7 enumerates your app:** because the CI is
> **structural** — assertions read rendered output and directory shape,
> never names: the Deployment inline-literal ban (iron law),
> ES+Deployment⇒`envFrom` (config must be *consumed*, not decoration),
> `*migrate*`⇒PreSync (schema gates deploy), and epoch-pair equality
> (a half-bump is red). Same doctrine as the auto-merge fence (patterns,
> not apps) and the gate (reads the slug grammar): **convention IS the
> registry** — a new app is covered the moment its YAML follows it. The
> one-time provisioning *script* that stamps these shapes is known and
> deliberately deferred: automation earns its keep only after the
> convention has been walked by hand a couple of times and stopped
> changing.

## The birth ceremony

First merge → three amber bump jobs. Approving one **is** the release
decision (ch. 09 §2): `major` → **v1.0.0**, `minor`/`patch` → v0.1.0 —
pick the birth number on purpose; it's a human ceremony by design.
Then the one-timer the chain can't do for itself: **if the repo is
private, flip the GHCR package to public** — images inherit repo
visibility on first push, pods carry no registry credentials by design,
and the failure is silent until the first roll. The
`ImagePullBackOff: unauthorized` story and its card live in
[ch. 12 §2](12-operations.md).

## The boundary line

> **The portal may hold every door, but it may never hold the map.**
> Values, versions, pins, restores — doors, and the portal owns them
> all. Topology — repos, hub dirs, waves, gates, environments, the
> kinds table — is the map, and the map lives in Git where every change
> is a reviewed PR with the rendered diff as evidence. Let the portal
> draw structure and `selfHeal` starts fighting a UI nobody diffs; let
> Git store values and the iron law dies quietly. Both halves of stops
> 1–7 exist to keep this line where you can see it.

Next → [13 References](13-references.md) — the official docs behind every
claim in this folder.
