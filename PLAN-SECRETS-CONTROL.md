# PLAN — Secrets Control Plane (apps are data)

**Status:** Phases A + B EXECUTED on `feature/secrets-control-plane` (lumen + mellon) — awaiting owner review/merge. Phase C deferred. **Repos:** `lumen/` (API), `mellon/` (UI), `vortex/` (deferred).
**Doc owner:** this file is the contract — update task checkboxes and the Decision Log here, not in chat transcripts.

## 0. Mission

`console.gofar.id` becomes the **central control surface for the whole infra**, starting with
the secrets plane: OpenBao stores secrets for _every_ service, so the portal must treat app
namespaces as **data, not code** — onboard any app, edit per-env values under a global
key-set invariant, inspect/pin/restore versions, and search within the selected env.
`lumen` is the first tenant, not a special case.

## 1. Owner-ratified decisions (2026-11-09)

| #   | Topic         | Ruling                                                                                                                                                                       |
| --- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Pin semantics | Pin = **operator intent** (badge/metadata). Reads ALWAYS serve head; any specific version is _viewable_ (`?version` already exists) — pin never reroutes reads or consumers. |
| D2  | Rollback      | **Included**: restore a version's values onto the CURRENT key set, saved as a new head. Removed keys do not resurrect.                                                       |
| D3  | Search        | **Current env, client-side**: fuzzy on key names AND values. No server search surface (values never flow wider than the view you already hold).                              |
| D4  | Env model     | Onboard seeds the **trio default** `dev/staging/production`; `POST /bao/{app}/envs` extends an app later, seeded with the canonical key set.                                 |
| D5  | Destroy       | App/env **destroy is out of API scope** (delete-grant is too heavy for a UI; Bao-side drills stay operator-only).                                                            |

## 2. Frozen design contract

Code to this table; if reality forces a change, record it in §8 before writing code.

### 2.1 lumen — `/admin/bao/*` (admin bearer; AppRole relays to Bao)

| Endpoint                      | Change       | Semantics                                                                                                                                                                                                                                                                                                           |
| ----------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /bao/paths`              | none         | already dynamic (scans `kv/metadata/`); lists EVERY app subtree — keep it so                                                                                                                                                                                                                                        |
| `POST /bao/apps`              | **new**      | body `{app, envs?}`; slug `^[a-z][a-z0-9-]{1,31}$`, no leading `_`; default envs = trio; creates each env as empty bundle `{}`; 409 if any env of the app already exists                                                                                                                                            |
| `POST /bao/{app}/envs`        | **new**      | body `{env}`; seeds the new env with the app's **canonical key set** = union of sibling envs' key sets, all values `""`; 409 if the env exists                                                                                                                                                                      |
| `PUT /bao/{app}/{env}`        | **extended** | existing CAS bundle write + **key-set mirror fan-out**: diff saved key set vs that env's PREVIOUS head; adds (`""` values) and removals applied to **all sibling envs**; values travel only for the written env; sibling writes CAS against each sibling's own head — stale ⇒ 409 `{"error":"mirror stale: <env>"}` |
| `GET /bao/{app}/{env}`        | none         | head, or `?version=N` (D1 — pin never affects this)                                                                                                                                                                                                                                                                 |
| `GET /bao/{app}/{env}?meta`   | **extended** | adds `pinnedVersion` (nullable), read from KV-v2 `custom_metadata`                                                                                                                                                                                                                                                  |
| `PUT /bao/{app}/{env}/pin`    | **new**      | body `{version}`; validates the version exists; PATCHes `custom_metadata {"pinnedVersion":N}` on `kv/metadata/{app}/{env}`                                                                                                                                                                                          |
| `DELETE /bao/{app}/{env}/pin` | **new**      | clears `pinnedVersion` from custom_metadata                                                                                                                                                                                                                                                                         |

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
- [x] **A2 — bao client** `internal/bao/bao.go`
      `Meta` gains `PinnedVersion *int` (parse `custom_metadata` from
      `GET kv/metadata/{app}/{env}` — Meta op must start reading the metadata endpoint);
      `PatchMetadataCustom(ctx, app, env, map)` for pin/unpin; `CreateIfAbsent`-style
      write helper for seeding empty bundles.
      **Accept:** unit tests for parsing (fixture JSON); wire-shape documented in code.
- [x] **A3 — service methods** `internal/adminsvc/` (secrets section)
      `OnboardApp`, `AddEnv`, `Pin`, `Unpin`, and the **WriteSecret mirror** (uses A1's
      keyDelta + reads sibling heads). Sibling CAS-stale ⇒ typed error carrying env.
      **Accept:** integration test (A5) proves fan-out; pure logic already proven in A1.
- [x] **A4 — handlers** `internal/api/admin/secrets.go`
      Mount the four new routes per §2.1; status mapping: 400 slug, 409 exists/stale,
      404 pin-version-unknown, 503 plane-disabled (existing pattern). Logs per §2.2-5.
      **Accept:** handlers stay thin (adminsvc owns logic — the repo's import rule
      still holds, check `db50d1b`-era test that guards it).
- [x] **A5 — dev plane + integration tests**
      `scripts/dev-plane.sh`: policy gains `path "kv/metadata/*" {capabilities=["read","list","patch"]}`.
      `internal/api/bao_integration_test.go` additions (same env-gating style): onboard
      `itest-app` → paths shows 3 envs; write w/ key added → siblings gain `""` key;
      remove → gone everywhere; pin/Unpin/meta roundtrip; sibling-stale 409.
      **Accept:** `go test ./...` green (with plane) and green (skipped, without plane).
- [x] **A6 — docs**: `lumen/DESIGN.md` §9 mirror (apps-are-data rule, endpoints table,
      pin semantics D1); journal in `lumen/PLAN.md`.

**Gate A:** `gofmt -l .` empty · `go vet ./...` · `go build ./...` · `go test ./...` ·
manual curl of every new endpoint against the live dev plane.

## 4. Task breakdown — Phase B: mellon (after A4/A5 ship)

- [x] **B1 — API layer**: `src/lib/api/types.ts` + `fetch-adapter.ts` — new methods
      (`onboardApp`, `addEnv`, `pin`, `unpin`), `SecretMeta.pinnedVersion`, mirror-stale
      error surfacing; extend the test-only twin if AdminApi has one there (check
      `mock.ts` scope) and keep contract tests honest.
      **Accept:** unit tests for adapter (mapping, 409 shapes) pass offline.
- [x] **B2 — fuzzy scorer** `src/lib/fuzzy.ts` (pure) + tests: subsequence + prefix/word
      bonus, stable ranking. **Accept:** vitest cases incl. empty query = identity order.
- [x] **B3 — pickers + onboarding**: app select / env tabs / `+ onboard app` dialog /
      `+ add env`. Data-driven only — grep gate: no `'lumen'|'dev'|'staging'|'production'`
      string literals in the page logic (defaults come from the API/`POST` contract).
- [x] **B4 — search bar**: filter rows via B2 on key+value, n-of-m counter, escape clears.
      Keyboard-first.
- [x] **B5 — pin UI + history actions**: badge, badge→pinned-vs-head diff, per-version
      pin/view/restore. Restore = overlay-onto-current-keys then normal dirty-save path (D2).
- [x] **B6 — console harness scenario**: end-to-end on throwaway `harness-app`:
      onboard → trio exists → edit dev adding KEY → switch staging → KEY present empty →
      search filters → pin v2 → badge amber after a v3 write → restore v2 → unpin.
      Teardown: none (dev plane is in-memory/re-seedable; document in the test comment).
      **Accept:** full mellon gate suite + `npm run test:console` green.
- [x] **B7 — docs**: `mellon/DESIGN.md` §9 rewrite (control-plane posture), journal in
      `mellon/PLAN.md`, root `AGENTS.md`/`INFRA_ARCHITECTURE.md` §5.6 note: prod
      `fzr-portal` policy must include `patch` on `kv/metadata/*`.

**Gate B:** `prettier` · `npm run lint` (standalone, exit 0) · `npm run check` 0/0 ·
`npm run test:unit` · `npm run build` · `npm run test:console`.

## 5. Task breakdown — Phase C: deferred (explicitly NOT in this round)

- [x] C1 — apps×envs **overview matrix** pane (head/pin/empty-key drift per app) — the
      data model (meta.pinnedVersion + paths) is already shaped for it.
- [x] C2 — `driftcheck` pin-aware (warn when head ≠ pin in CI/CLI). Shipped
      branch `feature/c2-pin-driftcheck` (unmerged): meta seam + unit tests +
      LIVE proof (real pin-under-head, default exit 0 warns, --strict-pin exit
      1, plane restored, battery 7/7).
- [x] C3 — ExternalSecret CR alignment — ABSORBED by the 2026-11-10 key-set
      cutover (property==secretKey 1:1 doctrine in the CR headers did the
      generator's job by hand; the portal matrix + pin-aware driftcheck now
      watch alignment continuously — a generator would emit what the CRs
      already ARE). Portal-suggests-YAML stays a recorded future, not a task.
- [ ] C4 — prod seeds (vortex): §5.6 policy w/ patch cap; kv seeds for new apps.
- [x] C5 — integration-path isolation: the battery must OWN an `itest/`
      prefix (relay test currently purges/reseeds `kv/lumen/dev` — the same
      path a HUMAN browses; an old-worker + shared-queue incident proved the
      collision class). Move relay-test ownership to `itest/*` paths.

## 6. Test ledger (where each promise is enforced)

| Promise                         | Guard                                          |
| ------------------------------- | ---------------------------------------------- |
| key-set invariant across envs   | A1 unit + A5 integration + B6 harness          |
| pin never reroutes reads        | A5 (read after pin == head)                    |
| app-agnostic                    | B3 literal-grep gate + code review rule §2.2-1 |
| no values in logs               | A4 review + existing doctrine                  |
| search correct + no server leak | B2 unit (pure), D3 by construction             |
| rollback keeps keys current     | B5 + B6 restore leg                            |
| dev plane policy patch granted  | A5 (pin op fails loudly without it)            |

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
- 2026-11-09 — **A2 shipped** (`lumen@9382b75`). Bonus find by the fixture
  test: the pre-A2 `Meta` decoder string-keyed the versions map into
  `toNum` → EVERY VersionInfo.Version was 0 in production (mellon history
  showed 0/0 since day one; the twin was right, live was lying). Fixed via
  `strconv.Atoi` + skip-unparsable. New wire ops: `PinnedVersion *int`
  (custom_metadata, D1 intent-only), `PatchMetadataCustom` (RFC 7396 —
  unpin = null), `CreateIfAbsent` (cas=0) with `remapExists` →
  ErrAlreadyExists for onboarding collisions. B-phase note: mellon needs NO
  twin change — live finally matches it.
- 2026-11-10 — **Phase A complete** (lumen branch `feature/secrets-control-plane`:
  A1 20336ee, A3 7fb5ba0, A4 77b8064, A5 98563b9, A6+A2). Deviations recorded:
  ① the mirror IMPLEMENTS RECONCILE (siblings pulled toward the saved shape)
  instead of delta-vs-previous-head — strictly stronger: an interrupted mirror
  heals on the next write; value-only edits bump nothing (proven live in A5).
  ② pins ride custom_metadata AS STRINGS (engine is map[string]string; numeric
  answers 500) and the PATCH needs `application/merge-patch+json` (SDK sends
  scim+json → 415). Both discovered by the live battery, documented in lumen §9.
  ③ A5's own script learned to CAS-from-meta after the mirror 409'd it — the
  invariant refusing a naive test is the invariant WORKING.
- 2026-11-10 — **Phase B complete** (mellon same branch: B1, B2, B3-B5 5c588cc,
  B6, B7). Twin now carries the INVARIANT (mirror/union/pin as executable
  contract); harness 45/45 exit 0 driving the whole lifecycle UI against live
  lumen+OpenBao (T-plane1..7). Svelte trap family extended: regex quantifiers
  in static attributes are EATEN as interpolations; markup expressions may not
  START with a regex literal (parses as block-close). Test truths: aria-label
  pinning over nth selectors; no auto-travel after add-env (tab-then-visit);
  the modal history drawer must be dismissed before header-edge clicks.
  D5 honored: harness apps persist (run-fresh names; FORCE=1 make seed resets).
- 2026-11-10 — **dev-box state for the morning**: lumen :8080 serves the
  BRANCH build (`make server` from feature/secrets-control-plane, nohup — the
  pre-A server was retired; `make dev` reuses whatever serves :8080, so
  restart it after reviewing to pick merged main). Pins NOT moved: both
  children carry pending work on unmerged branches, by design.
- 2026-11-10 — **owner add-on: palette verbs** (mellon `33d0c3c` "register
  control-plane verbs"): secrets verbs registered in the §7
  command contract incl. the filter editField buffer; harness 48/48.
  Test-harness truths journaled: palette-target-by-aria-label, cancel
  over Escape, settle-before-count.
- 2026-11-10 — **dev-plane collision finding (owner's "can't see the
  value")**: lumen/dev had been purged mid-cycle — the A5/A6 integration
  battery OWNS kv/lumen/dev (bootstrapPlane purges it at run start), so a
  test run racing a human's browser session can show empty/gone state.
  Plane RE-SEEDED via scripts/dev-plane.sh (values back: v1 trio). Phase C
  candidate C5: move relay-test ownership to an `itest/` prefix so human
  dev data and the battery never share paths.
- 2026-11-10 — **compare round shipped** (mellon `73f5d26`; design ratified
  in chat): same-path versions ONLY (cross-env diff refused by doctrine —
  per-env secrets side by side is a leak pattern); presentations
  table/split/inline × content parsed/raw (raw visibly disabled in table —
  the UI states its own rules); masking applied BEFORE serialization
  (displayValue is the single rule, shared with the editor's reveal-all and
  viewing panel); reveal-all display-only, never persisted; prefs persist
  behind the primitive-flag guard (the INTERNAL-200 lesson applied
  preventively); nav child 'compare' TRIED per owner, with longest-match
  highlighting fixing the double-lit rows nested hrefs caused; mobile
  header stacks (the owner screenshot), orderEnvs gives dev→staging→
  production everywhere. Battery truths: '2 of 4' assertion was MY math
  error — reality said 3 changed keys and the UI was right; the raw-json
  click deadlocked on the button the UI deliberately disables — commented
  choreography now. Harness 55/55 (+7), 71 units, visuals in shots/.
- 2026-11-10 — **mobile honesty sweep + sheet ruling** (mellon, this-day
  commit): bottom-sheet rails show the PRE-DRAG view (owner): collapse-only
  — SectionCard `reorderable` prop + `movable` snippet params on all three
  rails; desktop unaffected. Two owned regressions fixed: the backwards
  `max-lg:hidden` sheet trigger, and `[data-pane] contain: layout style`
  REMOVED (stacking contexts buried sibling popovers — the re-anchor sweep
  missed paint order; the perf it bought was marginal next to the slot
  cache). Popover placement gained a viewport-fit FLIP (the older bug
  containment had masked); palette right-anchored; breadcrumb truncate finally
  bounded. Harness 64/64 (+7), lessons folded into DESIGN §6.1-adjacent
  journal. C5 (itest prefix isolation) still open.
- 2026-11-10 — **tag desk round** (branch `feature/tag-desk` in lumen+mellon,
  owner-ratified design): ① migration 0006 tags.created_at/updated_at (any
  desk touch stamps updated_at; recency true from today, not retroactive —
  said in the SQL itself); ② cloud→featured ② tag MATCHING moves to
  MEILISEARCH ({id,name} docs, counts/featured hydrate from Postgres —
  superseded doctrine recorded honestly: "a name, not a document" held only
  while prefix lookup was the engine's best offer; typo tolerance is now ONE
  story across posts/photos/tags); ③ desk list doors (/admin/posts,
  /admin/photos) accept ?q → engine route with facets; photos date windows
  CANNOT ride (PhotoDoc lacks day) → chips visibly pause during search;
  ④ featured is MANUAL promotion only (owner ruling), public widget =
  featured AND posts > 0 ("a featured tag at zero is ready, not display-
  worthy") — earendil untouched, contract shape preserved; ⑤ the /tags desk
  page: lean rows (checkbox/name/posts/featured-pill), row→dialog (rename/
  feature/used-by roster/timestamps/delete-with-count), bulk feature via one
  tx (updated = ACTUAL changes), engine search bar + pager on the URL;
  ⑥ dashboard becomes an append-ready card grid (posts/photos/tiles/tags,
  Traffic slot contract commented). Orchestration: 2 recon + 3 implementation
  subagents over disjoint file ownership; main held the convergence gates.
  Runtime discipline learned the hard way twice: queue-affecting deploys MUST
  restart the running `lumen` (an old worker binary rejected index_tag jobs
  sharing the dev queue), and pgrep/pkill patterns self-match the invoking
  shell — filter by /proc/comm before killing.
- 2026-11-10 — tag-desk round MERGED to main (lumen 7b744cb + hygiene fix
  ed23dc3 purging .vite junk an `add -A` swept in; mellon ff1d135) and pins
  bumped at root. Gates at both merge tips green (lumen 7/7 live battery,
  mellon 79/79 console harness). Phase C + C5 (itest prefix isolation)
  remain open by design.
- 2026-11-10 — **estate round executed** (branch `feature/estate-round` both
  repos, unmerged for review): C5 (battery owns itest/relay — proven by a
  plane restart mid-round) and C1 (summary sweep + matrix page + twin + 6
  harness asserts, 85/85). Gate discipline repaired mid-flight after two
  tail-masked-exit slips: every gate now records its exit code explicitly.
- 2026-11-10 — **ESO pin raised 0.1.4 → 2.15.0** (vortex branch `chore/pin-eso-2.15.0`,
  unmerged). The 0.1.4 was an un-confirmed placeholder from the pre-1.x chart lifecycle;
  ESO unified operator+chart versioning in 2.x, and v2.15.0 is current (published today;
  operator tag + helm-chart tag + artifacthub cross-checked — the v1.5.0 the older docs
  cite does not exist as a tag). Never deployed => pin-before-first-install, no migration;
  all CRs already on stable external-secrets.io/v1. First-sync checklist now rides the CR
  comment (kubeVersion vs k3s, helm show values key audit, store-Ready order); verified
  during k3d rehearsal, not at prod. INFRA §5.6 + tree line updated to match.
- 2026-11-10 — **gitops alignment round** (vortex branch `chore/gitops-repo-and-es-keys`
  + `chore/container-hygiene` on all three children; estate-round merges pinned at root):
  repoURLs repointed to kanatabi/vortex (9 machine-critical spots incl. the hub);
  ExternalSecret key sets CUT OVER to the real env contract (property == secretKey,
  1:1 — the old lumen trio was drift that would have booted prod pods blind while
  every shape check passed; SESSION_JWT_SECRET was missing entirely); ORIGIN ruled
  dead and removed everywhere (no reader in any repo); NEW rulings recorded in the
  CR headers: LUMEN_MEDIA_* waits GATE #9, LUMEN_BAO_* relay creds ride the §5.6
  bootstrap family NOT an ExternalSecret (bootstrap paradox); dev overlays added for
  the local-cluster ESO rehearsal (bases stay ESO-free — opt-in by path). Container
  audit: all three Dockerfiles EXISTED (previously unbuilt) — lumen gained a
  .dockerignore (dev-plane.env would have baked into images), earendil/mellon comment
  fictions corrected; PROOF: docker build x3 + live SSR/auth smoke against dev-lumen
  all exit 0. NOTE: the owner merge sweep missed vortex `chore/pin-eso-2.15.0` —
  still unmerged; the new branch is file-disjoint so either merge order works.
- 2026-11-10 — **single-node + runbook round** (vortex branch `feature/single-node`
  4 commits + lumen `feature/c2-pin-driftcheck`, both unmerged): the 1-node shape
  is now first-class GitOps (components/single-node + selfsigned, overlays/local
  chain, apps/single-node hub CRs with STRUCTURAL wave gating — store-Ready
  before apps, seeded-Bao before store); mellon got its manifests; the
  REPLACE_AT_BOOTSTRAP placeholder is DEAD (appRole.roleRef verified against the
  shipped 2.15.0 CRD — both Bao creds now ride the bootstrap Secret; doctrine
  restated: Git templates, Secrets bootstrap, Bao values); lumen got the
  lumen-bao-credentials envFrom landing (optional:true keeps k3d honest);
  RUNBOOK.md at root = one doc for minikube rehearsal + single-VPS production +
  scale-out, pins researched and named (argo v2.13.2 vs k3s 1.37 flagged
  known-unverified until the live walk). Dev plane proven as the seed-shape
  reference: portal/eso policies, role writes, driftcheck live demo.
- 2026-11-11 — **RUNBOOK Part A walked to completion** (the "first live walk"
  item closed). Full estate Synced/Healthy on minikube; portal login proven on
  both postures (http→non-Secure cookie, https websecure→Secure); pin-drift
  amber cell demonstrated through the matrix; PreSync `lumen migrate` hook
  executed on real syncs. Rounds that came out of the walk (all merged):
  mellon `fix/session-cookie-secure` + `fix/preview-runtime-bundle` (the
  self-contained-server doctrine amended — jsdom/shiki are bundle-hostile,
  prod node_modules now ship; SSR externals audited to bare-specifier zero),
  lumen `feature/c2-pin-driftcheck` (driftcheck pin-aware + `migrate` verb —
  battery 7/7 post-merge after an overnight dev-plane container loss),
  vortex forwarded-headers + DSN-truth sweeps, earendil env.ts fossil.
  Vault was BORN, died (lost unseal key — /tmp is not offline storage, the
  runbook's own rule violated by its author), and was reborn: the A8b reinit
  recipe (incl. the hostpath ns/claim-keyed data-dir trap) is walk-proven.
  Earendil `about-page` + `hero-ascii-reveal` ruled STALE (Option A: never
  merge, keep as refs — content landed via earlier PRs; trees are far behind
  main). C2 also formally closes what C1's matrix previewed: pin intent is
  now watched by CLI, CI (--strict-pin) and the portal simultaneously.
- 2026-11-11b — **post-walk hardening** (owner driving the portal live caught
  what the smoke missed): earendil's deepest route (/posts/[slug]) 500d on
  ERR_MODULE_NOT_FOUND markdown-it — vite externalizes ALL node_modules in SSR
  builds, so every undeclared-at-runtime dep was a landmine in BOTH SSR apps
  (mellon's preview proxy fell to the same class minutes earlier; fixed there
  first). Policy now: markdown-it family noExternal (pure JS bundles),
  shiki/jsdom chain external + pruned prod node_modules in the image (package-
  layout resolvers, unbundleable in any output mode); audits grep bare
  specifiers, humans don't discover them at runtime. Deepest-route rule written
  into RUNBOOK A10. Owner decisions executed: lumen runtime distroless ->
  pinned alpine:3.24.4 (uid 65532 + CA certs kept — `kubectl exec` matters
  more than purity when the pod misbehaves); earendil ingress cut over to
  gofar.id/www (their own commit, walk-verified). Full post pipeline proven on
  cluster: anchor-h1, Shiki fence, mermaid-src, task-list, search leg — zero
  module errors. Portal CSRF confirmed healthy on both paths (the 403 that
  started this was a curl missing Origin, and the answer is the guard WORKS).
- 2026-11-11c — **setup-wizard round** (merged lumen+mellon mains): the estate
  bootstraps itself — /setup registers the first admin via TOFU (advisory-lock
  atomic; 410 Gone forever after; no admin-password Job in the primary path,
  CLI demoted to recovery), must_change temps (server-generated syllable
  passwords, one-time reveal, ~50 bits) are guided back through /setup, and
  the 428 forced-change lock is transport-enforced in lumen (roles/flags read
  per request — never JWT claims). lumen migration 0007 + battery e2e on a
  scratch schema; mellon twin mirrors the invariants + 8 new harness asserts
  (94/94). Cluster redeployed along the way: one-shot lumen migrate Job (the
  PreSync hook automates that ordering forever), portal + users desk verified
  live on the rehearsal cluster. Wizard security note queued FOR GATE #5: the
  TOFU window (empty users + reachable portal) is bounded by console.gofar.id
  staying dark until #10 — the registration endpoint is the estate's only
  unauthenticated write, and the review should say so out loud.
- — (append deltas here: contract changes, deviations, new rulings)
