# PLAN — Secrets Control Plane (apps are data)

**Status:** approved design, unexecuted. **Repos:** `lumen/` (API), `mellon/` (UI), `vortex/` (deferred).
**Doc owner:** this file is the contract — update task checkboxes and the Decision Log here, not in chat transcripts.

## 0. Mission

`console.gofar.id` becomes the **central control surface for the whole infra**, starting with
the secrets plane: OpenBao stores secrets for *every* service, so the portal must treat app
namespaces as **data, not code** — onboard any app, edit per-env values under a global
key-set invariant, inspect/pin/restore versions, and search within the selected env.
`lumen` is the first tenant, not a special case.

## 1. Owner-ratified decisions (2026-11-09)

| # | Topic | Ruling |
|---|-------|--------|
| D1 | Pin semantics | Pin = **operator intent** (badge/metadata). Reads ALWAYS serve head; any specific version is *viewable* (`?version` already exists) — pin never reroutes reads or consumers. |
| D2 | Rollback | **Included**: restore a version's values onto the CURRENT key set, saved as a new head. Removed keys do not resurrect. |
| D3 | Search | **Current env, client-side**: fuzzy on key names AND values. No server search surface (values never flow wider than the view you already hold). |
| D4 | Env model | Onboard seeds the **trio default** `dev/staging/production`; `POST /bao/{app}/envs` extends an app later, seeded with the canonical key set. |
| D5 | Destroy | App/env **destroy is out of API scope** (delete-grant is too heavy for a UI; Bao-side drills stay operator-only). |

## 2. Frozen design contract

Code to this table; if reality forces a change, record it in §8 before writing code.

### 2.1 lumen — `/admin/bao/*` (admin bearer; AppRole relays to Bao)

| Endpoint | Change | Semantics |
|---|---|---|
| `GET /bao/paths` | none | already dynamic (scans `kv/metadata/`); lists EVERY app subtree — keep it so |
| `POST /bao/apps` | **new** | body `{app, envs?}`; slug `^[a-z][a-z0-9-]{1,31}$`, no leading `_`; default envs = trio; creates each env as empty bundle `{}`; 409 if any env of the app already exists |
| `POST /bao/{app}/envs` | **new** | body `{env}`; seeds the new env with the app's **canonical key set** = union of sibling envs' key sets, all values `""`; 409 if the env exists |
| `PUT /bao/{app}/{env}` | **extended** | existing CAS bundle write + **key-set mirror fan-out**: diff saved key set vs that env's PREVIOUS head; adds (`""` values) and removals applied to **all sibling envs**; values travel only for the written env; sibling writes CAS against each sibling's own head — stale ⇒ 409 `{"error":"mirror stale: <env>"}` |
| `GET /bao/{app}/{env}` | none | head, or `?version=N` (D1 — pin never affects this) |
| `GET /bao/{app}/{env}?meta` | **extended** | adds `pinnedVersion` (nullable), read from KV-v2 `custom_metadata` |
| `PUT /bao/{app}/{env}/pin` | **new** | body `{version}`; validates the version exists; PATCHes `custom_metadata {"pinnedVersion":N}` on `kv/metadata/{app}/{env}` |
| `DELETE /bao/{app}/{env}/pin` | **new** | clears `pinnedVersion` from custom_metadata |

### 2.2 Invariants & doctrine (binding)

1. **Apps are data** — zero app-specific logic in lumen/mellon; no allowlists; `{app}` is an opaque validated slug. (A future `if app == "lumen"` anywhere = design violation.)
2. **Key sets are structurally identical** across all envs of an app; values are per-env. The mirror on the write path is the enforcement point.
3. **Head is what you see** — editors, consumers (ESO), and reads never consult the pin.
4. **Vocabulary** — app slug == the infra service name (vortex kustomize dir / Argo app name). GitOps still owns deployments; this portal owns secrets.
5. **Logging doctrine holds** — new endpoints log `op + app + env + version + key-counts`, NEVER values. No `sys/` routes. No destroy endpoints (D5).
6. **Blast radius** — the only new Bao capability grant is `patch` on `kv/metadata/*` (dev-plane.sh + §5.6 prod seed note). Read/list/write on `kv/data/*` stay as-is.

### 2.3 mellon — `/secrets` page

- **App picker** (grouped from `paths` data) → **env tabs** (child of selected app) — replaces path chips; everything renders from data (no hardcoded env/app).
- **+ onboard app**: name field → `POST /bao/apps` → select it, land on `dev`.
- **+ add env** (small action on the env tab strip) → `POST /bao/{app}/envs`.
- **Search bar** (D3): client-side fuzzy (subsequence scorer, unit-tested) over current env's rows, key + value; "n of m keys" counter; clear-x.
- **Pin badge**: header shows `v{head}` + `pinned v{N}` when set (amber when `N ≠ head`); badge click → **diff pinned-vs-head** (reuse `lineDiff`/`diffLines`).
- **History drawer**: per version row — `view` (read-only payload), `diff` (exists), **`pin`** (PUT pin), and **`restore`** (D2: overlay that version's values onto current key set → normal save flow, so mirror fan-out applies).
- Dirty-dot / unsaved / watermark behavior unchanged; Watermark still masks values.

## 3. Task breakdown — Phase A: lumen (start here; its API is the contract)

**Branch:** `feature/secrets-control-plane` forked from `refactor/layered-architecture`
(handlers + adminsvc already live there; merge order: layered → main FIRST, then this —
see §7 risks). Validate with dev plane up: `scripts/dev-plane.sh` → `dev-plane.env`.

- [x] **A1 — pure core** `internal/adminsvc/secrets_pure.go` + `_test.go`
      Validate `keyDelta(oldSet, newSet) → (adds, removes)`, `unionKeys(map[env][]key)`,
      slug validation, canonical-set selection. NO Bao/DB imports.
      **Accept:** table-driven unit tests pass with no network; covers empty-env,
      remove-all, add-after-remove races as pure data.
- [ ] **A2 — bao client** `internal/bao/bao.go`
      `Meta` gains `PinnedVersion *int` (parse `custom_metadata` from
      `GET kv/metadata/{app}/{env}` — Meta op must start reading the metadata endpoint);
      `PatchMetadataCustom(ctx, app, env, map)` for pin/unpin; `CreateIfAbsent`-style
      write helper for seeding empty bundles.
      **Accept:** unit tests for parsing (fixture JSON); wire-shape documented in code.
- [ ] **A3 — service methods** `internal/adminsvc/` (secrets section)
      `OnboardApp`, `AddEnv`, `Pin`, `Unpin`, and the **WriteSecret mirror** (uses A1's
      keyDelta + reads sibling heads). Sibling CAS-stale ⇒ typed error carrying env.
      **Accept:** integration test (A5) proves fan-out; pure logic already proven in A1.
- [ ] **A4 — handlers** `internal/api/admin/secrets.go`
      Mount the four new routes per §2.1; status mapping: 400 slug, 409 exists/stale,
      404 pin-version-unknown, 503 plane-disabled (existing pattern). Logs per §2.2-5.
      **Accept:** handlers stay thin (adminsvc owns logic — the repo's import rule
      still holds, check `db50d1b`-era test that guards it).
- [ ] **A5 — dev plane + integration tests**
      `scripts/dev-plane.sh`: policy gains `path "kv/metadata/*" {capabilities=["read","list","patch"]}`.
      `internal/api/bao_integration_test.go` additions (same env-gating style): onboard
      `itest-app` → paths shows 3 envs; write w/ key added → siblings gain `""` key;
      remove → gone everywhere; pin/Unpin/meta roundtrip; sibling-stale 409.
      **Accept:** `go test ./...` green (with plane) and green (skipped, without plane).
- [ ] **A6 — docs**: `lumen/DESIGN.md` §9 mirror (apps-are-data rule, endpoints table,
      pin semantics D1); journal in `lumen/PLAN.md`.

**Gate A:** `gofmt -l .` empty · `go vet ./...` · `go build ./...` · `go test ./...` ·
manual curl of every new endpoint against the live dev plane.

## 4. Task breakdown — Phase B: mellon (after A4/A5 ship)

- [ ] **B1 — API layer**: `src/lib/api/types.ts` + `fetch-adapter.ts` — new methods
      (`onboardApp`, `addEnv`, `pin`, `unpin`), `SecretMeta.pinnedVersion`, mirror-stale
      error surfacing; extend the test-only twin if AdminApi has one there (check
      `mock.ts` scope) and keep contract tests honest.
      **Accept:** unit tests for adapter (mapping, 409 shapes) pass offline.
- [ ] **B2 — fuzzy scorer** `src/lib/fuzzy.ts` (pure) + tests: subsequence + prefix/word
      bonus, stable ranking. **Accept:** vitest cases incl. empty query = identity order.
- [ ] **B3 — pickers + onboarding**: app select / env tabs / `+ onboard app` dialog /
      `+ add env`. Data-driven only — grep gate: no `'lumen'|'dev'|'staging'|'production'`
      string literals in the page logic (defaults come from the API/`POST` contract).
- [ ] **B4 — search bar**: filter rows via B2 on key+value, n-of-m counter, escape clears.
      Keyboard-first.
- [ ] **B5 — pin UI + history actions**: badge, badge→pinned-vs-head diff, per-version
      pin/view/restore. Restore = overlay-onto-current-keys then normal dirty-save path (D2).
- [ ] **B6 — console harness scenario**: end-to-end on throwaway `harness-app`:
      onboard → trio exists → edit dev adding KEY → switch staging → KEY present empty →
      search filters → pin v2 → badge amber after a v3 write → restore v2 → unpin.
      Teardown: none (dev plane is in-memory/re-seedable; document in the test comment).
      **Accept:** full mellon gate suite + `npm run test:console` green.
- [ ] **B7 — docs**: `mellon/DESIGN.md` §9 rewrite (control-plane posture), journal in
      `mellon/PLAN.md`, root `AGENTS.md`/`INFRA_ARCHITECTURE.md` §5.6 note: prod
      `fzr-portal` policy must include `patch` on `kv/metadata/*`.

**Gate B:** `prettier` · `npm run lint` (standalone, exit 0) · `npm run check` 0/0 ·
`npm run test:unit` · `npm run build` · `npm run test:console`.

## 5. Task breakdown — Phase C: deferred (explicitly NOT in this round)

- [ ] C1 — apps×envs **overview matrix** pane (head/pin/empty-key drift per app) — the
      data model (meta.pinnedVersion + paths) is already shaped for it.
- [ ] C2 — `driftcheck` pin-aware (warn when head ≠ pin in CI/CLI).
- [ ] C3 — ExternalSecret CR alignment: onboarding checklist generator (names match
      `vortex` dirs; CRs stay GitOps-written — portal may one day *suggest* the YAML).
- [ ] C4 — prod seeds (vortex): §5.6 policy w/ patch cap; kv seeds for new apps.

## 6. Test ledger (where each promise is enforced)

| Promise | Guard |
|---|---|
| key-set invariant across envs | A1 unit + A5 integration + B6 harness |
| pin never reroutes reads | A5 (read after pin == head) |
| app-agnostic | B3 literal-grep gate + code review rule §2.2-1 |
| no values in logs | A4 review + existing doctrine |
| search correct + no server leak | B2 unit (pure), D3 by construction |
| rollback keeps keys current | B5 + B6 restore leg |
| dev plane policy patch granted | A5 (pin op fails loudly without it) |

## 7. Risks & orders

- **Merge order dependency**: layered refactor is unmerged. Ship layered→main (owner), then
  rebase/merge `feature/secrets-control-plane`→main. Do NOT fork from main — the handler/
  service split moved under the owner's feet mid-flight.
- **Sibling CAS races** (two tabs editing): mirror returns named-env 409; UI shows the
  existing conflict copy + reload. Acceptable at admin-single-operator scale; documented.
- **Pin before patch-capability**: if dev-plane isn't re-run, pin endpoints fail with a
  permission error surfaced as 502/500 — the runbook line in A5 docs ("re-run
  scripts/dev-plane.sh after pulling").
- **`harness-app` residue** in dev plane: intentional (D5); `FORCE=1 make seed` clears.
- **KV v2 custom_metadata availability**: OpenBao inherits it (dev runs real OpenBao,
  per bao.go header) — verified by A5 integration, not assumed.

## 8. Decision log (append-only)

- 2026-11-09 — D1..D5 ratified by owner (chat → this doc).
- 2026-11-09 — **A1 shipped** (`lumen@20336ee`, branch `feature/secrets-control-plane`
  off post-merge main — the §7 merge-order risk retired). Naming deltas from the
  sketch: functions exported (A4's package + integration tests consume them);
  `unionKeys` implemented as `CanonicalKeySet(map[env]payload)` — takes payloads
  directly so A3 never hand-rolls the projection; `KeySet` added as the sorted
  projection both share. The mirror's write-gate (`ApplyDelta → changed`) is the
  §7 two-tab-race answer: raced siblings keep their values AND skip the write
  (no gratuitous version bump, no fake 409) — unit-proven as pure data.
- — (append deltas here: contract changes, deviations, new rulings)
