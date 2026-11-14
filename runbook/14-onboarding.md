---
tags: [runbook, onboarding]
updated: 2026-11-14
status: >-
  reference — every stop below is a live contract as built (pin-lock
  ch.05 §7.1, config-gate ch.06 §4/ch.07, structural validate-all); the
  ceremony is walked per new app, so "proven" = each stop exists and bites;
  re-cut for the env model — two honest OPENs flagged inline (wizard env
  list, P3 epoch-agent backlog)
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
   **OPEN (don't paper over it in a hurry):** the wizard's env list still
   defaults to `dev/staging/production` — `dev` is gone (the env model
   retired it), and whether `shared` joins the portal's vocabulary is an
   undecided wire shape with two honest options: (a) keep `shared` a
   hand-seeded path the wizard never offers (its values — the signing key,
   the admin DSN — deserve the extra friction), or (b) surface `shared` as
   a read-mostly class with writes fenced by policy. Owner call; until
   then seed `*/shared` by CLI (ch. 05 §6.1) and treat the wizard's `dev`
   as a lie.
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
   bump jobs, ONE deploy chain per target environment — each chain
   `gate-audit` → `deploy-plan-<env>` → `deploy-<env>` — `anvil`
   actions pinned by SHA, and `push-release.sh` as the only tag author).
2. **CI settings tour — the protected-environment SET per repo**:
   `release-patch` + `release-minor` + `release-major`, plus one deploy
   environment per place the app runs: `deploy-staging` +
   `deploy-production` (earendil/mellon pattern) — add
   `deploy-foundation` if the app lives on the shared plane (lumen's
   three-chain shape). **ONE env per job** (shared envs batch-approve —
   a real incident, ch. 09 §5's first one-timer), required reviewer =
   the owner on each, and ALL of them created + protected BEFORE the
   first tag — the gate incident (ch. 09 §6) is what that sentence buys
   protection against; `gate-audit` will hold the chain RED otherwise.
   Plus **two PAT secrets**: `RELEASE_BOT_PAT`
   (Contents+Workflow+Actions) and
   `VORTEX_BOT_PAT` (opens the bump PR) — 90-day expiry, calendar both
   at day ~75 (ch. 12). And the note on `DEPLOY_AUTOMERGE`: the vortex
   repo variable that arms auto-merge; absent = off = the kill switch
   (ch. 09 §4).
3. **vortex manifests** — `bases/<app>/` base (**shape only: NO
   `images:` stanza — a base pin outranks every env overlay, the
   fixture-proven kustomize fact that made bases pin-free**, ESO-free,
   no inline config literals) + `environments/<env>/<app>/` overlays:
   each carries the ExternalSecret (target.name AUTHORED to the final
   suffixed spelling — `nameSuffix` never rewrites spec fields), the
   `envFrom` patches, the **version home** (`images:` stanza), the
   **epoch TRIO** (`omicron/config.epoch` pod annotation + gate
   `--declared` + ES annotation, byte-equal), and the
   `components/config-gate` PreSync Job — copy the shape of
   `environments/production/earendil/` (a foundation-plane app copies
   `environments/foundation/lumen/` — note its dir name is the APP name
   while resources keep explicit `lumen-admin-*` names: dir==app keeps
   the bump tooling name-free). **If the app serves the public, the
   overlay authors its own `ingress.yaml` too** (hosts/backend/TLS
   stated final, annotation-free — post-ingress-retirement a copy
   without it renders no door; see the earendil/mellon overlays for the
   shape). Then the Application CR in the right
   hub dir: `apps/foundation/`, `apps/staging/`, or `apps/production/`.
   The `bao` store, the issuerRef and the `lumen-bao-credentials`
   bootstrap family stay LITERAL everywhere — single-instance or
   Git-unmanaged objects the suffix must never chase.
4. **kinds-table PR** — add the new dir(s) + kind-count to
   `anvil/bin/expected-kinds.txt` (`--update` regenerates); `kubectl
   kustomize` each dir locally first (no cluster needed). ✅ check:
   `validate-all` prints `… table +
   shape + hooks + epoch trios GREEN` — the structural classes now
   guard your app forever, with no shared script edited (next paragraph).

> **Why nothing in stop 7 enumerates your app:** because the CI is
> **structural** — assertions read rendered output and directory shape,
> never names: the Deployment inline-literal ban (iron law),
> ES+Deployment⇒`envFrom` (config must be *consumed*, not decoration),
> `*migrate*`⇒PreSync (schema gates deploy), and epoch-TRIO equality —
> all three sides exist and match, or red
> (a half-bump is red). Same doctrine as the auto-merge fence (patterns,
> not apps) and the gate (reads the slug grammar): **convention IS the
> registry** — a new app is covered the moment its YAML follows it. The
> one-time provisioning *script* that stamps these shapes is known and
> deliberately deferred: automation earns its keep only after the
> convention has been walked by hand a couple of times and stopped
> changing.

## Backlog, clearly NOT live: the P3 epoch-agent

One paragraph so the idea has an address and a fence. **PROPOSED (backlog,
not built, not scheduled):** an agent that watches a vault path's head
version and, when it drifts from Git's declared TRIO, opens the
trio-flip PR — a *proposal*, reviewed and merged by a human like any
other. The hard boundary, printed now so future-you doesn't have to
re-derive it: the agent may **never auto-merge data lines** — the epoch
TRIO is a declaration about vault content, and letting the writer of
content also stamp its own declaration dissolves the whole pin/head/gate
contract (ch. 05 §7.1, ch. 06 §4). Until that thing exists, the ritual is
the manual one: portal matrix shows head → dispatch the config-epoch bump
→ the gate does the rest.

## The birth ceremony

First merge → three amber bump jobs. Approving one **is** the release
decision (ch. 09 §2): `major` → **v1.0.0**, `minor`/`patch` → v0.1.0 —
pick the birth number on purpose; it's a human ceremony by design. The
tag then lights the per-env deploy chains: an amber park for EVERY
environment the app declared (and a RED gate-audit first if those
environments aren't created + protected yet — that's the 2026-11-13
lesson, ch. 09 §6).
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
